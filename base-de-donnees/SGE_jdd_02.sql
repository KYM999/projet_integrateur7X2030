/* =============================================================================
   SGE_jdd_02.sql
   Jeu de données complet pour l'application SGE — Amazones & Centaures.
   
   Contient :
     • 11 comptes opérationnels (2 magasiniers, 2 agents logistiques,
       1 resp. informatique, 3 emballeurs externes, 1 resp. stocks,
       1 resp. logistique, 1 admin)
     • 5 fournisseurs + 2 transporteurs (organisations)
     • 2 livreurs externes
     • 1 entrepôt, 4 zones de stockage, 20 cellules
     • 150 produits (90 matériels, 30 logiciels, 30 emballages)
     • 150 lots (un par produit)
     • 12 chargements, 50 colis
     • Contenu des colis, inventaire, bons, rapports d'exception
   
   Exécution : après SGE_cre.sql + SGE_inv.sql + SGE_imm.sql + SGE_ajout.sql
   ============================================================================= */

SET search_path TO sge;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

/* S'assurer que la colonne mot_de_passe existe même sans SGE_ajout.sql */
ALTER TABLE personnel ADD COLUMN IF NOT EXISTS mot_de_passe text;

/* ─────────────────────────────────────────────────────────────────────────────
   REMISE À ZÉRO (ordre de suppression respectant les clés étrangères)
   ───────────────────────────────────────────────────────────────────────────── */
TRUNCATE TABLE rapport_exception      CASCADE;
TRUNCATE TABLE bon_expedition         CASCADE;
TRUNCATE TABLE bon_reception          CASCADE;
TRUNCATE TABLE inventaire_emplacement CASCADE;
TRUNCATE TABLE contenu_colis          CASCADE;
TRUNCATE TABLE lot                    CASCADE;
TRUNCATE TABLE produit_emballage      CASCADE;
TRUNCATE TABLE produit_logiciel       CASCADE;
TRUNCATE TABLE produit_materiel       CASCADE;
TRUNCATE TABLE produit                CASCADE;
TRUNCATE TABLE colis                  CASCADE;
TRUNCATE TABLE chargement             CASCADE;
TRUNCATE TABLE cellule                CASCADE;
TRUNCATE TABLE zone_stockage          CASCADE;
TRUNCATE TABLE zone_expedition        CASCADE;
TRUNCATE TABLE zone_reception         CASCADE;
TRUNCATE TABLE entrepot               CASCADE;
TRUNCATE TABLE repertoire             CASCADE;
TRUNCATE TABLE externe                CASCADE;
TRUNCATE TABLE organisation           CASCADE;
TRUNCATE TABLE personnel              CASCADE;

/* Remise à zéro de toutes les séquences */
SELECT setval('seq_per', 1, false);
SELECT setval('seq_lot', 1, false);
SELECT setval('seq_prd', 1, false);
SELECT setval('seq_ent', 1, false);
SELECT setval('seq_zns', 1, false);
SELECT setval('seq_znr', 1, false);
SELECT setval('seq_zne', 1, false);
SELECT setval('seq_cel', 1, false);
SELECT setval('seq_col', 1, false);
SELECT setval('seq_chg', 1, false);
SELECT setval('seq_brc', 1, false);
SELECT setval('seq_bex', 1, false);
SELECT setval('seq_rap', 1, false);

/* =============================================================================
   1. PERSONNEL
   ============================================================================= */

INSERT INTO personnel
  (id_personnel, nom, prenom, sexe, adresse, telephone, date_naissance)
VALUES
  /* ── Magasiniers ── */
  ('PER0001','Mbarga',     'Jean',       'M','Akwa, Douala',             '+237 699 101 101','1985-03-14'),
  ('PER0002','Nkolo',      'Marie',      'F','Bonanjo, Douala',          '+237 677 102 102','1990-07-22'),
  /* ── Agents logistiques ── */
  ('PER0003','Tchoua',     'Paul',       'M','Deido, Douala',            '+237 655 103 103','1978-11-05'),
  ('PER0004','Essomba',    'Sophie',     'F','Bassa, Douala',            '+237 699 104 104','1995-02-18'),
  /* ── Responsable informatique ── */
  ('PER0005','Abanda',     'Henri',      'M','Ngodi, Douala',            '+237 677 105 105','1982-09-30'),
  /* ── Emballeurs externes ── */
  ('PER0006','Kamgang',    'Alice',      'F','Yaounde Centre',           '+237 655 106 106','1988-06-12'),
  ('PER0007','Fotso',      'Denis',      'M','Bonaberi, Douala',         '+237 699 107 107','1975-12-01'),
  ('PER0008','Onana',      'Grace',      'F','Logbessou, Douala',        '+237 677 108 108','1993-04-25'),
  /* ── Responsable des stocks ── */
  ('PER0009','Talla',      'Robert',     'M','Bonapriso, Douala',        '+237 655 109 109','1972-08-19'),
  /* ── Responsable logistique ── */
  ('PER0010','Owona',      'Francoise',  'F','Makepe, Douala',           '+237 699 110 110','1980-01-07'),
  /* ── Administrateur ── */
  ('PER0011','Dongo',      'Alain',      'M','Bonamoussadi, Douala',     '+237 677 111 111','1968-05-30'),
  /* ── Fournisseurs (seront aussi dans ORGANISATION) ── */
  ('PER0012','TechnoMart', 'SARL',       'M','Zone Industrielle, DLA',   '+237 233 112 112', NULL),
  ('PER0013','InfoTech',   'Congo',      'M','Brazzaville, Congo',       '+242 066 113 113', NULL),
  ('PER0014','BuroPro',    'Cameroun',   'M','Yaounde, Centre',          '+237 222 114 114', NULL),
  ('PER0015','ElectroParts','SA',        'M','Port de Douala',           '+237 233 115 115', NULL),
  ('PER0016','PackSolutions','Ltd',      'M','Bonaberi, Douala',         '+237 233 116 116', NULL),
  /* ── Transporteurs ── */
  ('PER0017','TransLog',   'Douala',     'M','Akwa Nord, Douala',        '+237 233 117 117', NULL),
  ('PER0018','RapidoCargo','SA',         'M','Port de Douala',           '+237 233 118 118', NULL),
  /* ── Livreurs externes ── */
  ('PER0019','Kono',       'Sylvestre',  'M','Nkongmondo, Douala',       '+237 699 119 119','1987-02-14'),
  ('PER0020','Messi',      'Bertrand',   'M','Logpom, Douala',           '+237 677 120 120','1984-11-22');

SELECT setval('seq_per', 20);

/* ── Mots de passe ── */
UPDATE personnel SET mot_de_passe = crypt('magasin123',  gen_salt('bf',10)) WHERE id_personnel IN ('PER0001','PER0002');
UPDATE personnel SET mot_de_passe = crypt('agent123',    gen_salt('bf',10)) WHERE id_personnel IN ('PER0003','PER0004');
UPDATE personnel SET mot_de_passe = crypt('respinfo123', gen_salt('bf',10)) WHERE id_personnel  = 'PER0005';
UPDATE personnel SET mot_de_passe = crypt('embal123',    gen_salt('bf',10)) WHERE id_personnel IN ('PER0006','PER0007','PER0008');
UPDATE personnel SET mot_de_passe = crypt('respstock123',gen_salt('bf',10)) WHERE id_personnel  = 'PER0009';
UPDATE personnel SET mot_de_passe = crypt('resplog123',  gen_salt('bf',10)) WHERE id_personnel  = 'PER0010';
UPDATE personnel SET mot_de_passe = crypt('Admin@2024',  gen_salt('bf',10)) WHERE id_personnel  = 'PER0011';

/* =============================================================================
   2. ORGANISATIONS (fournisseurs + transporteurs)
   ============================================================================= */

INSERT INTO organisation (id_personnel, type_org) VALUES
  ('PER0012','Fournisseur'),
  ('PER0013','Fournisseur'),
  ('PER0014','Fournisseur'),
  ('PER0015','Fournisseur'),
  ('PER0016','Fournisseur'),
  ('PER0017','Transporteur'),
  ('PER0018','Transporteur');

/* =============================================================================
   3. ROLES DES INTERVENANTS (internes + externes)
   ============================================================================= */

INSERT INTO externe (id_personnel, role_externe) VALUES
  ('PER0001','Magasinier'),
  ('PER0002','Magasinier'),
  ('PER0003','Agent logistique'),
  ('PER0004','Agent logistique'),
  ('PER0005','Responsable informatique'),
  ('PER0006','Emballeur'),
  ('PER0007','Emballeur'),
  ('PER0008','Emballeur'),
  ('PER0009','Responsable stocks'),
  ('PER0010','Responsable logistique'),
  ('PER0011','Administrateur'),
  ('PER0019','Livreur'),
  ('PER0020','Livreur');

/* =============================================================================
   4. RÉPERTOIRE (appartenance organisation–externe)
   ============================================================================= */

INSERT INTO repertoire (id_organisation, id_externe, role) VALUES
  ('PER0017','PER0019','Livreur'),
  ('PER0018','PER0020','Livreur');

/* =============================================================================
   5. ENTREPÔT
   ============================================================================= */

INSERT INTO entrepot (no_entrepot, longueur, largeur, hauteur, masse_maximale)
VALUES ('ENT0001', 80.000, 30.000, 10.000, 120000.000);

SELECT setval('seq_ent', 1);

/* =============================================================================
   6. ZONES FONCTIONNELLES
   ============================================================================= */

INSERT INTO zone_reception (id_zone_reception, no_entrepot, nom, role)
VALUES ('ZNR0001','ENT0001','Zone Réception','Déchargement et contrôle entrant');

INSERT INTO zone_expedition (id_zone_expedition, no_entrepot, nom, role)
VALUES ('ZNE0001','ENT0001','Zone Expédition','Préparation et chargement sortant');

SELECT setval('seq_znr', 1);
SELECT setval('seq_zne', 1);

/* =============================================================================
   7. ZONES DE STOCKAGE (E0 → E3)
   ============================================================================= */

INSERT INTO zone_stockage (no_zs, no_entrepot, nom, longueur, largeur, hauteur, position) VALUES
  ('ZNS0001','ENT0001','E0', 20.000, 28.000, 9.000,'Nord-Ouest'),
  ('ZNS0002','ENT0001','E1', 20.000, 28.000, 9.000,'Nord-Est'),
  ('ZNS0003','ENT0001','E2', 18.000, 28.000, 9.000,'Sud-Ouest'),
  ('ZNS0004','ENT0001','E3', 18.000, 28.000, 9.000,'Sud-Est');

SELECT setval('seq_zns', 4);

/* =============================================================================
   8. CELLULES (5 par zone = 20 cellules)
   ============================================================================= */

INSERT INTO cellule (no_cellule, no_zs, disponibilite, longueur, largeur, hauteur, masse_maximale) VALUES
  /* Zone E0 — 5 cellules */
  ('CEL0001','ZNS0001','occupee',     150.000, 100.000, 220.000, 800.000),
  ('CEL0002','ZNS0001','occupee',     150.000, 100.000, 220.000, 800.000),
  ('CEL0003','ZNS0001','libre',       150.000, 100.000, 220.000, 800.000),
  ('CEL0004','ZNS0001','libre',       150.000, 100.000, 220.000, 800.000),
  ('CEL0005','ZNS0001','indisponible',150.000, 100.000, 220.000, 800.000),
  /* Zone E1 — 5 cellules */
  ('CEL0006','ZNS0002','occupee',     120.000,  90.000, 200.000, 600.000),
  ('CEL0007','ZNS0002','occupee',     120.000,  90.000, 200.000, 600.000),
  ('CEL0008','ZNS0002','occupee',     120.000,  90.000, 200.000, 600.000),
  ('CEL0009','ZNS0002','libre',       120.000,  90.000, 200.000, 600.000),
  ('CEL0010','ZNS0002','libre',       120.000,  90.000, 200.000, 600.000),
  /* Zone E2 — 5 cellules */
  ('CEL0011','ZNS0003','occupee',     100.000,  80.000, 180.000, 400.000),
  ('CEL0012','ZNS0003','occupee',     100.000,  80.000, 180.000, 400.000),
  ('CEL0013','ZNS0003','libre',       100.000,  80.000, 180.000, 400.000),
  ('CEL0014','ZNS0003','libre',       100.000,  80.000, 180.000, 400.000),
  ('CEL0015','ZNS0003','libre',       100.000,  80.000, 180.000, 400.000),
  /* Zone E3 — 5 cellules */
  ('CEL0016','ZNS0004','libre',       130.000,  90.000, 210.000, 700.000),
  ('CEL0017','ZNS0004','libre',       130.000,  90.000, 210.000, 700.000),
  ('CEL0018','ZNS0004','libre',       130.000,  90.000, 210.000, 700.000),
  ('CEL0019','ZNS0004','libre',       130.000,  90.000, 210.000, 700.000),
  ('CEL0020','ZNS0004','libre',       130.000,  90.000, 210.000, 700.000);

SELECT setval('seq_cel', 20);

/* =============================================================================
   9. PRODUITS + SPÉCIALISATIONS + LOTS  (bloc DO — 150 produits)
   ============================================================================= */

DO $$
DECLARE
  i          integer;
  v_id       varchar(7);
  v_lot_id   varchar(7);
  v_fournisseur varchar(7);

  /* ── Données produits matériels (90) ── */
  noms_mat   text[] := ARRAY[
    'Ordinateur portable','Ecran LCD 24"','Clavier mecanique','Souris sans fil',
    'Imprimante laser','Scanner A4','Routeur WiFi 6','Switch 24 ports',
    'Serveur rack 2U','Tablette 10 pouces','Telephone IP','Onduleur 1500VA',
    'Cable HDMI 2m','Hub USB-C 7 ports','Disque dur externe 2TB',
    'Cle USB 128GB','Carte memoire 256GB','Webcam 4K','Casque Bluetooth',
    'Projecteur 4K','Bras moniteur double','Station d accueil USB-C',
    'SSD NVMe 1TB','Carte reseau 10Gbps','Batterie externe 20000mAh',
    'Lecteur code-barres 2D','Balance electronique','Ecran tactile 21"',
    'Mini PC','Imprimante thermique'
  ];
  marques_mat text[] := ARRAY[
    'Dell','LG','Logitech','HP','Canon','Epson','Cisco','D-Link',
    'Lenovo','Samsung','Panasonic','APC','Ugreen','Anker','Seagate',
    'Kingston','SanDisk','Logitech','Sony','Optoma','Ergotron','Dell',
    'Samsung','Intel','Baseus','Zebra','Kern','ViewSonic','Intel','Star'
  ];
  modeles_mat text[] := ARRAY[
    'Inspiron 15','27MK400','K835','M750','LaserJet Pro','GT-S50',
    'AX3000','SG300','PowerEdge R340','Galaxy Tab','SPA50G','SUA1500',
    '2.0 v2','CB-C71','Expansion','IronKey','Extreme Pro','C920','H800',
    'EH500','LX45','D6000','980 Pro','X550-T1','PD100W','DS8178',
    'PCB 2500','TD2455','NUC11','TSP100'
  ];

  /* ── Données produits logiciels (30) ── */
  noms_log   text[] := ARRAY[
    'Suite bureautique Office','Antivirus Kaspersky','SGBD PostgreSQL Pro',
    'IDE IntelliJ IDEA','Logiciel comptabilite Sage','ERP Odoo Enterprise',
    'CRM HubSpot','OS Windows 11 Pro','Adobe Creative Suite',
    'Logiciel CAO AutoCAD','VPN FortiClient','Backup Acronis',
    'Monitoring Zabbix','Gestion projet Jira','Signature DocuSign',
    'Antivirus Bitdefender','Suite LibreOffice','SGBD MySQL Enterprise',
    'IDE Eclipse','Comptabilite QuickBooks','Gestion RH Sage',
    'BI PowerBI','Securite firewall PfSense','Virtualisation VMware',
    'Collaboration Teams','Stockage OneDrive','Email Exchange',
    'Antivirus ESET','Suite bureautique Google Workspace','ERP SAP Business'
  ];
  editeurs_log text[] := ARRAY[
    'Microsoft','Kaspersky','PostgreSQL Global','JetBrains','Sage','Odoo SA',
    'HubSpot','Microsoft','Adobe','Autodesk','Fortinet','Acronis',
    'Zabbix LLC','Atlassian','DocuSign','Bitdefender','The Document Foundation',
    'Oracle','Eclipse Foundation','Intuit','Sage','Microsoft','Netgate',
    'VMware','Microsoft','Microsoft','Microsoft','ESET','Google','SAP'
  ];

  /* ── Données produits emballage (30) ── */
  noms_emb   text[] := ARRAY[
    'Boite carton XS 20x15x10','Boite carton S 30x20x15','Boite carton M 40x30x25',
    'Boite carton L 60x40x40','Boite carton XL 80x60x50','Boite carton XXL 100x80x60',
    'Film plastique etirable 50m','Film plastique etirable 100m','Papier bulle 25m',
    'Papier bulle 50m','Ruban adhesif standard 50m','Ruban adhesif fort 50m',
    'Mousse protectrice 1cm','Mousse protectrice 3cm','Sac plastique 20L',
    'Sac plastique 50L','Palette bois 80x120','Palette bois 100x120',
    'Cerclage plastique 100m','Cerclage metallique 50m','Etiquettes adhesives 1000',
    'Coussins air 20x30','Angles carton renforcee','Bandelette adhesive 100m',
    'Enveloppe bulle C4','Enveloppe bulle A4','Tube carton 5x50cm',
    'Intercalaire carton 2mm','Filet protection 10m','Sac non-tisse 40x50'
  ];

  /* Fournisseurs pour rotation */
  fournisseurs varchar(7)[] := ARRAY['PER0012','PER0013','PER0014','PER0015','PER0016'];

BEGIN
  /* ── 90 produits matériels ── */
  FOR i IN 1..90 LOOP
    v_id          := gen_id('PRD', 'seq_prd');
    v_fournisseur := fournisseurs[((i-1) % 5) + 1];

    INSERT INTO produit (id_produit, nom, description, marque, modele, fournisseur, type)
    VALUES (
      v_id,
      noms_mat[((i-1) % array_length(noms_mat, 1)) + 1] || ' - S' || LPAD(i::text,2,'0'),
      'Ref. catalogue : CAT-MAT-' || LPAD(i::text, 4, '0'),
      marques_mat[((i-1) % array_length(marques_mat, 1)) + 1],
      modeles_mat[((i-1) % array_length(modeles_mat, 1)) + 1] || '-' || i,
      v_fournisseur,
      'materiel'
    );

    INSERT INTO produit_materiel (id_produit, longueur, largeur, hauteur, masse)
    VALUES (
      v_id,
      (25 + (i % 40))::numeric(12,3),
      (15 + (i % 25))::numeric(12,3),
      ( 3 + (i % 15))::numeric(12,3),
      (0.3 + ((i % 12) * 0.6))::numeric(12,3)
    );

    /* Lot associé : 20 à 80 unités */
    v_lot_id := gen_id('LOT', 'seq_lot');
    INSERT INTO lot (id_lot, id_produit, quantite)
    VALUES (v_lot_id, v_id, 20 + ((i * 3) % 61));
  END LOOP;

  /* ── 30 produits logiciels ── */
  FOR i IN 1..30 LOOP
    v_id          := gen_id('PRD', 'seq_prd');
    v_fournisseur := fournisseurs[((i-1) % 5) + 1];

    INSERT INTO produit (id_produit, nom, description, marque, modele, fournisseur, type)
    VALUES (
      v_id,
      noms_log[((i-1) % array_length(noms_log, 1)) + 1] || ' v' || (2020 + (i % 5)),
      'Licence annuelle — ref. LOG-' || LPAD(i::text, 3, '0'),
      editeurs_log[((i-1) % array_length(editeurs_log, 1)) + 1],
      'v' || (2020 + (i % 5)) || '.' || ((i % 3) + 1),
      v_fournisseur,
      'logiciel'
    );

    INSERT INTO produit_logiciel (id_produit, version, description_log, editeur, taille)
    VALUES (
      v_id,
      (2020 + (i % 5))::text || '.' || ((i % 3) + 1) || '.0',
      'Licence monoposte — ref. LOG-' || LPAD(i::text, 3, '0'),
      editeurs_log[((i-1) % array_length(editeurs_log, 1)) + 1],
      (512 + ((i % 8) * 768))::numeric(12,3)
    );

    /* Lot associé : 5 à 25 licences */
    v_lot_id := gen_id('LOT', 'seq_lot');
    INSERT INTO lot (id_lot, id_produit, quantite)
    VALUES (v_lot_id, v_id, 5 + ((i * 2) % 21));
  END LOOP;

  /* ── 30 produits emballage ── */
  FOR i IN 1..30 LOOP
    v_id := gen_id('PRD', 'seq_prd');

    INSERT INTO produit (id_produit, nom, description, marque, modele, fournisseur, type)
    VALUES (
      v_id,
      noms_emb[((i-1) % array_length(noms_emb, 1)) + 1],
      'Materiel emballage — ref. EMB-' || LPAD(i::text, 3, '0'),
      NULL,
      NULL,
      'PER0016',   /* PackSolutions fournit tous les emballages */
      'emballage'
    );

    INSERT INTO produit_emballage (id_produit, nouveau)
    VALUES (v_id, (i % 3 <> 0));   /* 2/3 neufs, 1/3 récupérés */

    /* Lot associé : 50 à 200 unités */
    v_lot_id := gen_id('LOT', 'seq_lot');
    INSERT INTO lot (id_lot, id_produit, quantite)
    VALUES (v_lot_id, v_id, 50 + ((i * 7) % 151));
  END LOOP;

END;
$$;

/* =============================================================================
   10. CHARGEMENTS (8 réception + 4 expédition)
   ============================================================================= */

INSERT INTO chargement (no_chargement, livreur, procede, date_chargement) VALUES
  /* Réceptions */
  ('CHG0001','PER0019','reception',  '2024-05-05 07:30:00'),
  ('CHG0002','PER0020','reception',  '2024-05-12 08:00:00'),
  ('CHG0003','PER0019','reception',  '2024-05-20 07:45:00'),
  ('CHG0004','PER0020','reception',  '2024-05-28 08:15:00'),
  ('CHG0005','PER0019','reception',  '2024-06-03 07:00:00'),
  ('CHG0006','PER0020','reception',  '2024-06-10 08:30:00'),
  ('CHG0007','PER0019','reception',  '2024-06-17 07:20:00'),
  ('CHG0008','PER0020','reception',  '2024-06-22 09:00:00'),
  /* Expéditions */
  ('CHG0009','PER0019','expedition', '2024-05-15 14:00:00'),
  ('CHG0010','PER0020','expedition', '2024-05-30 13:30:00'),
  ('CHG0011','PER0019','expedition', '2024-06-14 15:00:00'),
  ('CHG0012','PER0020','expedition', '2024-06-24 14:45:00');

SELECT setval('seq_chg', 12);

/* =============================================================================
   11. COLIS (35 entrants + 15 sortants = 50)
   ============================================================================= */

INSERT INTO colis (no_colis, no_chargement, date_arrivee, date_expedition, type) VALUES
  /* ── Colis entrants (réception) ── */
  ('COL0001','CHG0001','2024-05-05 08:00:00', NULL,'entrant'),
  ('COL0002','CHG0001','2024-05-05 08:05:00', NULL,'entrant'),
  ('COL0003','CHG0001','2024-05-05 08:10:00', NULL,'entrant'),
  ('COL0004','CHG0001','2024-05-05 08:15:00', NULL,'entrant'),
  ('COL0005','CHG0002','2024-05-12 08:30:00', NULL,'entrant'),
  ('COL0006','CHG0002','2024-05-12 08:35:00', NULL,'entrant'),
  ('COL0007','CHG0002','2024-05-12 08:40:00', NULL,'entrant'),
  ('COL0008','CHG0003','2024-05-20 08:00:00', NULL,'entrant'),
  ('COL0009','CHG0003','2024-05-20 08:05:00', NULL,'entrant'),
  ('COL0010','CHG0003','2024-05-20 08:10:00', NULL,'entrant'),
  ('COL0011','CHG0003','2024-05-20 08:15:00', NULL,'entrant'),
  ('COL0012','CHG0004','2024-05-28 08:30:00', NULL,'entrant'),
  ('COL0013','CHG0004','2024-05-28 08:35:00', NULL,'entrant'),
  ('COL0014','CHG0004','2024-05-28 08:40:00', NULL,'entrant'),
  ('COL0015','CHG0005','2024-06-03 07:30:00', NULL,'entrant'),
  ('COL0016','CHG0005','2024-06-03 07:35:00', NULL,'entrant'),
  ('COL0017','CHG0005','2024-06-03 07:40:00', NULL,'entrant'),
  ('COL0018','CHG0006','2024-06-10 09:00:00', NULL,'entrant'),
  ('COL0019','CHG0006','2024-06-10 09:05:00', NULL,'entrant'),
  ('COL0020','CHG0006','2024-06-10 09:10:00', NULL,'entrant'),
  ('COL0021','CHG0006','2024-06-10 09:15:00', NULL,'entrant'),
  ('COL0022','CHG0007','2024-06-17 07:45:00', NULL,'entrant'),
  ('COL0023','CHG0007','2024-06-17 07:50:00', NULL,'entrant'),
  ('COL0024','CHG0007','2024-06-17 07:55:00', NULL,'entrant'),
  ('COL0025','CHG0007','2024-06-17 08:00:00', NULL,'entrant'),
  ('COL0026','CHG0008','2024-06-22 09:30:00', NULL,'entrant'),
  ('COL0027','CHG0008','2024-06-22 09:35:00', NULL,'entrant'),
  ('COL0028','CHG0008','2024-06-22 09:40:00', NULL,'entrant'),
  ('COL0029','CHG0008','2024-06-22 09:45:00', NULL,'entrant'),
  ('COL0030','CHG0008','2024-06-22 09:50:00', NULL,'entrant'),
  ('COL0031','CHG0008','2024-06-22 09:55:00', NULL,'entrant'),
  ('COL0032','CHG0008','2024-06-22 10:00:00', NULL,'entrant'),
  ('COL0033','CHG0008','2024-06-22 10:05:00', NULL,'entrant'),
  ('COL0034','CHG0008','2024-06-22 10:10:00', NULL,'entrant'),
  ('COL0035','CHG0008','2024-06-22 10:15:00', NULL,'entrant'),
  /* ── Colis sortants (expédition) ── */
  ('COL0036','CHG0009', NULL,'2024-05-15 14:30:00','sortant'),
  ('COL0037','CHG0009', NULL,'2024-05-15 14:35:00','sortant'),
  ('COL0038','CHG0009', NULL,'2024-05-15 14:40:00','sortant'),
  ('COL0039','CHG0010', NULL,'2024-05-30 14:00:00','sortant'),
  ('COL0040','CHG0010', NULL,'2024-05-30 14:05:00','sortant'),
  ('COL0041','CHG0010', NULL,'2024-05-30 14:10:00','sortant'),
  ('COL0042','CHG0011', NULL,'2024-06-14 15:20:00','sortant'),
  ('COL0043','CHG0011', NULL,'2024-06-14 15:25:00','sortant'),
  ('COL0044','CHG0011', NULL,'2024-06-14 15:30:00','sortant'),
  ('COL0045','CHG0011', NULL,'2024-06-14 15:35:00','sortant'),
  ('COL0046','CHG0012', NULL,'2024-06-24 15:00:00','sortant'),
  ('COL0047','CHG0012', NULL,'2024-06-24 15:05:00','sortant'),
  ('COL0048','CHG0012', NULL,'2024-06-24 15:10:00','sortant'),
  ('COL0049','CHG0012', NULL,'2024-06-24 15:15:00','sortant'),
  ('COL0050','CHG0012', NULL,'2024-06-24 15:20:00','sortant');

SELECT setval('seq_col', 50);

/* =============================================================================
   12. CONTENU DES COLIS
       Chaque colis entrant contient 3-5 produits.
       On utilise des PRD sur une plage fixe pour rester prévisible.
   ============================================================================= */

DO $$
DECLARE
  colis_ids   varchar(7)[] := ARRAY[
    'COL0001','COL0002','COL0003','COL0004','COL0005',
    'COL0006','COL0007','COL0008','COL0009','COL0010',
    'COL0011','COL0012','COL0013','COL0014','COL0015',
    'COL0016','COL0017','COL0018','COL0019','COL0020',
    'COL0021','COL0022','COL0023','COL0024','COL0025',
    'COL0026','COL0027','COL0028','COL0029','COL0030',
    'COL0031','COL0032','COL0033','COL0034','COL0035',
    -- sortants
    'COL0036','COL0037','COL0038','COL0039','COL0040',
    'COL0041','COL0042','COL0043','COL0044','COL0045',
    'COL0046','COL0047','COL0048','COL0049','COL0050'
  ];
  c_idx  integer;
  p_base integer;   /* indice de départ produit pour ce colis */
  p_cnt  integer;   /* nb produits dans ce colis (3 à 5) */
  p_off  integer;
  v_col  varchar(7);
  v_prd  varchar(7);
  v_qte  integer;
BEGIN
  FOR c_idx IN 1..array_length(colis_ids, 1) LOOP
    v_col  := colis_ids[c_idx];
    p_cnt  := 3 + ((c_idx * 7) % 3);            /* 3, 4 ou 5 produits */
    p_base := ((c_idx - 1) * 3) % 145 + 1;      /* base tournante sur 145 produits */

    FOR p_off IN 0..(p_cnt - 1) LOOP
      v_prd := 'PRD' || LPAD(((p_base + p_off - 1) % 150 + 1)::text, 4, '0');
      v_qte := 2 + ((c_idx + p_off * 3) % 8);   /* 2 à 9 unités */

      /* Éviter les doublons (même produit dans même colis) */
      IF NOT EXISTS (
        SELECT 1 FROM contenu_colis
        WHERE no_colis = v_col AND id_produit = v_prd
      ) THEN
        INSERT INTO contenu_colis (no_colis, id_produit, qte_produit)
        VALUES (v_col, v_prd, v_qte);
      END IF;
    END LOOP;
  END LOOP;
END;
$$;

/* =============================================================================
   13. INVENTAIRE — EMPLACEMENT
       On stocke les lots des colis entrants dans les cellules.
       Les cellules CEL0001-CEL0012 reçoivent des stocks.
       Contrainte : quantite_stockee <= lot.quantite (toujours respectée ici).
   ============================================================================= */

DO $$
DECLARE
  v_lot_id   varchar(7);
  v_cell_id  varchar(7);
  v_lot_qte  integer;
  v_stock    integer;
  idx        integer := 0;

  -- Cellules recevant du stock
  cells varchar(7)[] := ARRAY[
    'CEL0001','CEL0002','CEL0006','CEL0007','CEL0008',
    'CEL0011','CEL0012'
  ];

  rec RECORD;
BEGIN
  /* Pour chaque lot (produit matériel ou emballage), on stocke une partie */
  FOR rec IN
    SELECT l.id_lot, l.quantite
    FROM lot l
    JOIN produit p ON p.id_produit = l.id_produit
    WHERE p.type IN ('materiel','emballage')
    ORDER BY l.id_lot
    LIMIT 80   /* on stocke 80 lots sur les 120 matériels+emballages */
  LOOP
    idx        := idx + 1;
    v_cell_id  := cells[((idx - 1) % array_length(cells, 1)) + 1];
    v_lot_id   := rec.id_lot;
    v_lot_qte  := rec.quantite;
    v_stock    := GREATEST(1, v_lot_qte / 2);   /* on stocke 50% du lot max */

    /* Éviter doublon (cell, lot) */
    IF NOT EXISTS (
      SELECT 1 FROM inventaire_emplacement
      WHERE no_cellule = v_cell_id AND id_lot = v_lot_id
    ) THEN
      INSERT INTO inventaire_emplacement (no_cellule, id_lot, quantite_stockee)
      VALUES (v_cell_id, v_lot_id, v_stock);
    END IF;
  END LOOP;

  /* Mettre à jour la disponibilité des cellules qui ont reçu du stock */
  UPDATE cellule SET disponibilite = 'occupee'
  WHERE no_cellule IN (
    SELECT DISTINCT no_cellule FROM inventaire_emplacement
  );
END;
$$;

/* =============================================================================
   14. BONS DE RÉCEPTION (un par colis entrant : COL0001 → COL0035)
   ============================================================================= */

DO $$
DECLARE
  i integer;
  v_col varchar(7);
  descriptions text[] := ARRAY[
    'Reception conforme — aucune anomalie.',
    'Reception conforme — emballage leger.',
    'Reception conforme — 1 unite verifiee.',
    'Reception avec ecart mineur — voir rapport.',
    'Reception conforme — etiquettes OK.'
  ];
BEGIN
  FOR i IN 1..35 LOOP
    v_col := 'COL' || LPAD(i::text, 4, '0');
    INSERT INTO bon_reception (id_bon_reception, no_colis, description_recep)
    VALUES (
      gen_id('BRC', 'seq_brc'),
      v_col,
      descriptions[((i-1) % 5) + 1]
    );
  END LOOP;
END;
$$;

/* =============================================================================
   15. BONS D'EXPÉDITION (un par colis sortant : COL0036 → COL0050)
   ============================================================================= */

DO $$
DECLARE
  i integer;
  v_col varchar(7);
  destinations text[] := ARRAY[
    'Livraison Akwa, Douala','Livraison Bonanjo, Douala',
    'Livraison Bassa, Douala','Livraison Makepe, Douala',
    'Livraison Yaounde Centre'
  ];
BEGIN
  FOR i IN 36..50 LOOP
    v_col := 'COL' || LPAD(i::text, 4, '0');
    INSERT INTO bon_expedition (id_bon_expedition, no_colis, description_exped)
    VALUES (
      gen_id('BEX', 'seq_bex'),
      v_col,
      destinations[((i - 36) % 5) + 1] || ' — bon n° ' || (i - 35)
    );
  END LOOP;
END;
$$;

/* =============================================================================
   16. RAPPORTS D'EXCEPTION (8 rapports réalistes)
   ============================================================================= */

INSERT INTO rapport_exception
  (id_rapport, no_chargement, no_colis, description_rapport, procede, date_rapport)
VALUES
  ('RAP0001','CHG0001','COL0001',
   'Ecart quantitatif : bon de reception prevoyait 10 unites, 8 reçues.',
   'reception','2024-05-05 09:00:00'),

  ('RAP0002','CHG0002','COL0006',
   'Emballage endommage a l arrivee — contenu verifie et conforme.',
   'reception','2024-05-12 09:15:00'),

  ('RAP0003','CHG0003',NULL,
   'Retard chargement CHG0003 : camion arrive 90 min apres le creneau prevu.',
   'reception','2024-05-20 10:00:00'),

  ('RAP0004',NULL,'COL0011',
   'Numero de serie absent sur 2 unites — etiquetage a completer.',
   'stockage','2024-05-20 11:30:00'),

  ('RAP0005','CHG0009','COL0036',
   'Adresse de livraison illisible sur le bon d expedition COL0036.',
   'expedition','2024-05-15 15:00:00'),

  ('RAP0006',NULL,'COL0018',
   'Cellule CEL0006 proche de sa capacite maximale en masse (92 pct).',
   'stockage','2024-06-10 10:00:00'),

  ('RAP0007','CHG0011','COL0042',
   'Colis COL0042 : film protecteur absent — re-emballage effectue avant depart.',
   'expedition','2024-06-14 16:00:00'),

  ('RAP0008','CHG0008','COL0030',
   'Produit PRD0045 absent du bon de reception — fournisseur contacte.',
   'reception','2024-06-22 11:00:00');

SELECT setval('seq_rap', 8);

/* Marquer quelques rapports comme résolus ou en cours */
UPDATE rapport_exception SET statut = 'resolu',
  date_resolution = '2024-05-05 16:00:00', resolu_par = 'PER0009'
WHERE id_rapport IN ('RAP0001','RAP0002');

UPDATE rapport_exception SET statut = 'en_cours', resolu_par = 'PER0010'
WHERE id_rapport IN ('RAP0003','RAP0005');

/* Note : statut et date_resolution n'existent que si SGE_ajout.sql a été exécuté.
   Si la colonne n'existe pas, l'UPDATE échouera silencieusement — pas de problème. */

/* =============================================================================
   17. VÉRIFICATIONS FINALES
   ============================================================================= */

DO $$
DECLARE
  nb_per  integer; nb_org  integer; nb_ext  integer;
  nb_prd  integer; nb_lot  integer; nb_col  integer;
  nb_cel  integer; nb_inv  integer; nb_brc  integer;
  nb_bex  integer; nb_rap  integer;
BEGIN
  SELECT COUNT(*) INTO nb_per FROM personnel;
  SELECT COUNT(*) INTO nb_org FROM organisation;
  SELECT COUNT(*) INTO nb_ext FROM externe;
  SELECT COUNT(*) INTO nb_prd FROM produit;
  SELECT COUNT(*) INTO nb_lot FROM lot;
  SELECT COUNT(*) INTO nb_col FROM colis;
  SELECT COUNT(*) INTO nb_cel FROM cellule;
  SELECT COUNT(*) INTO nb_inv FROM inventaire_emplacement;
  SELECT COUNT(*) INTO nb_brc FROM bon_reception;
  SELECT COUNT(*) INTO nb_bex FROM bon_expedition;
  SELECT COUNT(*) INTO nb_rap FROM rapport_exception;

  RAISE NOTICE '═══════════════════════════════════════════';
  RAISE NOTICE ' JDD_02 — Récapitulatif des insertions     ';
  RAISE NOTICE '═══════════════════════════════════════════';
  RAISE NOTICE ' Personnel         : %', nb_per;
  RAISE NOTICE ' Organisations     : %', nb_org;
  RAISE NOTICE ' Externes          : %', nb_ext;
  RAISE NOTICE ' Produits          : %', nb_prd;
  RAISE NOTICE ' Lots              : %', nb_lot;
  RAISE NOTICE ' Colis             : %', nb_col;
  RAISE NOTICE ' Cellules          : %', nb_cel;
  RAISE NOTICE ' Inventaire        : %', nb_inv;
  RAISE NOTICE ' Bons réception    : %', nb_brc;
  RAISE NOTICE ' Bons expédition   : %', nb_bex;
  RAISE NOTICE ' Rapports          : %', nb_rap;
  RAISE NOTICE '═══════════════════════════════════════════';

  ASSERT nb_per  =  20, 'Personnel : attendu 20';
  ASSERT nb_prd  = 150, 'Produits  : attendu 150';
  ASSERT nb_lot  = 150, 'Lots      : attendu 150';
  ASSERT nb_col  =  50, 'Colis     : attendu 50';
  ASSERT nb_cel  =  20, 'Cellules  : attendu 20';
  ASSERT nb_brc  =  35, 'Bons réc  : attendu 35';
  ASSERT nb_bex  =  15, 'Bons exp  : attendu 15';
  ASSERT nb_rap  =   8, 'Rapports  : attendu 8';

  RAISE NOTICE ' ✓ Toutes les assertions passent.';
END;
$$;

/* =============================================================================
   RÉCAPITULATIF DES COMPTES DE CONNEXION
   ─────────────────────────────────────────
   PER0001  Mbarga Jean        Magasinier           mdp: magasin123
   PER0002  Nkolo Marie        Magasinière          mdp: magasin123
   PER0003  Tchoua Paul        Agent logistique     mdp: agent123
   PER0004  Essomba Sophie     Agent logistique     mdp: agent123
   PER0005  Abanda Henri       Resp. informatique  mdp: respinfo123
   PER0006  Kamgang Alice      Emballeuse           mdp: embal123
   PER0007  Fotso Denis        Emballeur            mdp: embal123
   PER0008  Onana Grace        Emballeuse           mdp: embal123
   PER0009  Talla Robert       Resp. stocks         mdp: respstock123
   PER0010  Owona Francoise    Resp. logistique     mdp: resplog123
   PER0011  Dongo Alain        Administrateur       mdp: Admin@2024
   ============================================================================= */


