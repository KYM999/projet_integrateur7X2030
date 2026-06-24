/* ==========================================================================
   SGE_inv.sql
   Invariants, vues de contrôle et déclencheurs du SGE.
   Exécuter APRÈS SGE_cre.sql.
   ========================================================================== */

SET search_path TO sge;

/* ── Vues de contrôle ────────────────────────────────────────────────────── */

CREATE OR REPLACE VIEW v_inventaire_produit AS
SELECT
  p.id_produit,
  p.nom,
  p.type,
  COALESCE(SUM(ie.quantite_stockee), 0)::integer AS quantite_stockee
FROM produit p
LEFT JOIN lot l                    ON l.id_produit = p.id_produit
LEFT JOIN inventaire_emplacement ie ON ie.id_lot   = l.id_lot
GROUP BY p.id_produit, p.nom, p.type;

CREATE OR REPLACE VIEW v_inventaire_cellule AS
SELECT
  c.no_cellule,
  zs.nom        AS zone_stockage,
  c.disponibilite,
  COALESCE(SUM(ie.quantite_stockee), 0)::integer AS quantite_stockee
FROM cellule c
JOIN zone_stockage zs              ON zs.no_zs   = c.no_zs
LEFT JOIN inventaire_emplacement ie ON ie.no_cellule = c.no_cellule
GROUP BY c.no_cellule, zs.nom, c.disponibilite;

CREATE OR REPLACE VIEW v_occupation_cellule AS
SELECT
  c.no_cellule,
  c.masse_maximale,
  COALESCE(SUM(ie.quantite_stockee * pm.masse), 0)::numeric(12,3) AS masse_stockee,
  CASE
    WHEN c.masse_maximale = 0 THEN 0
    ELSE ROUND(
           (COALESCE(SUM(ie.quantite_stockee * pm.masse), 0) / c.masse_maximale) * 100,
           2)
  END AS taux_occupation_masse
FROM cellule c
LEFT JOIN inventaire_emplacement ie ON ie.no_cellule = c.no_cellule
LEFT JOIN lot l                     ON l.id_lot      = ie.id_lot
LEFT JOIN produit_materiel pm       ON pm.id_produit = l.id_produit
GROUP BY c.no_cellule, c.masse_maximale;

CREATE OR REPLACE VIEW v_colis_detail AS
SELECT
  c.no_colis,
  c.type,
  c.date_arrivee,
  c.date_expedition,
  p.id_produit,
  p.nom    AS produit,
  cc.qte_produit
FROM colis c
LEFT JOIN contenu_colis cc ON cc.no_colis   = c.no_colis
LEFT JOIN produit p        ON p.id_produit  = cc.id_produit;

CREATE OR REPLACE VIEW v_bons_reception_en_attente AS
SELECT
  br.id_bon_reception,
  br.no_colis,
  c.date_arrivee,
  c.no_chargement,
  br.description_recep
FROM bon_reception br
JOIN colis c ON c.no_colis = br.no_colis
WHERE c.type = 'entrant';

CREATE OR REPLACE VIEW v_bons_expedition_en_attente AS
SELECT
  be.id_bon_expedition,
  be.no_colis,
  c.date_expedition,
  c.no_chargement,
  be.description_exped
FROM bon_expedition be
JOIN colis c ON c.no_colis = be.no_colis
WHERE c.type = 'sortant' AND c.date_expedition IS NULL;

/* ── Déclencheur 1 : cohérence des dates du colis ───────────────────────── */

CREATE OR REPLACE FUNCTION verifier_dates_colis()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.date_arrivee IS NOT NULL
     AND NEW.date_expedition IS NOT NULL
     AND NEW.date_expedition < NEW.date_arrivee THEN
    RAISE EXCEPTION 'La date d''expédition (%) ne peut pas précéder la date d''arrivée (%) du colis %.',
      NEW.date_expedition, NEW.date_arrivee, NEW.no_colis;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_verifier_dates_colis
BEFORE INSERT OR UPDATE ON colis
FOR EACH ROW EXECUTE FUNCTION verifier_dates_colis();

/* ── Déclencheur 2 : cohérence type produit / table de spécialisation ────── */

CREATE OR REPLACE FUNCTION verifier_type_produit()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  type_attendu type_produit;
BEGIN
  SELECT p.type INTO type_attendu
  FROM produit p
  WHERE p.id_produit = NEW.id_produit;

  IF TG_TABLE_NAME = 'produit_materiel'  AND type_attendu <> 'materiel'  THEN
    RAISE EXCEPTION 'Le produit % doit être de type materiel (type actuel : %).', NEW.id_produit, type_attendu;
  ELSIF TG_TABLE_NAME = 'produit_logiciel' AND type_attendu <> 'logiciel' THEN
    RAISE EXCEPTION 'Le produit % doit être de type logiciel (type actuel : %).', NEW.id_produit, type_attendu;
  ELSIF TG_TABLE_NAME = 'produit_emballage' AND type_attendu <> 'emballage' THEN
    RAISE EXCEPTION 'Le produit % doit être de type emballage (type actuel : %).', NEW.id_produit, type_attendu;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_type_produit_materiel
BEFORE INSERT OR UPDATE ON produit_materiel
FOR EACH ROW EXECUTE FUNCTION verifier_type_produit();

CREATE TRIGGER trg_type_produit_logiciel
BEFORE INSERT OR UPDATE ON produit_logiciel
FOR EACH ROW EXECUTE FUNCTION verifier_type_produit();

CREATE TRIGGER trg_type_produit_emballage
BEFORE INSERT OR UPDATE ON produit_emballage
FOR EACH ROW EXECUTE FUNCTION verifier_type_produit();

/* ── Déclencheur 3 : quantité stockée ≤ quantité du lot ─────────────────── */

CREATE OR REPLACE FUNCTION verifier_quantite_lot()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  lot_a_verifier varchar(7);
  qte_lot        integer;
  qte_stockee    integer;
BEGIN
  lot_a_verifier := CASE WHEN TG_OP = 'DELETE' THEN OLD.id_lot ELSE NEW.id_lot END;

  SELECT quantite INTO qte_lot
  FROM lot
  WHERE id_lot = lot_a_verifier;

  SELECT COALESCE(SUM(quantite_stockee), 0)::integer INTO qte_stockee
  FROM inventaire_emplacement
  WHERE id_lot = lot_a_verifier;

  IF qte_stockee > qte_lot THEN
    RAISE EXCEPTION 'Quantité stockée (%) dépasse la quantité du lot % (%).',
      qte_stockee, lot_a_verifier, qte_lot;
  END IF;

  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_verifier_quantite_lot
AFTER INSERT OR UPDATE OR DELETE ON inventaire_emplacement
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE FUNCTION verifier_quantite_lot();

/* ── Déclencheur 4 : masse stockée ≤ masse maximale de la cellule ─────────── */

CREATE OR REPLACE FUNCTION verifier_capacite_cellule()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  cellule_a_verifier varchar(7);
  masse_max          numeric;
  masse_actuelle     numeric;
BEGIN
  cellule_a_verifier := CASE WHEN TG_OP = 'DELETE' THEN OLD.no_cellule ELSE NEW.no_cellule END;

  SELECT masse_maximale INTO masse_max
  FROM cellule
  WHERE no_cellule = cellule_a_verifier;

  SELECT COALESCE(SUM(ie.quantite_stockee * COALESCE(pm.masse, 0)), 0) INTO masse_actuelle
  FROM inventaire_emplacement ie
  JOIN lot l                  ON l.id_lot      = ie.id_lot
  LEFT JOIN produit_materiel pm ON pm.id_produit = l.id_produit
  WHERE ie.no_cellule = cellule_a_verifier;

  IF masse_actuelle > masse_max THEN
    RAISE EXCEPTION 'Masse stockée (% kg) dépasse la masse maximale de la cellule % (% kg).',
      masse_actuelle, cellule_a_verifier, masse_max;
  END IF;

  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_verifier_capacite_cellule
AFTER INSERT OR UPDATE OR DELETE ON inventaire_emplacement
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE FUNCTION verifier_capacite_cellule();
