/* ==========================================================================
   SGE_tra.sql
   Traitements proposés sous forme de routines de mise à jour.
   Exécuter APRÈS SGE_cre.sql, SGE_inv.sql et SGE_imm.sql.
   Corrections v2 :
     - tra_signaler_exception : procede_type → type_procede
     - UPDATE disponibilite   : 'occupée' → 'occupee' (cohérent avec l'enum)
     - tous les identifiants  : VARCHAR(7)
   ========================================================================== */

SET search_path TO sge;

/* ── T1 : stocker un lot dans une cellule ────────────────────────────────── */

CREATE OR REPLACE FUNCTION tra_stocker_lot(
  p_no_cellule varchar(7),
  p_id_lot     varchar(7),
  p_quantite   dom_quantite
)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO inventaire_emplacement (no_cellule, id_lot, quantite_stockee)
  VALUES (p_no_cellule, p_id_lot, p_quantite)
  ON CONFLICT (no_cellule, id_lot)
  DO UPDATE SET quantite_stockee =
      inventaire_emplacement.quantite_stockee + EXCLUDED.quantite_stockee;

  /* CORR: 'occupée' → 'occupee' (sans accent, cohérent avec l'enum type_disponibilite) */
  UPDATE cellule
  SET disponibilite = 'occupee'
  WHERE no_cellule = p_no_cellule;
END;
$$;

/* ── T2 : déstocker un lot d'une cellule ─────────────────────────────────── */

CREATE OR REPLACE FUNCTION tra_destocker_lot(
  p_no_cellule varchar(7),
  p_id_lot     varchar(7),
  p_quantite   dom_quantite
)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  qte_actuelle integer;
BEGIN
  SELECT quantite_stockee INTO qte_actuelle
  FROM inventaire_emplacement
  WHERE no_cellule = p_no_cellule AND id_lot = p_id_lot;

  IF qte_actuelle IS NULL THEN
    RAISE EXCEPTION 'Aucun stock pour le lot % dans la cellule %.', p_id_lot, p_no_cellule;
  END IF;

  IF qte_actuelle < p_quantite THEN
    RAISE EXCEPTION 'Stock insuffisant pour le lot % dans la cellule % : demandé %, disponible %.',
      p_id_lot, p_no_cellule, p_quantite, qte_actuelle;
  END IF;

  IF qte_actuelle = p_quantite THEN
    DELETE FROM inventaire_emplacement
    WHERE no_cellule = p_no_cellule AND id_lot = p_id_lot;
  ELSE
    UPDATE inventaire_emplacement
    SET quantite_stockee = quantite_stockee - p_quantite
    WHERE no_cellule = p_no_cellule AND id_lot = p_id_lot;
  END IF;

  /* Remettre la cellule à 'libre' si elle est maintenant vide */
  IF NOT EXISTS (
    SELECT 1 FROM inventaire_emplacement WHERE no_cellule = p_no_cellule
  ) THEN
    UPDATE cellule SET disponibilite = 'libre' WHERE no_cellule = p_no_cellule;
  END IF;
END;
$$;

/* ── T3 : transférer un lot d'une cellule à une autre ─────────────────────── */

CREATE OR REPLACE FUNCTION tra_transferer_stock(
  p_cellule_source      varchar(7),
  p_cellule_destination varchar(7),
  p_id_lot              varchar(7),
  p_quantite            dom_quantite
)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM tra_destocker_lot(p_cellule_source, p_id_lot, p_quantite);
  PERFORM tra_stocker_lot(p_cellule_destination, p_id_lot, p_quantite);
END;
$$;

/* ── T4 : réceptionner un colis (procédé 2.1.1 du mandat) ──────────────── */

CREATE OR REPLACE FUNCTION tra_receptionner_colis(
  p_no_colis       varchar(7),
  p_description_bon text
)
RETURNS varchar(7)
LANGUAGE plpgsql AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  UPDATE colis
  SET date_arrivee = COALESCE(date_arrivee, CURRENT_TIMESTAMP),
      type         = 'entrant'
  WHERE no_colis = p_no_colis;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Colis % introuvable.', p_no_colis;
  END IF;

  INSERT INTO bon_reception (no_colis, description_recep)
  VALUES (p_no_colis, p_description_bon)
  ON CONFLICT (no_colis)
  DO UPDATE SET description_recep = EXCLUDED.description_recep
  RETURNING id_bon_reception INTO nouvel_id;

  RETURN nouvel_id;
END;
$$;

/* ── T5 : expédier un colis (procédé 2.1.2 du mandat) ───────────────────── */

CREATE OR REPLACE FUNCTION tra_expedier_colis(
  p_no_colis        varchar(7),
  p_description_bon text
)
RETURNS varchar(7)
LANGUAGE plpgsql AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  UPDATE colis
  SET date_expedition = CURRENT_TIMESTAMP,
      type            = 'sortant'
  WHERE no_colis = p_no_colis;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Colis % introuvable.', p_no_colis;
  END IF;

  INSERT INTO bon_expedition (no_colis, description_exped)
  VALUES (p_no_colis, p_description_bon)
  ON CONFLICT (no_colis)
  DO UPDATE SET description_exped = EXCLUDED.description_exped
  RETURNING id_bon_expedition INTO nouvel_id;

  RETURN nouvel_id;
END;
$$;

/* ── T6 : signaler une exception ─────────────────────────────────────────── */

/* CORR: procede_type n'existe pas → type_procede */
CREATE OR REPLACE FUNCTION tra_signaler_exception(
  p_procede       type_procede,
  p_description   text,
  p_no_chargement varchar(7) DEFAULT NULL,
  p_no_colis      varchar(7) DEFAULT NULL
)
RETURNS varchar(7)
LANGUAGE plpgsql AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  IF p_no_chargement IS NULL AND p_no_colis IS NULL THEN
    RAISE EXCEPTION 'Un rapport d''exception doit référencer au moins un chargement ou un colis.';
  END IF;

  INSERT INTO rapport_exception (procede, description_rapport, no_chargement, no_colis)
  VALUES (p_procede, p_description, p_no_chargement, p_no_colis)
  RETURNING id_rapport INTO nouvel_id;
  RETURN nouvel_id;
END;
$$;
