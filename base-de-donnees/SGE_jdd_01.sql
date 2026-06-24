/* ==========================================================================
   SGE_jdd_01.sql
   Jeu de données complet n°1 — Entrepôt SAC, Douala.
   Couvre : personnel, organisation, externe, répertoire,
            entrepôt, zones, cellules, produits (3 types),
            lots, colis, contenus, bons, inventaire, rapports.
   Exécuter APRÈS SGE_cre.sql + SGE_inv.sql + SGE_imm.sql.
   ========================================================================== */

SET search_path TO sge;

/* ── 1. Personnel (7 personnes) ─────────────────────────────────────────── */

-- Identifiants fixés manuellement pour les tests reproductibles,
-- puis les séquences sont avancées via setval().
INSERT INTO personnel (id_personnel, nom, prenom, sexe, adresse, telephone, date_naissance, date_enregistrement) VALUES
  ('PER0001', 'Mbarga',   'Jean',    'M', 'Akwa, Douala',         '+237 699 001 001', '1985-03-14', '2023-01-10'),
  ('PER0002', 'Nkolo',    'Marie',   'F', 'Bonanjo, Douala',      '+237 677 002 002', '1990-07-22', '2023-01-10'),
  ('PER0003', 'Tchoua',   'Paul',    'M', 'Deido, Douala',        '+237 655 003 003', '1978-11-05', '2023-01-11'),
  ('PER0004', 'Essomba',  'Sophie',  'F', 'Bassa, Douala',        '+237 699 004 004', '1995-02-18', '2023-02-01'),
  ('PER0005', 'Abanda',   'Herve',   'M', 'Ngodi, Douala',        '+237 677 005 005', '1982-09-30', '2023-02-01'),
  ('PER0006', 'Kamgang',  'Alice',   'F', 'Yaounde centre',       '+237 655 006 006', '1988-06-12', '2023-03-15'),
  ('PER0007', 'Fotso',    'Denis',   'M', 'Bonaberi, Douala',     '+237 699 007 007', '1975-12-01', '2023-04-01');

SELECT setval('seq_per', 7);

/* ── 2. Organisations ───────────────────────────────────────────────────── */
-- PER0001 → organisation SAC (fournisseur/propriétaire)
-- PER0003 → transporteur
-- PER0006 → fournisseur externe

INSERT INTO organisation (id_personnel, type_org) VALUES
  ('PER0001', 'Partenaire'),
  ('PER0003', 'Transporteur'),
  ('PER0006', 'Fournisseur');

/* ── 3. Externes ──────────────────────────────────────────────────────────  */
-- PER0002 → magasinière (salariée SAC = externe dans la modélisation)
-- PER0004 → emballeuse
-- PER0005 → livreur
-- PER0007 → conducteur pour PER0003

INSERT INTO externe (id_personnel, role_externe) VALUES
  ('PER0002', 'Magasinier'),
  ('PER0004', 'Magasinier'),
  ('PER0005', 'Conducteur'),
  ('PER0007', 'Conducteur');

/* ── 4. Répertoire (association Organisation × Externe) ───────────────────  */
INSERT INTO repertoire (id_organisation, id_externe, role) VALUES
  ('PER0003', 'PER0007', 'Conducteur'),
  ('PER0001', 'PER0002', 'Magasinier'),
  ('PER0001', 'PER0004', 'Magasinier');

/* ── 5. Entrepôt ──────────────────────────────────────────────────────────  */
INSERT INTO entrepot (no_entrepot, longueur, largeur, hauteur, masse_maximale) VALUES
  ('ENT0001', 50.000, 20.000, 8.000, 50000.000);

SELECT setval('seq_ent', 1);

/* ── 6. Zones de stockage (E0, E1, E2, E3 du schéma du mandat) ────────────  */
INSERT INTO zone_stockage (no_zs, no_entrepot, nom, longueur, largeur, hauteur, position) VALUES
  ('ZNS0001', 'ENT0001', 'E0', 12.000, 18.000, 7.000, 'Centre'),
  ('ZNS0002', 'ENT0001', 'E1', 12.000, 18.000, 7.000, 'Nord'),
  ('ZNS0003', 'ENT0001', 'E2',  8.000, 18.000, 7.000, 'Est'),
  ('ZNS0004', 'ENT0001', 'E3', 12.000, 18.000, 7.000, 'Sud');

SELECT setval('seq_zns', 4);

/* ── 7. Zones fonctionnelles ─────────────────────────────────────────────  */
INSERT INTO zone_reception (id_zone_reception, no_entrepot, nom, role) VALUES
  ('ZNR0001', 'ENT0001', 'Zone reception', 'Déchargement entrant');

INSERT INTO zone_expedition (id_zone_expedition, no_entrepot, nom, role) VALUES
  ('ZNE0001', 'ENT0001', 'Zone expedition', 'Chargement sortant');

SELECT setval('seq_znr', 1);
SELECT setval('seq_zne', 1);

/* ── 8. Cellules (3 par zone E0 et E1, 2 par E2 et E3) ──────────────────  */
INSERT INTO cellule (no_cellule, no_zs, disponibilite, longueur, largeur, hauteur, masse_maximale) VALUES
  ('CEL0001', 'ZNS0001', 'libre',        120.000, 80.000, 200.000, 500.000),
  ('CEL0002', 'ZNS0001', 'libre',        120.000, 80.000, 200.000, 500.000),
  ('CEL0003', 'ZNS0001', 'indisponible', 120.000, 80.000, 200.000, 500.000),
  ('CEL0004', 'ZNS0002', 'libre',        100.000, 80.000, 180.000, 300.000),
  ('CEL0005', 'ZNS0002', 'libre',        100.000, 80.000, 180.000, 300.000),
  ('CEL0006', 'ZNS0002', 'libre',        100.000, 80.000, 180.000, 300.000),
  ('CEL0007', 'ZNS0003', 'libre',         80.000, 60.000, 150.000, 200.000),
  ('CEL0008', 'ZNS0003', 'libre',         80.000, 60.000, 150.000, 200.000),
  ('CEL0009', 'ZNS0004', 'libre',        120.000, 80.000, 200.000, 500.000),
  ('CEL0010', 'ZNS0004', 'libre',        120.000, 80.000, 200.000, 500.000);

SELECT setval('seq_cel', 10);

/* ── 9. Produits (3 matériels + 1 logiciel + 2 emballages) ──────────────  */
INSERT INTO produit (id_produit, nom, description, marque, modele, fournisseur, type) VALUES
  ('PRD0001', 'Ordinateur portable', 'Laptop 15 pouces',        'Dell',   'Inspiron 15',  'PER0006', 'materiel'),
  ('PRD0002', 'Ecran PC 24"',        'Moniteur Full HD',        'LG',     '24MK400',      'PER0006', 'materiel'),
  ('PRD0003', 'Clavier USB',         'Clavier azerty filaire',  'Logitech','K120',         'PER0006', 'materiel'),
  ('PRD0004', 'Suite bureautique',   'Licence Office 365',      'Microsoft','Office 365',  'PER0006', 'logiciel'),
  ('PRD0005', 'Boite carton L',      'Carton 60x40x40 cm',      NULL,     NULL,            NULL,      'emballage'),
  ('PRD0006', 'Film plastique',      'Film bulles 50m',         NULL,     NULL,            NULL,      'emballage');

SELECT setval('seq_prd', 6);

/* ── 10. Spécialisations produit ─────────────────────────────────────────  */
INSERT INTO produit_materiel (id_produit, longueur, largeur, hauteur, masse) VALUES
  ('PRD0001', 37.000,  2.200, 24.000, 2.100),
  ('PRD0002', 56.000,  4.500, 34.000, 4.800),
  ('PRD0003', 45.000,  2.100, 15.000, 0.850);

INSERT INTO produit_logiciel (id_produit, version, description_log, editeur, taille) VALUES
  ('PRD0004', '16.0.1', 'Suite Office avec Word, Excel, PowerPoint', 'Microsoft', 4096.000);

INSERT INTO produit_emballage (id_produit, nouveau) VALUES
  ('PRD0005', true),
  ('PRD0006', true);

/* ── 11. Chargements ─────────────────────────────────────────────────────  */
INSERT INTO chargement (no_chargement, livreur, procede, date_chargement) VALUES
  ('CHG0001', 'PER0005', 'reception',  '2024-06-10 08:30:00'),
  ('CHG0002', 'PER0007', 'expedition', '2024-06-12 14:00:00');

SELECT setval('seq_chg', 2);

/* ── 12. Colis ────────────────────────────────────────────────────────────  */
INSERT INTO colis (no_colis, no_chargement, date_arrivee, date_expedition, type) VALUES
  ('COL0001', 'CHG0001', '2024-06-10 09:00:00', NULL,                   'entrant'),
  ('COL0002', 'CHG0001', '2024-06-10 09:05:00', NULL,                   'entrant'),
  ('COL0003', 'CHG0002', NULL,                   '2024-06-12 15:00:00', 'sortant');

SELECT setval('seq_col', 3);

/* ── 13. Contenu des colis ───────────────────────────────────────────────  */
INSERT INTO contenu_colis (no_colis, id_produit, qte_produit) VALUES
  ('COL0001', 'PRD0001',  5),   -- 5 laptops Dell
  ('COL0001', 'PRD0005', 10),   -- 10 boites carton
  ('COL0002', 'PRD0002',  8),   -- 8 écrans LG
  ('COL0002', 'PRD0003', 20),   -- 20 claviers
  ('COL0003', 'PRD0001',  3);   -- 3 laptops en sortie

/* ── 14. Lots (stock constitué après réception COL0001 et COL0002) ────────  */
INSERT INTO lot (id_lot, id_produit, quantite) VALUES
  ('LOT0001', 'PRD0001', 5),
  ('LOT0002', 'PRD0002', 8),
  ('LOT0003', 'PRD0003', 20);

SELECT setval('seq_lot', 3);

/* ── 15. Inventaire emplacement ──────────────────────────────────────────  */
INSERT INTO inventaire_emplacement (no_cellule, id_lot, quantite_stockee) VALUES
  ('CEL0001', 'LOT0001', 5),   -- 5 laptops dans CEL0001
  ('CEL0004', 'LOT0002', 8),   -- 8 écrans dans CEL0004
  ('CEL0005', 'LOT0003', 20);  -- 20 claviers dans CEL0005

-- Mise à jour cohérente de la disponibilité
UPDATE cellule SET disponibilite = 'occupee'
WHERE no_cellule IN ('CEL0001', 'CEL0004', 'CEL0005');

/* ── 16. Bons de réception ───────────────────────────────────────────────  */
INSERT INTO bon_reception (id_bon_reception, no_colis, description_recep) VALUES
  ('BRC0001', 'COL0001', 'Réception conforme — 5 laptops Dell + 10 boites carton'),
  ('BRC0002', 'COL0002', 'Réception conforme — 8 écrans LG + 20 claviers Logitech');

SELECT setval('seq_brc', 2);

/* ── 17. Bon d'expédition ─────────────────────────────────────────────────  */
INSERT INTO bon_expedition (id_bon_expedition, no_colis, description_exped) VALUES
  ('BEX0001', 'COL0003', 'Expédition — 3 laptops Dell vers client Akwa');

SELECT setval('seq_bex', 1);

/* ── 18. Rapport d'exception (1 exemple) ──────────────────────────────────  */
INSERT INTO rapport_exception (id_rapport, no_chargement, no_colis, description_rapport, procede, date_rapport) VALUES
  ('RAP0001', 'CHG0001', 'COL0001',
   'Écart constaté : bon de réception prévoyait 6 laptops, seulement 5 reçus.',
   'reception', '2024-06-10 09:15:00');

SELECT setval('seq_rap', 1);

/* ── Vérifications rapides post-insertion ─────────────────────────────────  */
DO $$
BEGIN
  ASSERT (SELECT COUNT(*) FROM personnel)              = 7,  'Nb personnel incorrect';
  ASSERT (SELECT COUNT(*) FROM produit)                = 6,  'Nb produits incorrect';
  ASSERT (SELECT COUNT(*) FROM cellule)                = 10, 'Nb cellules incorrect';
  ASSERT (SELECT COUNT(*) FROM inventaire_emplacement) = 3,  'Nb emplacements incorrect';
  RAISE NOTICE 'JDD_01 : toutes les assertions passent.';
END;
$$;
