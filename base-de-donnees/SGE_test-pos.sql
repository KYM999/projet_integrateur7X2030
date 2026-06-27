/* ==========================================================================
   SGE_test-pos.sql
   Tests unitaires POSITIFS du SGE.
   Chaque test vérifie qu'une opération légitime réussit et produit
   le résultat attendu. Exécuter APRÈS SGE_jdd_01.sql.
   Convention :
     - Chaque bloc DO $$ ... $$ est un test isolé.
     - En cas d'échec, RAISE EXCEPTION arrête le bloc et affiche le message.
     - RAISE NOTICE affiche le résultat en cas de succès.
   ========================================================================== */

SET search_path TO sge;

/* ═══════════════════════════════════════════════════════════════════════════
   GROUPE 1 — Base de données (structure et domaines)
   ═══════════════════════════════════════════════════════════════════════════ */

-- POS-BD-01 : insertion de personnel valide
DO $$
DECLARE v_id varchar(7);
BEGIN
  v_id := imm_ajouter_personnel('Dupont', 'Luc', 'M', 'Rue de la Paix', '+237 699 111 222', '1992-04-15');
  ASSERT v_id LIKE 'PER%', 'POS-BD-01 : identifiant attendu au format PERxxxx';
  RAISE NOTICE 'POS-BD-01 PASS : personnel ajouté avec id=%', v_id;
  DELETE FROM personnel WHERE id_personnel = v_id;
END;
$$;

-- POS-BD-02 : insertion d'un produit matériel valide
DO $$
DECLARE v_id varchar(7);
BEGIN
  v_id := imm_ajouter_produit('Souris USB', 'materiel', 'Souris optique filaire', 'Logitech', 'B100', 'PER0006');
  INSERT INTO produit_materiel (id_produit, longueur, largeur, hauteur, masse) VALUES (v_id, 11.0, 6.0, 3.5, 0.090);
  ASSERT v_id LIKE 'PRD%', 'POS-BD-02 : identifiant attendu au format PRDxxxx';
  RAISE NOTICE 'POS-BD-02 PASS : produit materiel ajouté avec id=%', v_id;
  DELETE FROM produit WHERE id_produit = v_id;
END;
$$;

-- POS-BD-03 : insertion d'un lot valide
DO $$
DECLARE v_id varchar(7);
BEGIN
  v_id := imm_ajouter_lot('PRD0003', 50);
  ASSERT v_id LIKE 'LOT%', 'POS-BD-03 : identifiant attendu au format LOTxxxx';
  RAISE NOTICE 'POS-BD-03 PASS : lot ajouté avec id=%', v_id;
  DELETE FROM lot WHERE id_lot = v_id;
END;
$$;

-- POS-BD-04 : domaine dom_telephone — numéro nul autorisé
DO $$
DECLARE v_id varchar(7);
BEGIN
  v_id := imm_ajouter_personnel('Martin', 'Julie', 'F', NULL, NULL, NULL);
  RAISE NOTICE 'POS-BD-04 PASS : telephone NULL autorisé, id=%', v_id;
  DELETE FROM personnel WHERE id_personnel = v_id;
END;
$$;

-- POS-BD-05 : gen_id produit le bon format
DO $$
DECLARE v varchar(7);
BEGIN
  v := gen_id('TST', 'seq_per');
  ASSERT length(v) = 7,         'POS-BD-05 : longueur doit être 7';
  ASSERT v LIKE 'TST%',         'POS-BD-05 : préfixe TST attendu';
  ASSERT v ~ '^TST[0-9]{4}$',  'POS-BD-05 : format TST0000 attendu';
  RAISE NOTICE 'POS-BD-05 PASS : gen_id produit "%"', v;
END;
$$;

/* ═══════════════════════════════════════════════════════════════════════════
   GROUPE 2 — IMM (interface machine-machine)
   ═══════════════════════════════════════════════════════════════════════════ */

-- POS-IMM-01 : ajout + modification + suppression d'un personnel
DO $$
DECLARE v_id varchar(7);
BEGIN
  v_id := imm_ajouter_personnel('Ngono', 'Eva', 'F', 'Yaounde', '+237 699 900 900', '1993-01-01');
  PERFORM imm_modifier_personnel(v_id, 'Ngono-bis', 'Eva', 'Douala', '+237 699 900 901');
  ASSERT (SELECT nom FROM personnel WHERE id_personnel = v_id) = 'Ngono-bis', 'POS-IMM-01 : nom non modifié';
  PERFORM imm_supprimer_personnel(v_id);
  ASSERT NOT EXISTS (SELECT 1 FROM personnel WHERE id_personnel = v_id), 'POS-IMM-01 : suppression non effective';
  RAISE NOTICE 'POS-IMM-01 PASS : cycle CRUD personnel complet';
END;
$$;

-- POS-IMM-02 : ajout colis + contenu
DO $$
DECLARE v_col varchar(7);
BEGIN
  v_col := imm_ajouter_colis('entrant', 'CHG0001', CURRENT_TIMESTAMP::timestamp, NULL);
  PERFORM imm_ajouter_contenu_colis(v_col, 'PRD0003', 5);
  ASSERT (SELECT qte_produit FROM contenu_colis WHERE no_colis = v_col AND id_produit = 'PRD0003') = 5,
    'POS-IMM-02 : contenu colis incorrect';
  PERFORM imm_supprimer_colis(v_col);
  RAISE NOTICE 'POS-IMM-02 PASS : colis + contenu créés et supprimés';
END;
$$;

/* ═══════════════════════════════════════════════════════════════════════════
   GROUPE 3 — REQUÊTES (SGE_req.sql)
   ═══════════════════════════════════════════════════════════════════════════ */

-- POS-REQ-01 : req_stock_par_produit retourne des lignes
DO $$
DECLARE nb integer;
BEGIN
  SELECT COUNT(*) INTO nb FROM req_stock_par_produit();
  ASSERT nb >= 3, 'POS-REQ-01 : au moins 3 produits attendus dans le stock';
  RAISE NOTICE 'POS-REQ-01 PASS : % ligne(s) retournées par req_stock_par_produit', nb;
END;
$$;

-- POS-REQ-02 : req_emplacements_produit pour PRD0001 retourne CEL0001
DO $$
DECLARE nb integer;
BEGIN
  SELECT COUNT(*) INTO nb FROM req_emplacements_produit('PRD0001');
  ASSERT nb >= 1, 'POS-REQ-02 : PRD0001 doit avoir au moins 1 emplacement';
  RAISE NOTICE 'POS-REQ-02 PASS : % emplacement(s) pour PRD0001', nb;
END;
$$;

-- POS-REQ-03 : req_cellules_disponibles retourne uniquement des cellules libres
DO $$
DECLARE nb_occupees integer;
BEGIN
  SELECT COUNT(*) INTO nb_occupees
  FROM req_cellules_disponibles()
  WHERE disponibilite <> 'libre';
  ASSERT nb_occupees = 0, 'POS-REQ-03 : seules les cellules libres doivent être retournées';
  RAISE NOTICE 'POS-REQ-03 PASS : aucune cellule non-libre dans le résultat';
END;
$$;

-- POS-REQ-04 : req_colis_en_reception retourne les colis entrants
DO $$
DECLARE nb integer;
BEGIN
  SELECT COUNT(*) INTO nb FROM req_colis_en_reception();
  ASSERT nb >= 2, 'POS-REQ-04 : au moins 2 colis entrants attendus';
  RAISE NOTICE 'POS-REQ-04 PASS : % colis en réception', nb;
END;
$$;

-- POS-REQ-05 : req_rapports_exception retourne au moins un rapport
DO $$
DECLARE nb integer;
BEGIN
  SELECT COUNT(*) INTO nb FROM req_rapports_exception();
  ASSERT nb >= 1, 'POS-REQ-05 : au moins 1 rapport d''exception attendu';
  RAISE NOTICE 'POS-REQ-05 PASS : % rapport(s) d''exception', nb;
END;
$$;

/* ═══════════════════════════════════════════════════════════════════════════
   GROUPE 4 — TRAITEMENTS (SGE_tra.sql)
   ═══════════════════════════════════════════════════════════════════════════ */

-- POS-TRA-01 : stocker un lot → cellule passe à 'occupee'
DO $$
DECLARE
  v_lot varchar(7);
  v_dispo type_disponibilite;
BEGIN
  v_lot := imm_ajouter_lot('PRD0003', 10);
  PERFORM tra_stocker_lot('CEL0009', v_lot, 10);
  SELECT disponibilite INTO v_dispo FROM cellule WHERE no_cellule = 'CEL0009';
  ASSERT v_dispo = 'occupee', 'POS-TRA-01 : cellule doit être occupee après stockage';
  -- Nettoyage
  PERFORM tra_destocker_lot('CEL0009', v_lot, 10);
  DELETE FROM lot WHERE id_lot = v_lot;
  RAISE NOTICE 'POS-TRA-01 PASS : stockage → cellule occupee, puis nettoyage → libre';
END;
$$;

-- POS-TRA-02 : déstocker un lot → cellule repasse à 'libre'
DO $$
DECLARE
  v_lot varchar(7);
  v_dispo type_disponibilite;
BEGIN
  v_lot := imm_ajouter_lot('PRD0002', 5);
  PERFORM tra_stocker_lot('CEL0010', v_lot, 5);
  PERFORM tra_destocker_lot('CEL0010', v_lot, 5);
  SELECT disponibilite INTO v_dispo FROM cellule WHERE no_cellule = 'CEL0010';
  ASSERT v_dispo = 'libre', 'POS-TRA-02 : cellule doit être libre après déstockage complet';
  DELETE FROM lot WHERE id_lot = v_lot;
  RAISE NOTICE 'POS-TRA-02 PASS : déstockage complet → cellule libre';
END;
$$;

-- POS-TRA-03 : déstockage partiel ne libère pas la cellule
DO $$
DECLARE
  v_lot varchar(7);
  v_dispo type_disponibilite;
BEGIN
  v_lot := imm_ajouter_lot('PRD0001', 10);
  PERFORM tra_stocker_lot('CEL0007', v_lot, 10);
  PERFORM tra_destocker_lot('CEL0007', v_lot, 4);
  SELECT disponibilite INTO v_dispo FROM cellule WHERE no_cellule = 'CEL0007';
  ASSERT v_dispo = 'occupee', 'POS-TRA-03 : cellule doit rester occupee après déstockage partiel';
  -- Nettoyage
  PERFORM tra_destocker_lot('CEL0007', v_lot, 6);
  DELETE FROM lot WHERE id_lot = v_lot;
  RAISE NOTICE 'POS-TRA-03 PASS : déstockage partiel → cellule toujours occupee';
END;
$$;

-- POS-TRA-04 : transfert de stock entre deux cellules
DO $$
DECLARE
  v_lot varchar(7);
  qte_src integer; qte_dst integer;
BEGIN
  v_lot := imm_ajouter_lot('PRD0003', 15);
  PERFORM tra_stocker_lot('CEL0008', v_lot, 15);
  PERFORM tra_transferer_stock('CEL0008', 'CEL0009', v_lot, 15);
  SELECT quantite_stockee INTO qte_dst FROM inventaire_emplacement
  WHERE no_cellule = 'CEL0009' AND id_lot = v_lot;
  ASSERT qte_dst = 15, 'POS-TRA-04 : 15 unités attendues dans la cellule destination';
  ASSERT NOT EXISTS (SELECT 1 FROM inventaire_emplacement WHERE no_cellule = 'CEL0008' AND id_lot = v_lot),
    'POS-TRA-04 : cellule source doit être vide après transfert';
  -- Nettoyage
  PERFORM tra_destocker_lot('CEL0009', v_lot, 15);
  DELETE FROM lot WHERE id_lot = v_lot;
  RAISE NOTICE 'POS-TRA-04 PASS : transfert de stock réussi';
END;
$$;

-- POS-TRA-05 : réceptionner un colis crée un bon de réception
DO $$
DECLARE
  v_col varchar(7); v_bon varchar(7);
BEGIN
  v_col := imm_ajouter_colis('entrant', 'CHG0001', CURRENT_TIMESTAMP::timestamp, NULL);
  v_bon := tra_receptionner_colis(v_col, 'Test bon réception positif');
  ASSERT v_bon LIKE 'BRC%', 'POS-TRA-05 : id bon réception au format BRCxxxx attendu';
  ASSERT EXISTS (SELECT 1 FROM bon_reception WHERE no_colis = v_col), 'POS-TRA-05 : bon non créé';
  PERFORM imm_supprimer_colis(v_col);
  RAISE NOTICE 'POS-TRA-05 PASS : bon de réception créé avec id=%', v_bon;
END;
$$;

-- POS-TRA-06 : expédier un colis crée un bon d'expédition
DO $$
DECLARE
  v_col varchar(7); v_bon varchar(7);
BEGIN
  v_col := imm_ajouter_colis('sortant', 'CHG0002', NULL, NULL);
  v_bon := tra_expedier_colis(v_col, 'Test bon expédition positif');
  ASSERT v_bon LIKE 'BEX%', 'POS-TRA-06 : id bon expédition au format BEXxxxx attendu';
  ASSERT EXISTS (SELECT 1 FROM bon_expedition WHERE no_colis = v_col), 'POS-TRA-06 : bon non créé';
  PERFORM imm_supprimer_colis(v_col);
  RAISE NOTICE 'POS-TRA-06 PASS : bon d''expédition créé avec id=%', v_bon;
END;
$$;

-- POS-TRA-07 : signaler une exception est bien enregistré
DO $$
DECLARE v_rap varchar(7);
BEGIN
  v_rap := tra_signaler_exception('reception', 'Test exception positive', 'CHG0001', NULL);
  ASSERT v_rap LIKE 'RAP%', 'POS-TRA-07 : id rapport au format RAPxxxx attendu';
  ASSERT EXISTS (SELECT 1 FROM rapport_exception WHERE id_rapport = v_rap), 'POS-TRA-07 : rapport non créé';
  DELETE FROM rapport_exception WHERE id_rapport = v_rap;
  RAISE NOTICE 'POS-TRA-07 PASS : rapport d''exception créé avec id=%', v_rap;
END;
$$;

/* ═══════════════════════════════════════════════════════════════════════════
   GROUPE 5 — Déclencheurs (comportement attendu en cas normal)
   ═══════════════════════════════════════════════════════════════════════════ */

-- POS-TRG-01 : déclencheur type produit — produit_materiel sur produit 'materiel' passe
DO $$
DECLARE v_id varchar(7);
BEGIN
  v_id := imm_ajouter_produit('Imprimante', 'materiel');
  INSERT INTO produit_materiel (id_produit, longueur, largeur, hauteur, masse)
  VALUES (v_id, 40.0, 35.0, 25.0, 6.5);
  RAISE NOTICE 'POS-TRG-01 PASS : spécialisation materiel acceptée pour produit materiel';
  DELETE FROM produit WHERE id_produit = v_id;
END;
$$;

-- POS-TRG-02 : dates colis — date_expedition > date_arrivee est valide
DO $$
DECLARE v_col varchar(7);
BEGIN
  v_col := imm_ajouter_colis('entrant', 'CHG0001', '2024-06-15 08:00:00'::timestamp, NULL);
  UPDATE colis SET date_expedition = '2024-06-20 10:00:00' WHERE no_colis = v_col;
  RAISE NOTICE 'POS-TRG-02 PASS : date_expedition > date_arrivee acceptée';
  PERFORM imm_supprimer_colis(v_col);
END;
$$;

RAISE NOTICE '=== Tous les tests POSITIFS terminés ===';