/* ==========================================================================
   SGE_test-neg.sql
   Tests unitaires NÉGATIFS du SGE.
   Chaque test vérifie qu'une opération illicite déclenche bien l'exception
   attendue. Le pattern utilisé :
       BEGIN ... EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'PASS ...'; END
   Si aucune exception n'est levée, RAISE EXCEPTION signale l'échec du test.
   Exécuter APRÈS SGE_jdd_01.sql.
   ========================================================================== */

SET search_path TO sge;

/* ═══════════════════════════════════════════════════════════════════════════
   GROUPE 1 — Violations de domaines et contraintes CHECK
   ═══════════════════════════════════════════════════════════════════════════ */

-- NEG-BD-01 : nom vide (dom_nom CHECK length > 0)
DO $$
BEGIN
  INSERT INTO personnel (id_personnel, nom, prenom, sexe)
  VALUES ('PER9901', '   ', 'Test', 'M');
  RAISE EXCEPTION 'NEG-BD-01 FAIL : nom vide aurait dû être rejeté';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-BD-01 PASS : nom vide rejeté — %', SQLERRM;
END;
$$;

-- NEG-BD-02 : téléphone invalide (dom_telephone CHECK regex)
DO $$
BEGIN
  INSERT INTO personnel (id_personnel, nom, prenom, sexe, telephone)
  VALUES ('PER9902', 'Test', 'Test', 'M', 'ABCDE');
  RAISE EXCEPTION 'NEG-BD-02 FAIL : téléphone invalide aurait dû être rejeté';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-BD-02 PASS : téléphone invalide rejeté — %', SQLERRM;
END;
$$;

-- NEG-BD-03 : quantité négative (dom_quantite CHECK >= 0)
DO $$
BEGIN
  INSERT INTO lot (id_produit, quantite) VALUES ('PRD0001', -5);
  RAISE EXCEPTION 'NEG-BD-03 FAIL : quantité négative aurait dû être rejetée';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-BD-03 PASS : quantité négative rejetée — %', SQLERRM;
END;
$$;

-- NEG-BD-04 : mesure négative (dom_mesure CHECK >= 0)
DO $$
BEGIN
  INSERT INTO cellule (no_zs, longueur, largeur, hauteur, masse_maximale)
  VALUES ('ZNS0001', -10.0, 80.0, 200.0, 500.0);
  RAISE EXCEPTION 'NEG-BD-04 FAIL : longueur négative aurait dû être rejetée';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-BD-04 PASS : longueur négative rejetée — %', SQLERRM;
END;
$$;

-- NEG-BD-05 : date_naissance dans le futur (CHECK <= CURRENT_DATE)
DO $$
BEGIN
  INSERT INTO personnel (id_personnel, nom, prenom, sexe, date_naissance)
  VALUES ('PER9903', 'Futur', 'Enfant', 'F', CURRENT_DATE + 1);
  RAISE EXCEPTION 'NEG-BD-05 FAIL : date_naissance future aurait dû être rejetée';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-BD-05 PASS : date_naissance future rejetée — %', SQLERRM;
END;
$$;

-- NEG-BD-06 : sexe hors enum
DO $$
BEGIN
  INSERT INTO personnel (id_personnel, nom, prenom, sexe)
  VALUES ('PER9904', 'Test', 'Test', 'Z');
  RAISE EXCEPTION 'NEG-BD-06 FAIL : valeur sexe invalide aurait dû être rejetée';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-BD-06 PASS : valeur sexe invalide rejetée — %', SQLERRM;
END;
$$;

-- NEG-BD-07 : rapport_exception sans chargement NI colis (CHECK NOT NULL OR)
DO $$
BEGIN
  INSERT INTO rapport_exception (description_rapport, procede)
  VALUES ('Sans référence', 'reception');
  RAISE EXCEPTION 'NEG-BD-07 FAIL : rapport sans ref aurait dû être rejeté';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-BD-07 PASS : rapport sans chargement ni colis rejeté — %', SQLERRM;
END;
$$;

/* ═══════════════════════════════════════════════════════════════════════════
   GROUPE 2 — Violations de clés étrangères
   ═══════════════════════════════════════════════════════════════════════════ */

-- NEG-FK-01 : colis référençant un chargement inexistant
DO $$
BEGIN
  INSERT INTO colis (no_colis, no_chargement, type)
  VALUES ('COL9901', 'CHG9999', 'entrant');
  RAISE EXCEPTION 'NEG-FK-01 FAIL : FK chargement inexistant aurait dû être rejetée';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-FK-01 PASS : FK chargement inexistant rejetée — %', SQLERRM;
END;
$$;

-- NEG-FK-02 : lot référençant un produit inexistant
DO $$
BEGIN
  INSERT INTO lot (id_produit, quantite) VALUES ('PRD9999', 10);
  RAISE EXCEPTION 'NEG-FK-02 FAIL : FK produit inexistant aurait dû être rejetée';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-FK-02 PASS : FK produit inexistant rejetée — %', SQLERRM;
END;
$$;

-- NEG-FK-03 : inventaire_emplacement référençant une cellule inexistante
DO $$
BEGIN
  INSERT INTO inventaire_emplacement (no_cellule, id_lot, quantite_stockee)
  VALUES ('CEL9999', 'LOT0001', 5);
  RAISE EXCEPTION 'NEG-FK-03 FAIL : FK cellule inexistante aurait dû être rejetée';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-FK-03 PASS : FK cellule inexistante rejetée — %', SQLERRM;
END;
$$;

-- NEG-FK-04 : organisation référençant un personnel inexistant
DO $$
BEGIN
  INSERT INTO organisation (id_personnel, type_org) VALUES ('PER9999', 'Fournisseur');
  RAISE EXCEPTION 'NEG-FK-04 FAIL : FK personnel inexistant aurait dû être rejetée';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-FK-04 PASS : FK personnel inexistant rejetée — %', SQLERRM;
END;
$$;

/* ═══════════════════════════════════════════════════════════════════════════
   GROUPE 3 — Violations de clés primaires / unicité
   ═══════════════════════════════════════════════════════════════════════════ */

-- NEG-PK-01 : doublon de clé primaire dans personnel
DO $$
BEGIN
  INSERT INTO personnel (id_personnel, nom, prenom, sexe)
  VALUES ('PER0001', 'Doublon', 'Test', 'M');
  RAISE EXCEPTION 'NEG-PK-01 FAIL : doublon PK personnel aurait dû être rejeté';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-PK-01 PASS : doublon PK personnel rejeté — %', SQLERRM;
END;
$$;

-- NEG-PK-02 : doublon de clé composite (no_colis, id_produit) dans contenu_colis
DO $$
BEGIN
  INSERT INTO contenu_colis (no_colis, id_produit, qte_produit)
  VALUES ('COL0001', 'PRD0001', 2);  -- existe déjà dans jdd_01
  RAISE EXCEPTION 'NEG-PK-02 FAIL : doublon PK contenu_colis aurait dû être rejeté';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-PK-02 PASS : doublon PK contenu_colis rejeté — %', SQLERRM;
END;
$$;

-- NEG-PK-03 : bon_reception.no_colis UNIQUE — deux bons pour le même colis
DO $$
BEGIN
  INSERT INTO bon_reception (no_colis, description_recep)
  VALUES ('COL0001', 'Second bon pour le même colis');
  RAISE EXCEPTION 'NEG-PK-03 FAIL : doublon UNIQUE no_colis dans bon_reception aurait dû être rejeté';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-PK-03 PASS : doublon no_colis dans bon_reception rejeté — %', SQLERRM;
END;
$$;

/* ═══════════════════════════════════════════════════════════════════════════
   GROUPE 4 — Déclencheurs (trg_verifier_*)
   ═══════════════════════════════════════════════════════════════════════════ */

-- NEG-TRG-01 : déclencheur type produit — insérer un produit_materiel pour un produit logiciel
DO $$
DECLARE v_id varchar(7);
BEGIN
  v_id := imm_ajouter_produit('WinTest', 'logiciel');
  INSERT INTO produit_materiel (id_produit, longueur, largeur, hauteur, masse)
  VALUES (v_id, 30.0, 20.0, 10.0, 0.5);
  DELETE FROM produit WHERE id_produit = v_id;
  RAISE EXCEPTION 'NEG-TRG-01 FAIL : type incompatible aurait dû être rejeté';
EXCEPTION WHEN OTHERS THEN
  BEGIN
    DELETE FROM produit WHERE id_produit = v_id;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  RAISE NOTICE 'NEG-TRG-01 PASS : produit_materiel sur produit logiciel rejeté — %', SQLERRM;
END;
$$;

-- NEG-TRG-02 : déclencheur dates — date_expedition < date_arrivee
DO $$
DECLARE v_col varchar(7);
BEGIN
  v_col := imm_ajouter_colis('entrant', 'CHG0001', '2024-06-10 10:00:00'::timestamp, NULL);
  UPDATE colis SET date_expedition = '2024-06-09 08:00:00' WHERE no_colis = v_col;
  PERFORM imm_supprimer_colis(v_col);
  RAISE EXCEPTION 'NEG-TRG-02 FAIL : date_expedition < date_arrivee aurait dû être rejetée';
EXCEPTION WHEN OTHERS THEN
  BEGIN
    PERFORM imm_supprimer_colis(v_col);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  RAISE NOTICE 'NEG-TRG-02 PASS : date_expedition antérieure rejetée — %', SQLERRM;
END;
$$;

-- NEG-TRG-03 : déclencheur quantité — stocker plus que la quantité du lot
DO $$
DECLARE v_lot varchar(7);
BEGIN
  v_lot := imm_ajouter_lot('PRD0003', 5);
  -- Tenter de stocker 10 alors que le lot n'en contient que 5
  INSERT INTO inventaire_emplacement (no_cellule, id_lot, quantite_stockee)
  VALUES ('CEL0006', v_lot, 10);
  DELETE FROM lot WHERE id_lot = v_lot;
  RAISE EXCEPTION 'NEG-TRG-03 FAIL : dépassement quantité lot aurait dû être rejeté';
EXCEPTION WHEN OTHERS THEN
  BEGIN
    DELETE FROM lot WHERE id_lot = v_lot;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  RAISE NOTICE 'NEG-TRG-03 PASS : dépassement quantité lot rejeté — %', SQLERRM;
END;
$$;

-- NEG-TRG-04 : déclencheur masse — dépasser la masse maximale d'une cellule
DO $$
DECLARE
  v_lot varchar(7);
  v_prd varchar(7);
BEGIN
  -- Créer un produit matériel très lourd (300 kg/unité)
  v_prd := imm_ajouter_produit('Bloc béton', 'materiel');
  INSERT INTO produit_materiel (id_produit, longueur, largeur, hauteur, masse)
  VALUES (v_prd, 60.0, 40.0, 20.0, 300.000);
  v_lot := imm_ajouter_lot(v_prd, 3);
  -- CEL0008 a masse_maximale = 200 kg, tenter d'y mettre 3 × 300 kg = 900 kg
  INSERT INTO inventaire_emplacement (no_cellule, id_lot, quantite_stockee)
  VALUES ('CEL0008', v_lot, 3);
  DELETE FROM lot    WHERE id_lot    = v_lot;
  DELETE FROM produit WHERE id_produit = v_prd;
  RAISE EXCEPTION 'NEG-TRG-04 FAIL : dépassement masse cellule aurait dû être rejeté';
EXCEPTION WHEN OTHERS THEN
  BEGIN
    DELETE FROM inventaire_emplacement WHERE id_lot = v_lot;
    DELETE FROM lot     WHERE id_lot     = v_lot;
    DELETE FROM produit WHERE id_produit = v_prd;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  RAISE NOTICE 'NEG-TRG-04 PASS : dépassement masse cellule rejeté — %', SQLERRM;
END;
$$;

/* ═══════════════════════════════════════════════════════════════════════════
   GROUPE 5 — Violations dans les routines de traitement (SGE_tra.sql)
   ═══════════════════════════════════════════════════════════════════════════ */

-- NEG-TRA-01 : tra_destocker_lot — colis inexistant dans la cellule
DO $$
BEGIN
  PERFORM tra_destocker_lot('CEL0006', 'LOT0001', 1);
  RAISE EXCEPTION 'NEG-TRA-01 FAIL : déstocker depuis cellule sans stock aurait dû échouer';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-TRA-01 PASS : déstocker lot absent rejeté — %', SQLERRM;
END;
$$;

-- NEG-TRA-02 : tra_destocker_lot — quantité demandée > quantité disponible
DO $$
BEGIN
  -- LOT0001 a 5 unités dans CEL0001
  PERFORM tra_destocker_lot('CEL0001', 'LOT0001', 999);
  RAISE EXCEPTION 'NEG-TRA-02 FAIL : déstockage excessif aurait dû être rejeté';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-TRA-02 PASS : déstockage excessif rejeté — %', SQLERRM;
END;
$$;

-- NEG-TRA-03 : tra_receptionner_colis — colis inexistant
DO $$
BEGIN
  PERFORM tra_receptionner_colis('COL9999', 'Bon pour colis inexistant');
  RAISE EXCEPTION 'NEG-TRA-03 FAIL : réceptionner un colis inexistant aurait dû échouer';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-TRA-03 PASS : réception colis inexistant rejetée — %', SQLERRM;
END;
$$;

-- NEG-TRA-04 : tra_signaler_exception — sans chargement ni colis
DO $$
BEGIN
  PERFORM tra_signaler_exception('stockage', 'Exception sans référence', NULL, NULL);
  RAISE EXCEPTION 'NEG-TRA-04 FAIL : rapport sans référence aurait dû être rejeté';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-TRA-04 PASS : rapport sans référence rejeté — %', SQLERRM;
END;
$$;

-- NEG-TRA-05 : imm_supprimer_personnel inexistant
DO $$
BEGIN
  PERFORM imm_supprimer_personnel('PER9999');
  RAISE EXCEPTION 'NEG-TRA-05 FAIL : supprimer personnel inexistant aurait dû échouer';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-TRA-05 PASS : suppression personnel inexistant rejetée — %', SQLERRM;
END;
$$;

-- NEG-TRA-06 : imm_supprimer_colis inexistant
DO $$
BEGIN
  PERFORM imm_supprimer_colis('COL9999');
  RAISE EXCEPTION 'NEG-TRA-06 FAIL : supprimer colis inexistant aurait dû échouer';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'NEG-TRA-06 PASS : suppression colis inexistant rejetée — %', SQLERRM;
END;
$$;

RAISE NOTICE '=== Tous les tests NÉGATIFS terminés ===';