/*
  SGE_tra.sql
  Traitements proposes sous forme de routines de mise a jour.
  Executer apres SGE_cre.sql, SGE_inv.sql et SGE_imm.sql.
*/

SET search_path TO sge;

CREATE OR REPLACE FUNCTION tra_stocker_lot(
  p_no_cellule integer,
  p_id_lot varchar(7),
  p_quantite dom_quantite
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO inventaire_emplacement (no_cellule, id_lot, quantite_stockee)
  VALUES (p_no_cellule, p_id_lot, p_quantite)
  ON CONFLICT (no_cellule, id_lot)
  DO UPDATE SET quantite_stockee = inventaire_emplacement.quantite_stockee + EXCLUDED.quantite_stockee;

  UPDATE cellule
  SET disponibilite = 'occupee'
  WHERE no_cellule = p_no_cellule;
END;
$$;

CREATE OR REPLACE FUNCTION tra_destocker_lot(
  p_no_cellule integer,
  p_id_lot varchar(7),
  p_quantite dom_quantite
)
RETURNS void
LANGUAGE plpgsql
AS $$
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
    RAISE EXCEPTION 'Stock insuffisant: demande %, disponible %.', p_quantite, qte_actuelle;
  END IF;

  IF qte_actuelle = p_quantite THEN
    DELETE FROM inventaire_emplacement
    WHERE no_cellule = p_no_cellule AND id_lot = p_id_lot;
  ELSE
    UPDATE inventaire_emplacement
    SET quantite_stockee = quantite_stockee - p_quantite
    WHERE no_cellule = p_no_cellule AND id_lot = p_id_lot;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM inventaire_emplacement WHERE no_cellule = p_no_cellule) THEN
    UPDATE cellule SET disponibilite = 'libre' WHERE no_cellule = p_no_cellule;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION tra_transferer_stock(
  p_cellule_source integer,
  p_cellule_destination integer,
  p_id_lot varchar(7),
  p_quantite dom_quantite
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM tra_destocker_lot(p_cellule_source, p_id_lot, p_quantite);
  PERFORM tra_stocker_lot(p_cellule_destination, p_id_lot, p_quantite);
END;
$$;

CREATE OR REPLACE FUNCTION tra_receptionner_colis(
  p_no_colis integer,
  p_description_bon text
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  UPDATE colis
  SET date_arrivee = COALESCE(date_arrivee, CURRENT_TIMESTAMP),
      type = 'entrant'
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

CREATE OR REPLACE FUNCTION tra_expedier_colis(
  p_no_colis integer,
  p_description_bon text
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  UPDATE colis
  SET date_expedition = CURRENT_TIMESTAMP,
      type = 'sortant'
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

CREATE OR REPLACE FUNCTION tra_signaler_exception(
  p_procede procede_type,
  p_description text,
  p_no_chargement integer DEFAULT NULL,
  p_no_colis integer DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  INSERT INTO rapport_exception (procede, description_rapport, no_chargement, no_colis)
  VALUES (p_procede, p_description, p_no_chargement, p_no_colis)
  RETURNING id_rapport INTO nouvel_id;
  RETURN nouvel_id;
END;
$$;
