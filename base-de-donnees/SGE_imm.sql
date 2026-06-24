/* ==========================================================================
   SGE_imm.sql
   Interface machine-machine (IMM) — vues et routines CRUD de base.
   Exécuter APRÈS SGE_cre.sql et SGE_inv.sql.
   Corrections v2 :
     - imm_supprimer_personnel  : paramètre varchar(7) (était integer)
     - imm_ajouter_produit      : RETURNS varchar(7) (était integer)
     - imm_supprimer_produit    : paramètre varchar(7) (était integer)
     - imm_ajouter_lot          : RETURNS varchar(7) (était integer)
     - imm_ajouter_organisation : paramètre type_organisation (inchangé, ok)
   ========================================================================== */

SET search_path TO sge;

/* ── Vues de consultation rapide ─────────────────────────────────────────── */

CREATE OR REPLACE VIEW imm_personnel AS
SELECT id_personnel, nom, prenom, sexe, adresse, telephone, date_enregistrement
FROM personnel;

CREATE OR REPLACE VIEW imm_produit AS
SELECT id_produit, nom, type, description, marque, modele, fournisseur
FROM produit;

CREATE OR REPLACE VIEW imm_stock AS
SELECT * FROM v_inventaire_produit;

CREATE OR REPLACE VIEW imm_cellules AS
SELECT * FROM v_inventaire_cellule;

/* ── Personnel ───────────────────────────────────────────────────────────── */

CREATE OR REPLACE FUNCTION imm_ajouter_personnel(
  p_nom            dom_nom,
  p_prenom         dom_nom,
  p_sexe           sexe_type,
  p_adresse        text          DEFAULT NULL,
  p_telephone      dom_telephone DEFAULT NULL,
  p_date_naissance date          DEFAULT NULL
)
RETURNS varchar(7)
LANGUAGE plpgsql AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  INSERT INTO personnel (nom, prenom, sexe, adresse, telephone, date_naissance)
  VALUES (p_nom, p_prenom, p_sexe, p_adresse, p_telephone, p_date_naissance)
  RETURNING id_personnel INTO nouvel_id;
  RETURN nouvel_id;
END;
$$;

CREATE OR REPLACE FUNCTION imm_modifier_personnel(
  p_id        varchar(7),
  p_nom       dom_nom,
  p_prenom    dom_nom,
  p_adresse   text,
  p_telephone dom_telephone
)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE personnel
  SET nom       = p_nom,
      prenom    = p_prenom,
      adresse   = p_adresse,
      telephone = p_telephone
  WHERE id_personnel = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Personnel % introuvable.', p_id;
  END IF;
END;
$$;

/* CORR: paramètre était INTEGER, doit être VARCHAR(7) */
CREATE OR REPLACE FUNCTION imm_supprimer_personnel(p_id varchar(7))
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM personnel WHERE id_personnel = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Personnel % introuvable.', p_id;
  END IF;
END;
$$;

/* ── Intervenants : organisation / externe ───────────────────────────────── */

CREATE OR REPLACE FUNCTION imm_ajouter_organisation(
  p_id_personnel varchar(7),
  p_type         type_organisation
)
RETURNS void
LANGUAGE sql AS $$
  INSERT INTO organisation (id_personnel, type_org)
  VALUES (p_id_personnel, p_type);
$$;

CREATE OR REPLACE FUNCTION imm_ajouter_externe(
  p_id_personnel varchar(7),
  p_role         dom_nom
)
RETURNS void
LANGUAGE sql AS $$
  INSERT INTO externe (id_personnel, role_externe)
  VALUES (p_id_personnel, p_role);
$$;

/* ── Produits ────────────────────────────────────────────────────────────── */

/* CORR: RETURNS était INTEGER, doit être VARCHAR(7) */
CREATE OR REPLACE FUNCTION imm_ajouter_produit(
  p_nom         dom_nom,
  p_type        type_produit,
  p_description text          DEFAULT NULL,
  p_marque      dom_nom       DEFAULT NULL,
  p_modele      dom_nom       DEFAULT NULL,
  p_fournisseur varchar(7)    DEFAULT NULL
)
RETURNS varchar(7)
LANGUAGE plpgsql AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  INSERT INTO produit (nom, type, description, marque, modele, fournisseur)
  VALUES (p_nom, p_type, p_description, p_marque, p_modele, p_fournisseur)
  RETURNING id_produit INTO nouvel_id;
  RETURN nouvel_id;
END;
$$;

CREATE OR REPLACE FUNCTION imm_modifier_produit(
  p_id          varchar(7),
  p_nom         dom_nom,
  p_description text,
  p_marque      dom_nom,
  p_modele      dom_nom
)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE produit
  SET nom         = p_nom,
      description = p_description,
      marque      = p_marque,
      modele      = p_modele
  WHERE id_produit = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Produit % introuvable.', p_id;
  END IF;
END;
$$;

/* CORR: paramètre était INTEGER, doit être VARCHAR(7) */
CREATE OR REPLACE FUNCTION imm_supprimer_produit(p_id varchar(7))
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM produit WHERE id_produit = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Produit % introuvable.', p_id;
  END IF;
END;
$$;

/* ── Lots ────────────────────────────────────────────────────────────────── */

/* CORR: RETURNS était INTEGER, doit être VARCHAR(7) (lot.id_lot est varchar(7)) */
CREATE OR REPLACE FUNCTION imm_ajouter_lot(
  p_id_produit varchar(7),
  p_quantite   dom_quantite
)
RETURNS varchar(7)
LANGUAGE plpgsql AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  INSERT INTO lot (id_produit, quantite)
  VALUES (p_id_produit, p_quantite)
  RETURNING id_lot INTO nouvel_id;
  RETURN nouvel_id;
END;
$$;

/* ── Entrepôt / zones / cellules ─────────────────────────────────────────── */

CREATE OR REPLACE FUNCTION imm_ajouter_entrepot(
  p_longueur       dom_mesure,
  p_largeur        dom_mesure,
  p_hauteur        dom_mesure,
  p_masse_maximale dom_mesure
)
RETURNS varchar(7)
LANGUAGE plpgsql AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  INSERT INTO entrepot (longueur, largeur, hauteur, masse_maximale)
  VALUES (p_longueur, p_largeur, p_hauteur, p_masse_maximale)
  RETURNING no_entrepot INTO nouvel_id;
  RETURN nouvel_id;
END;
$$;

CREATE OR REPLACE FUNCTION imm_ajouter_zone_stockage(
  p_no_entrepot varchar(7),
  p_nom         dom_nom,
  p_longueur    dom_mesure,
  p_largeur     dom_mesure,
  p_hauteur     dom_mesure,
  p_position    dom_nom
)
RETURNS varchar(7)
LANGUAGE plpgsql AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  INSERT INTO zone_stockage (no_entrepot, nom, longueur, largeur, hauteur, position)
  VALUES (p_no_entrepot, p_nom, p_longueur, p_largeur, p_hauteur, p_position)
  RETURNING no_zs INTO nouvel_id;
  RETURN nouvel_id;
END;
$$;

CREATE OR REPLACE FUNCTION imm_ajouter_cellule(
  p_no_zs          varchar(7),
  p_longueur       dom_mesure,
  p_largeur        dom_mesure,
  p_hauteur        dom_mesure,
  p_masse_maximale dom_mesure
)
RETURNS varchar(7)
LANGUAGE plpgsql AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  INSERT INTO cellule (no_zs, longueur, largeur, hauteur, masse_maximale)
  VALUES (p_no_zs, p_longueur, p_largeur, p_hauteur, p_masse_maximale)
  RETURNING no_cellule INTO nouvel_id;
  RETURN nouvel_id;
END;
$$;

/* ── Colis ───────────────────────────────────────────────────────────────── */

CREATE OR REPLACE FUNCTION imm_ajouter_colis(
  p_type            type_colis,
  p_no_chargement   varchar(7)  DEFAULT NULL,
  p_date_arrivee    timestamp   DEFAULT NULL,
  p_date_expedition timestamp   DEFAULT NULL
)
RETURNS varchar(7)
LANGUAGE plpgsql AS $$
DECLARE
  nouvel_id varchar(7);
BEGIN
  INSERT INTO colis (type, no_chargement, date_arrivee, date_expedition)
  VALUES (p_type, p_no_chargement, p_date_arrivee, p_date_expedition)
  RETURNING no_colis INTO nouvel_id;
  RETURN nouvel_id;
END;
$$;

CREATE OR REPLACE FUNCTION imm_ajouter_contenu_colis(
  p_no_colis   varchar(7),
  p_id_produit varchar(7),
  p_quantite   dom_quantite
)
RETURNS void
LANGUAGE sql AS $$
  INSERT INTO contenu_colis (no_colis, id_produit, qte_produit)
  VALUES (p_no_colis, p_id_produit, p_quantite);
$$;

CREATE OR REPLACE FUNCTION imm_supprimer_colis(p_no_colis varchar(7))
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM colis WHERE no_colis = p_no_colis;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Colis % introuvable.', p_no_colis;
  END IF;
END;
$$;
