/* ==========================================================================
   SGE_ajout.sql
   Ajouts ciblés au schéma existant :
     1. Mot de passe hashé sur la table personnel (pgcrypto bcrypt).
     2. Statut et suivi des rapports d'exception,
        avec vues séparées par procédé (réception, stockage, expédition).
   Exécuter APRÈS SGE_cre.sql + SGE_inv.sql + SGE_imm.sql + SGE_tra.sql.
   ========================================================================== */

SET search_path TO sge;

/* ══════════════════════════════════════════════════════════════════════════
   1. MOT DE PASSE UTILISATEUR
   ══════════════════════════════════════════════════════════════════════════ */

/* Extension pgcrypto pour le hachage bcrypt */
CREATE EXTENSION IF NOT EXISTS pgcrypto;

/* Colonne mot_de_passe dans personnel (texte hashé, nullable à la création) */
ALTER TABLE personnel
  ADD COLUMN IF NOT EXISTS mot_de_passe text
    CHECK (mot_de_passe IS NULL OR length(mot_de_passe) > 0);

/* ── Définir le mot de passe d'un utilisateur ──────────────────────────── */
CREATE OR REPLACE FUNCTION set_mot_de_passe(
  p_id          varchar(7),
  p_mot_de_passe text          -- mot de passe en clair, hashé ici
)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF length(trim(p_mot_de_passe)) < 6 THEN
    RAISE EXCEPTION 'Le mot de passe doit contenir au moins 6 caractères.';
  END IF;

  UPDATE personnel
  SET mot_de_passe = crypt(p_mot_de_passe, gen_salt('bf', 10))
  WHERE id_personnel = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Personnel % introuvable.', p_id;
  END IF;
END;
$$;

/* ── Vérifier le mot de passe (retourne TRUE si correct) ──────────────── */
CREATE OR REPLACE FUNCTION verifier_mot_de_passe(
  p_id           varchar(7),
  p_mot_de_passe text
)
RETURNS boolean
LANGUAGE plpgsql AS $$
DECLARE
  hash_stocke text;
BEGIN
  SELECT mot_de_passe INTO hash_stocke
  FROM personnel
  WHERE id_personnel = p_id;

  IF hash_stocke IS NULL THEN
    RAISE EXCEPTION 'Aucun mot de passe défini pour le personnel %.', p_id;
  END IF;

  RETURN (crypt(p_mot_de_passe, hash_stocke) = hash_stocke);
END;
$$;

/* ══════════════════════════════════════════════════════════════════════════
   2. GESTION DES RAPPORTS D'EXCEPTION
   ══════════════════════════════════════════════════════════════════════════ */

/* ── Enum de statut ────────────────────────────────────────────────────── */
CREATE TYPE statut_rapport AS ENUM ('en_attente', 'en_cours', 'resolu');

/* ── Colonnes de suivi ajoutées à rapport_exception ───────────────────── */
ALTER TABLE rapport_exception
  ADD COLUMN IF NOT EXISTS statut          statut_rapport NOT NULL DEFAULT 'en_attente',
  ADD COLUMN IF NOT EXISTS date_resolution timestamp,
  ADD COLUMN IF NOT EXISTS resolu_par      varchar(7)
    REFERENCES personnel(id_personnel) ON DELETE SET NULL;

/* ── Vue : tous les rapports avec le nom du responsable ──────────────────  */
CREATE OR REPLACE VIEW v_rapports_exception_detail AS
SELECT
  r.id_rapport,
  r.procede,
  r.statut,
  r.description_rapport,
  r.date_rapport,
  r.no_chargement,
  r.no_colis,
  r.date_resolution,
  p.nom    || ' ' || p.prenom AS resolu_par
FROM rapport_exception r
LEFT JOIN personnel p ON p.id_personnel = r.resolu_par
ORDER BY r.date_rapport DESC;

/* ── Vue : rapports de RÉCEPTION ─────────────────────────────────────── */
CREATE OR REPLACE VIEW v_rapports_reception AS
SELECT *
FROM v_rapports_exception_detail
WHERE procede = 'reception';

/* ── Vue : rapports de STOCKAGE ──────────────────────────────────────── */
CREATE OR REPLACE VIEW v_rapports_stockage AS
SELECT *
FROM v_rapports_exception_detail
WHERE procede = 'stockage';

/* ── Vue : rapports d'EXPÉDITION ─────────────────────────────────────── */
CREATE OR REPLACE VIEW v_rapports_expedition AS
SELECT *
FROM v_rapports_exception_detail
WHERE procede = 'expedition';

/* ── Vue : rapports en attente par procédé (tableau de bord) ─────────── */
CREATE OR REPLACE VIEW v_rapports_en_attente AS
SELECT
  procede,
  COUNT(*) FILTER (WHERE statut = 'en_attente') AS en_attente,
  COUNT(*) FILTER (WHERE statut = 'en_cours')   AS en_cours,
  COUNT(*) FILTER (WHERE statut = 'resolu')      AS resolus,
  COUNT(*)                                        AS total
FROM rapport_exception
GROUP BY procede
ORDER BY procede;

/* ── Prise en charge d'un rapport (en_attente → en_cours) ───────────── */
CREATE OR REPLACE FUNCTION tra_prendre_en_charge_rapport(
  p_id_rapport  varchar(7),
  p_id_personnel varchar(7)
)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE rapport_exception
  SET statut     = 'en_cours',
      resolu_par = p_id_personnel
  WHERE id_rapport = p_id_rapport
    AND statut     = 'en_attente';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rapport % introuvable ou déjà pris en charge.', p_id_rapport;
  END IF;
END;
$$;

/* ── Résolution d'un rapport (en_cours → resolu) ─────────────────────── */
CREATE OR REPLACE FUNCTION tra_resoudre_rapport(
  p_id_rapport   varchar(7),
  p_id_personnel varchar(7)
)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE rapport_exception
  SET statut          = 'resolu',
      date_resolution = CURRENT_TIMESTAMP,
      resolu_par      = p_id_personnel
  WHERE id_rapport = p_id_rapport
    AND statut IN ('en_attente', 'en_cours');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rapport % introuvable ou déjà résolu.', p_id_rapport;
  END IF;
END;
$$;

/* ── Requête : rapports non résolus d'un procédé donné ───────────────── */
CREATE OR REPLACE FUNCTION req_rapports_ouverts(p_procede type_procede)
RETURNS TABLE (
  id_rapport          varchar(7),
  statut              statut_rapport,
  description_rapport text,
  date_rapport        timestamp,
  no_colis            varchar(7),
  no_chargement       varchar(7)
)
LANGUAGE sql AS $$
  SELECT id_rapport, statut, description_rapport, date_rapport, no_colis, no_chargement
  FROM rapport_exception
  WHERE procede = p_procede
    AND statut <> 'resolu'
  ORDER BY date_rapport ASC;
$$;
