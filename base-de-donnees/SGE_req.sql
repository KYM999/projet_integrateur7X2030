/* ==========================================================================
   SGE_req.sql
   Requêtes proposées sous forme de routines de sélection.
   Exécuter APRÈS SGE_cre.sql et SGE_inv.sql.
   Corrections v2 :
     - req_emplacements_produit : paramètre INTEGER → VARCHAR(7)
     - req_cellules_disponibles : 'reservee' absent de l'enum → filtre sur 'libre'
     - req_rapports_exception   : procede_type → type_procede
   ========================================================================== */

SET search_path TO sge;

/* ── R1 : stock global par produit ──────────────────────────────────────── */

CREATE OR REPLACE FUNCTION req_stock_par_produit()
RETURNS TABLE (
  id_produit       varchar(7),
  nom              varchar(50),
  type             type_produit,
  quantite_stockee integer
)
LANGUAGE sql AS $$
  SELECT id_produit, nom::varchar(50), type, quantite_stockee
  FROM v_inventaire_produit
  ORDER BY nom;
$$;

/* ── R2 : emplacements d'un produit donné ────────────────────────────────── */

/* CORR: paramètre était INTEGER, doit être VARCHAR(7) */
CREATE OR REPLACE FUNCTION req_emplacements_produit(p_id_produit varchar(7))
RETURNS TABLE (
  id_lot           varchar(7),
  no_cellule       varchar(7),
  zone_stockage    varchar(50),
  quantite_stockee integer
)
LANGUAGE sql AS $$
  SELECT l.id_lot, c.no_cellule, zs.nom::varchar(50), ie.quantite_stockee
  FROM lot l
  JOIN inventaire_emplacement ie ON ie.id_lot      = l.id_lot
  JOIN cellule c                 ON c.no_cellule   = ie.no_cellule
  JOIN zone_stockage zs          ON zs.no_zs       = c.no_zs
  WHERE l.id_produit = p_id_produit
  ORDER BY zs.nom, c.no_cellule;
$$;

/* ── R3 : cellules libres avec taux d'occupation ─────────────────────────── */

/* CORR: 'reservee' n'existe pas dans l'enum type_disponibilite → filtre sur 'libre' uniquement */
CREATE OR REPLACE FUNCTION req_cellules_disponibles()
RETURNS TABLE (
  no_cellule       varchar(7),
  zone_stockage    varchar(50),
  masse_maximale   numeric,
  masse_stockee    numeric,
  taux_occupation  numeric,
  disponibilite    type_disponibilite
)
LANGUAGE sql AS $$
  SELECT
    c.no_cellule,
    zs.nom::varchar(50),
    c.masse_maximale,
    voc.masse_stockee,
    voc.taux_occupation_masse,
    c.disponibilite
  FROM cellule c
  JOIN zone_stockage zs          ON zs.no_zs     = c.no_zs
  JOIN v_occupation_cellule voc  ON voc.no_cellule = c.no_cellule
  WHERE c.disponibilite = 'libre'
  ORDER BY zs.nom, c.no_cellule;
$$;

/* ── R4 : colis entrants en attente de stockage ──────────────────────────── */

CREATE OR REPLACE FUNCTION req_colis_en_reception()
RETURNS TABLE (
  no_colis         varchar(7),
  no_chargement    varchar(7),
  date_arrivee     timestamp,
  nb_produits      bigint,
  quantite_totale  bigint
)
LANGUAGE sql AS $$
  SELECT
    c.no_colis,
    c.no_chargement,
    c.date_arrivee,
    COUNT(cc.id_produit)            AS nb_produits,
    COALESCE(SUM(cc.qte_produit), 0) AS quantite_totale
  FROM colis c
  LEFT JOIN contenu_colis cc ON cc.no_colis = c.no_colis
  WHERE c.type = 'entrant'
  GROUP BY c.no_colis, c.no_chargement, c.date_arrivee
  ORDER BY c.date_arrivee NULLS LAST, c.no_colis;
$$;

/* ── R5 : colis sortants expédiés ─────────────────────────────────────────── */

CREATE OR REPLACE FUNCTION req_colis_expedies()
RETURNS TABLE (
  no_colis        varchar(7),
  date_expedition timestamp,
  quantite_totale bigint
)
LANGUAGE sql AS $$
  SELECT
    c.no_colis,
    c.date_expedition,
    COALESCE(SUM(cc.qte_produit), 0) AS quantite_totale
  FROM colis c
  LEFT JOIN contenu_colis cc ON cc.no_colis = c.no_colis
  WHERE c.type = 'sortant' AND c.date_expedition IS NOT NULL
  GROUP BY c.no_colis, c.date_expedition
  ORDER BY c.date_expedition DESC;
$$;

/* ── R6 : rapports d'exception (tous) ────────────────────────────────────── */

/* CORR: procede_type n'existe pas → type_procede */
CREATE OR REPLACE FUNCTION req_rapports_exception()
RETURNS TABLE (
  id_rapport          varchar(7),
  procede             type_procede,
  no_chargement       varchar(7),
  no_colis            varchar(7),
  description_rapport text,
  date_rapport        timestamp
)
LANGUAGE sql AS $$
  SELECT id_rapport, procede, no_chargement, no_colis, description_rapport, date_rapport
  FROM rapport_exception
  ORDER BY date_rapport DESC, id_rapport DESC;
$$;

/* ── R7 : suggestions de cellules pour stocker un produit matériel ────────── */

CREATE OR REPLACE FUNCTION req_suggerer_cellules(
  p_id_produit varchar(7),
  p_quantite   integer
)
RETURNS TABLE (
  no_cellule       varchar(7),
  zone_stockage    varchar(50),
  capacite_restante numeric
)
LANGUAGE sql AS $$
  SELECT
    c.no_cellule,
    zs.nom::varchar(50),
    c.masse_maximale - voc.masse_stockee AS capacite_restante
  FROM cellule c
  JOIN zone_stockage zs         ON zs.no_zs      = c.no_zs
  JOIN v_occupation_cellule voc ON voc.no_cellule = c.no_cellule
  JOIN produit_materiel pm      ON pm.id_produit  = p_id_produit
  WHERE c.disponibilite = 'libre'
    AND (c.masse_maximale - voc.masse_stockee) >= pm.masse * p_quantite
  ORDER BY capacite_restante ASC;
$$;
