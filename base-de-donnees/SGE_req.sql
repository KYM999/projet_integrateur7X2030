/*
  SGE_req.sql
  Requetes proposees sous forme de routines de selection.
  Executer apres SGE_cre.sql et SGE_inv.sql.
*/

SET search_path TO sge;

CREATE OR REPLACE FUNCTION req_stock_par_produit()
RETURNS TABLE (
  id_produit varchar(7),
  nom varchar,
  type type_produit,
  quantite_stockee integer
)
LANGUAGE sql
AS $$
  SELECT id_produit, nom::varchar, type, quantite_stockee
  FROM v_inventaire_produit
  ORDER BY nom;
$$;

CREATE OR REPLACE FUNCTION req_emplacements_produit(p_id_produit integer)
RETURNS TABLE (
  id_lot varchar(7),
  no_cellule integer,
  zone_stockage varchar,
  quantite_stockee integer
)
LANGUAGE sql
AS $$
  SELECT l.id_lot, c.no_cellule, zs.nom::varchar, ie.quantite_stockee
  FROM lot l
  JOIN inventaire_emplacement ie ON ie.id_lot = l.id_lot
  JOIN cellule c ON c.no_cellule = ie.no_cellule
  JOIN zone_stockage zs ON zs.no_zs = c.no_zs
  WHERE l.id_produit = p_id_produit
  ORDER BY zs.nom, c.no_cellule;
$$;

CREATE OR REPLACE FUNCTION req_cellules_disponibles()
RETURNS TABLE (
  no_cellule integer,
  zone_stockage varchar,
  masse_maximale numeric,
  masse_stockee numeric,
  disponibilite disponibilite
)
LANGUAGE sql
AS $$
  SELECT c.no_cellule, zs.nom::varchar, c.masse_maximale, voc.masse_stockee, c.disponibilite
  FROM cellule c
  JOIN zone_stockage zs ON zs.no_zs = c.no_zs
  JOIN v_occupation_cellule voc ON voc.no_cellule = c.no_cellule
  WHERE c.disponibilite IN ('libre', 'reservee')
  ORDER BY zs.nom, c.no_cellule;
$$;

CREATE OR REPLACE FUNCTION req_colis_en_reception()
RETURNS TABLE (
  no_colis integer,
  date_arrivee timestamp,
  nb_produits bigint,
  quantite_totale bigint
)
LANGUAGE sql
AS $$
  SELECT c.no_colis,
         c.date_arrivee,
         COUNT(cc.id_produit) AS nb_produits,
         COALESCE(SUM(cc.qte_produit), 0) AS quantite_totale
  FROM colis c
  LEFT JOIN contenu_colis cc ON cc.no_colis = c.no_colis
  WHERE c.type = 'entrant' AND c.date_expedition IS NULL
  GROUP BY c.no_colis, c.date_arrivee
  ORDER BY c.date_arrivee NULLS LAST, c.no_colis;
$$;

CREATE OR REPLACE FUNCTION req_colis_expedies()
RETURNS TABLE (
  no_colis integer,
  date_expedition timestamp,
  quantite_totale bigint
)
LANGUAGE sql
AS $$
  SELECT c.no_colis,
         c.date_expedition,
         COALESCE(SUM(cc.qte_produit), 0) AS quantite_totale
  FROM colis c
  LEFT JOIN contenu_colis cc ON cc.no_colis = c.no_colis
  WHERE c.type = 'sortant' AND c.date_expedition IS NOT NULL
  GROUP BY c.no_colis, c.date_expedition
  ORDER BY c.date_expedition DESC;
$$;

CREATE OR REPLACE FUNCTION req_rapports_exception()
RETURNS TABLE (
  id_rapport varchar(7),
  procede procede_type,
  no_chargement integer,
  no_colis integer,
  description_rapport text,
  date_rapport timestamp
)
LANGUAGE sql
AS $$
  SELECT id_rapport, procede, no_chargement, no_colis, description_rapport, date_rapport
  FROM rapport_exception
  ORDER BY date_rapport DESC, id_rapport DESC;
$$;
