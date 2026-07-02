# =============================================================================
# tbi.py — Interface Dialoguée (TBI) de l'Application d'Automatisation
# Système de Gestion d'Entrepôts — SAC (Amazones et Centaures)
# =============================================================================
# Ce fichier implémente l'interface textuelle interactive (TBI) de l'AA.
# Il réutilise le module dao.py de l'AE comme couche d'accès aux données,
# garantissant que les deux applications (AA et AE) partagent les mêmes données.
#
# Structure des menus :
#   Menu principal
#   ├── 1. Réception
#   │   ├── 1. Lister les bons en attente
#   │   ├── 2. Prendre en charge un bon
#   │   ├── 3. Traiter un bon (marquer traité)
#   │   └── 4. Signaler une exception
#   ├── 2. Expédition
#   │   ├── 1. Lister les bons en attente
#   │   ├── 2. Préparer un bon
#   │   ├── 3. Confirmer une expédition
#   │   └── 4. Signaler une exception
#   ├── 3. Inventaire
#   │   ├── 1. Voir tous les produits
#   │   ├── 2. Rechercher un produit
#   │   ├── 3. Voir les cellules de stockage
#   │   └── 4. Proposer un emplacement
#   ├── 4. Rapports
#   │   ├── 1. Voir les rapports d'exception
#   │   ├── 2. Prendre en charge un rapport
#   │   └── 3. Résoudre un rapport
#   └── 0. Quitter
#
# Codes d'erreur :
#   E-TBI-01 : option de menu invalide
#   E-TBI-02 : saisie vide sur un champ obligatoire
#   E-TBI-03 : format de valeur incorrect
#   E-TBI-04 : identifiant introuvable dans les données
#   E-TBI-05 : opération impossible (règle métier violée)
#   E-TBI-06 : erreur système (journalisée dans journal_erreurs.log)
#   E-TBI-08 : trop d'erreurs consécutives, opération abandonnée
# =============================================================================

import sys
import os
import time
from datetime import datetime

# ── Chemin vers dao.py et mock_data.py de l'AE ───────────────────────────────
AE_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "C:\\Users\\GN237\\Desktop\\projet_integrateur7X2030\\application-exploitation")
)
if AE_PATH not in sys.path:
    sys.path.insert(0, AE_PATH)

# Import du module DAO de l'AE (couche d'accès aux données partagée)
try:
    import dao
except ImportError:
    print("ERREUR [E-TBI-06] Impossible d'importer dao.py.")
    print(f"Vérifiez que le chemin est correct : {AE_PATH}")
    sys.exit(1)

# ── Constantes ────────────────────────────────────────────────────────────────
MAX_TENTATIVES   = 3          # Nombre de tentatives avant abandon (E-TBI-08)
TIMEOUT_SECONDES = 300        # 5 minutes d'inactivité → retour menu principal (E-TBI-07)
LOG_FICHIER      = os.path.join(os.path.dirname(__file__), "journal_erreurs.log")

# Correspondance statut → libellé lisible
STATUTS = {
    "en_attente": "En attente",
    "en_cours":   "En cours",
    "traite":     "Traité",
    "conforme":   "Conforme",
    "non_conforme": "Non conforme",
    "expedie":    "Expédié",
    "resolu":     "Résolu",
    "occupee":    "Occupée",
    "libre":      "Libre",
    "indisponible": "Indisponible",
}


# =============================================================================
# UTILITAIRES D'AFFICHAGE
# =============================================================================

def ligne(car="─", longueur=56):
    """Affiche une ligne de séparation."""
    print(car * longueur)


def titre(texte):
    """Affiche un titre encadré."""
    print()
    ligne("═")
    print(f"  {texte}")
    ligne("═")


def sous_titre(texte):
    """Affiche un sous-titre avec séparateur."""
    print()
    print(f"  ── {texte}")
    ligne()


def statut_label(statut):
    """Retourne le libellé lisible d'un statut."""
    return STATUTS.get(statut, statut)


def afficher_tableau(colonnes, lignes):
    """
    Affiche un tableau formaté dans le terminal.
    colonnes : liste de tuples (clé, libellé, largeur)
    lignes   : liste de dictionnaires
    """
    if not lignes:
        print("  (aucun résultat)")
        return

    # En-tête
    entete = "  ".join(f"{lib:<{larg}}" for _, lib, larg in colonnes)
    print(f"\n  {entete}")
    ligne()

    # Lignes de données
    for row in lignes:
        valeurs = []
        for cle, _, larg in colonnes:
            val = str(row.get(cle, "—"))
            val = statut_label(val) if cle == "statut" else val
            # Tronquer si trop long
            val = val[:larg-1] + "…" if len(val) > larg else val
            valeurs.append(f"{val:<{larg}}")
        print("  " + "  ".join(valeurs))


def journaliser(code, detail):
    """Enregistre une erreur système dans le fichier journal (E-TBI-06)."""
    horodatage = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(LOG_FICHIER, "a", encoding="utf-8") as f:
            f.write(f"[{horodatage}] {code} : {detail}\n")
    except Exception:
        pass  # Ne pas planter si le journal n'est pas accessible


def pause():
    """Attend que l'utilisateur appuie sur Entrée avant de continuer."""
    input("\n  >>> Appuyez sur Entrée pour continuer...")


# =============================================================================
# UTILITAIRES DE SAISIE AVEC VALIDATION
# =============================================================================

def saisir(invite, validateur=None, msg_erreur=None, exemple=None):
    """
    Demande une saisie à l'utilisateur avec validation et gestion des erreurs.

    Paramètres :
      invite      : texte affiché avant la saisie
      validateur  : fonction(valeur) → True si valide
      msg_erreur  : message affiché si la validation échoue (E-TBI-03)
      exemple     : exemple de valeur valide affiché dans le message d'erreur

    Retourne la valeur saisie, ou None si MAX_TENTATIVES échecs (E-TBI-08).
    """
    tentatives = 0
    while tentatives < MAX_TENTATIVES:
        valeur = input(f"  >>> {invite} : ").strip()

        # Champ vide (E-TBI-02)
        if not valeur:
            print(f"  ERREUR [E-TBI-02] Ce champ est obligatoire.")
            tentatives += 1
            continue

        # Validation du format (E-TBI-03)
        if validateur and not validateur(valeur):
            msg = msg_erreur or "Format incorrect."
            ex  = f" Exemple : {exemple}" if exemple else ""
            print(f"  ERREUR [E-TBI-03] {msg}{ex}")
            tentatives += 1
            continue

        return valeur

    # Trop d'erreurs (E-TBI-08)
    print(f"  ERREUR [E-TBI-08] Trop d'erreurs consécutives. Opération annulée.")
    return None


def saisir_choix(invite, valeurs_valides):
    """
    Demande un choix parmi une liste de valeurs valides.
    Retourne le choix ou None après MAX_TENTATIVES échecs.
    """
    return saisir(
        invite,
        validateur=lambda v: v in valeurs_valides,
        msg_erreur=f"Choisissez parmi : {', '.join(valeurs_valides)}.",
        exemple=valeurs_valides[0] if valeurs_valides else None
    )


def confirmer(invite):
    """
    Demande une confirmation o/n.
    Retourne True si oui, False si non ou saisie invalide.
    """
    rep = saisir(
        invite + " (o/n)",
        validateur=lambda v: v.lower() in ("o", "n"),
        msg_erreur="Répondez par 'o' (oui) ou 'n' (non).",
        exemple="o"
    )
    return rep is not None and rep.lower() == "o"


def chercher_bon(liste, id_bon):
    """
    Recherche un bon (réception ou expédition) par son identifiant.
    Retourne le bon trouvé, ou None avec message d'erreur (E-TBI-04).
    """
    bon = next((b for b in liste if b.get("id") == id_bon), None)
    if not bon:
        print(f"  ERREUR [E-TBI-04] Identifiant '{id_bon}' introuvable. Vérifiez et réessayez.")
    return bon


# =============================================================================
# MENU PRINCIPAL
# =============================================================================

def afficher_menu_principal():
    """Affiche le menu principal de navigation."""
    titre("SGE — Application d'Automatisation  |  Mode dialogue (TBI)")
    print("  Amazones et Centaures (SAC)\n")
    print("   1. Réception")
    print("   2. Expédition")
    print("   3. Inventaire")
    print("   4. Rapports d'exception")
    print("   0. Quitter")
    ligne()


def afficher_aide():
    """Affiche le message d'aide général."""
    sous_titre("AIDE")
    print("  Tapez le numéro de l'option souhaitée, puis appuyez sur Entrée.")
    print("  Tapez  0  à tout moment pour revenir au menu précédent.")
    print("  Tapez  aide  pour revoir ce message.")
    print("  Après 5 minutes d'inactivité, vous revenez au menu principal.")
    pause()


# =============================================================================
# MODULE 1 — RÉCEPTION
# =============================================================================

def menu_reception():
    """Sous-menu de gestion des réceptions."""
    while True:
        sous_titre("RÉCEPTION")
        print("   1. Lister les bons en attente")
        print("   2. Prendre en charge un bon")
        print("   3. Marquer un bon comme traité")
        print("   4. Signaler une exception")
        print("   0. Retour au menu principal")
        ligne()

        choix = input("  >>> Votre choix : ").strip().lower()

        if choix == "aide":
            afficher_aide()
        elif choix == "1":
            lister_bons_reception()
        elif choix == "2":
            prendre_en_charge_reception()
        elif choix == "3":
            traiter_bon_reception()
        elif choix == "4":
            signaler_exception_reception()
        elif choix == "0":
            return
        else:
            # Option invalide (E-TBI-01)
            print("  ERREUR [E-TBI-01] Option invalide. Choisissez un numéro parmi les options affichées.")


def lister_bons_reception():
    """
    Affiche tous les bons de réception avec leur statut.
    Données source : dao.get_bons_reception()
    Colonnes : id, désignation, date, n° colis, statut
    """
    sous_titre("BONS DE RÉCEPTION")
    try:
        bons = dao.get_bons_reception()
        if not bons:
            print("  Aucun bon de réception enregistré.")
        else:
            afficher_tableau(
                colonnes=[
                    ("id",          "N° Bon",      10),
                    ("designation", "Désignation", 28),
                    ("date",        "Date",        12),
                    ("no_colis",    "N° Colis",    10),
                    ("statut",      "Statut",      14),
                ],
                lignes=bons
            )
            print(f"\n  Total : {len(bons)} bon(s)")
    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


def prendre_en_charge_reception():
    """
    Passe un bon de réception au statut 'en_cours'.
    Appelle : dao.prendre_en_charge_reception(id_bon)
    """
    sous_titre("PRISE EN CHARGE D'UN BON DE RÉCEPTION")

    # Afficher d'abord les bons disponibles pour aider l'utilisateur
    try:
        bons = dao.get_bons_reception()
        en_attente = [b for b in bons if b.get("statut") == "en_attente"]
        if not en_attente:
            print("  Aucun bon en attente de prise en charge.")
            pause()
            return

        print("  Bons en attente :")
        afficher_tableau(
            colonnes=[
                ("id",          "N° Bon",      10),
                ("designation", "Désignation", 30),
                ("date",        "Date",        12),
            ],
            lignes=en_attente
        )

        # Saisie du numéro de bon
        id_bon = saisir("\nNuméro du bon à prendre en charge")
        if id_bon is None:
            return

        # Vérification de l'existence du bon (E-TBI-04)
        bon = chercher_bon(bons, id_bon)
        if not bon:
            pause()
            return

        # Vérification que le bon est bien en attente (E-TBI-05)
        if bon.get("statut") != "en_attente":
            print(f"  ERREUR [E-TBI-05] Ce bon est déjà au statut '{statut_label(bon.get('statut'))}'.")
            print("  Seuls les bons 'En attente' peuvent être pris en charge.")
            pause()
            return

        # Confirmation avant action
        print(f"\n  Bon : {bon.get('id')} — {bon.get('designation')}")
        if not confirmer("Confirmer la prise en charge"):
            print("  Opération annulée.")
            pause()
            return

        # Appel DAO
        dao.prendre_en_charge_reception(id_bon)
        print(f"\n  [OK] Bon '{id_bon}' pris en charge. Statut → En cours.")

    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


def traiter_bon_reception():
    """
    Marque un bon de réception comme 'traité'.
    Appelle : dao.traiter_reception(id_bon)
    """
    sous_titre("TRAITEMENT D'UN BON DE RÉCEPTION")
    try:
        bons = dao.get_bons_reception()
        en_cours = [b for b in bons if b.get("statut") == "en_cours"]

        if not en_cours:
            print("  Aucun bon en cours. Prenez d'abord un bon en charge.")
            pause()
            return

        print("  Bons en cours :")
        afficher_tableau(
            colonnes=[
                ("id",          "N° Bon",      10),
                ("designation", "Désignation", 30),
                ("qte",         "Qté attendue", 14),
            ],
            lignes=en_cours
        )

        id_bon = saisir("\nNuméro du bon à traiter")
        if id_bon is None:
            return

        bon = chercher_bon(bons, id_bon)
        if not bon:
            pause()
            return

        # Vérification du statut (E-TBI-05)
        if bon.get("statut") != "en_cours":
            print(f"  ERREUR [E-TBI-05] Ce bon est au statut '{statut_label(bon.get('statut'))}'.")
            print("  Seuls les bons 'En cours' peuvent être marqués comme traités.")
            pause()
            return

        # Vérification de la description du colis
        print(f"\n  Bon       : {bon.get('id')}")
        print(f"  Désignation : {bon.get('designation')}")
        print(f"  Qté attendue : {bon.get('qte')}")
        print(f"  Description : {bon.get('description', '—')}")

        # Saisie de la quantité reçue
        qte_recue_str = saisir(
            "Quantité effectivement reçue",
            validateur=lambda v: v.isdigit() and int(v) >= 0,
            msg_erreur="Saisissez un nombre entier positif ou nul.",
            exemple="5"
        )
        if qte_recue_str is None:
            return

        qte_recue = int(qte_recue_str)
        qte_attendue = bon.get("qte", 0)

        # Détection d'écart — propose un rapport d'exception
        if qte_recue != qte_attendue:
            print(f"\n  ⚠ Écart détecté : attendu {qte_attendue}, reçu {qte_recue}.")
            if confirmer("Générer un rapport d'exception pour cet écart"):
                description = saisir("Décrivez l'écart constaté")
                if description:
                    dao.signaler_exception(
                        procede="reception",
                        description=description,
                        no_colis=bon.get("no_colis", "—"),
                        id_personnel=""
                    )
                    print("  [OK] Rapport d'exception enregistré.")

        if not confirmer("Confirmer le traitement de ce bon"):
            print("  Opération annulée.")
            pause()
            return

        dao.traiter_reception(id_bon)
        print(f"\n  [OK] Bon '{id_bon}' marqué comme traité.")

    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


def signaler_exception_reception():
    """
    Crée un rapport d'exception lié à une réception.
    Appelle : dao.signaler_exception(procede, description, no_colis)
    """
    sous_titre("RAPPORT D'EXCEPTION — RÉCEPTION")
    try:
        # Affichage des bons disponibles pour choisir le colis concerné
        bons = dao.get_bons_reception()
        afficher_tableau(
            colonnes=[
                ("id",       "N° Bon",    10),
                ("no_colis", "N° Colis",  10),
                ("statut",   "Statut",    14),
            ],
            lignes=bons
        )

        no_colis = saisir("\nN° du colis concerné (ex: COL0001)")
        if no_colis is None:
            return

        description = saisir("Décrivez l'anomalie constatée")
        if description is None:
            return

        if not confirmer("Enregistrer ce rapport d'exception"):
            print("  Opération annulée.")
            pause()
            return

        dao.signaler_exception(
            procede="reception",
            description=description,
            no_colis=no_colis,
            id_personnel=""
        )
        print(f"\n  [OK] Rapport d'exception enregistré pour le colis '{no_colis}'.")

    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


# =============================================================================
# MODULE 2 — EXPÉDITION
# =============================================================================

def menu_expedition():
    """Sous-menu de gestion des expéditions."""
    while True:
        sous_titre("EXPÉDITION")
        print("   1. Lister les bons en attente")
        print("   2. Préparer un bon")
        print("   3. Confirmer une expédition")
        print("   4. Signaler une exception")
        print("   0. Retour au menu principal")
        ligne()

        choix = input("  >>> Votre choix : ").strip().lower()

        if choix == "aide":
            afficher_aide()
        elif choix == "1":
            lister_bons_expedition()
        elif choix == "2":
            preparer_bon_expedition()
        elif choix == "3":
            confirmer_expedition()
        elif choix == "4":
            signaler_exception_expedition()
        elif choix == "0":
            return
        else:
            print("  ERREUR [E-TBI-01] Option invalide. Choisissez un numéro parmi les options affichées.")


def lister_bons_expedition():
    """
    Affiche tous les bons d'expédition avec transporteur et priorité.
    Données source : dao.get_bons_expedition()
    """
    sous_titre("BONS D'EXPÉDITION")
    try:
        bons = dao.get_bons_expedition()
        if not bons:
            print("  Aucun bon d'expédition enregistré.")
        else:
            afficher_tableau(
                colonnes=[
                    ("id",           "N° Bon",        10),
                    ("designation",  "Désignation",   26),
                    ("transporteur", "Transporteur",  16),
                    ("date",         "Date",          12),
                    ("statut",       "Statut",        12),
                    ("priorite",     "Priorité",       9),
                ],
                lignes=bons
            )
            print(f"\n  Total : {len(bons)} bon(s)")
    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


def preparer_bon_expedition():
    """
    Passe un bon d'expédition au statut 'en_cours'.
    Appelle : dao.preparer_expedition(id_bon)
    """
    sous_titre("PRÉPARATION D'UN BON D'EXPÉDITION")
    try:
        bons = dao.get_bons_expedition()
        en_attente = [b for b in bons if b.get("statut") == "en_attente"]

        if not en_attente:
            print("  Aucun bon d'expédition en attente.")
            pause()
            return

        print("  Bons en attente (triés par priorité) :")
        # Tri par priorité croissante (1 = plus urgent)
        tries = sorted(en_attente, key=lambda b: b.get("priorite", 9))
        afficher_tableau(
            colonnes=[
                ("id",           "N° Bon",       10),
                ("designation",  "Désignation",  28),
                ("transporteur", "Transporteur", 16),
                ("priorite",     "Priorité",      9),
            ],
            lignes=tries
        )

        id_bon = saisir("\nNuméro du bon à préparer")
        if id_bon is None:
            return

        bon = chercher_bon(bons, id_bon)
        if not bon:
            pause()
            return

        # Vérification du statut (E-TBI-05)
        if bon.get("statut") != "en_attente":
            print(f"  ERREUR [E-TBI-05] Ce bon est au statut '{statut_label(bon.get('statut'))}'.")
            pause()
            return

        print(f"\n  Bon         : {bon.get('id')}")
        print(f"  Désignation : {bon.get('designation')}")
        print(f"  Transporteur : {bon.get('transporteur', '—')}")
        print(f"  Commande    : {bon.get('commande', '—')}")
        print(f"  Description : {bon.get('description', '—')}")

        if not confirmer("Confirmer la préparation de ce bon"):
            print("  Opération annulée.")
            pause()
            return

        dao.preparer_expedition(id_bon)
        print(f"\n  [OK] Bon '{id_bon}' en cours de préparation.")

    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


def confirmer_expedition():
    """
    Marque un bon d'expédition comme 'expédié'.
    Appelle : dao.confirmer_expedition(id_bon)
    """
    sous_titre("CONFIRMATION D'EXPÉDITION")
    try:
        bons = dao.get_bons_expedition()
        en_cours = [b for b in bons if b.get("statut") == "en_cours"]

        if not en_cours:
            print("  Aucun bon en cours de préparation.")
            pause()
            return

        print("  Bons en cours :")
        afficher_tableau(
            colonnes=[
                ("id",           "N° Bon",       10),
                ("designation",  "Désignation",  28),
                ("transporteur", "Transporteur", 16),
            ],
            lignes=en_cours
        )

        id_bon = saisir("\nNuméro du bon à confirmer")
        if id_bon is None:
            return

        bon = chercher_bon(bons, id_bon)
        if not bon:
            pause()
            return

        # Vérification du statut (E-TBI-05)
        if bon.get("statut") != "en_cours":
            print(f"  ERREUR [E-TBI-05] Ce bon est au statut '{statut_label(bon.get('statut'))}'.")
            pause()
            return

        print(f"\n  Bon         : {bon.get('id')}")
        print(f"  Désignation : {bon.get('designation')}")
        print(f"  Transporteur : {bon.get('transporteur', '—')}")
        print(f"  Commande    : {bon.get('commande', '—')}")
        print(f"  N° Colis    : {bon.get('no_colis', '—')}")

        # Vérification du colis par le transporteur
        anomalie = input("  >>> Des anomalies sur le colis ? (o/n) : ").strip().lower()
        if anomalie == "o":
            description = saisir("Décrivez l'anomalie")
            if description:
                dao.signaler_exception(
                    procede="expedition",
                    description=description,
                    no_colis=bon.get("no_colis", "—"),
                    id_personnel=""
                )
                print("  [OK] Rapport d'exception enregistré.")

        if not confirmer("Confirmer l'expédition de ce colis"):
            print("  Opération annulée.")
            pause()
            return

        dao.confirmer_expedition(id_bon)
        print(f"\n  [OK] Bon '{id_bon}' marqué comme expédié.")
        print(f"  Transporteur '{bon.get('transporteur', '—')}' a pris en charge le colis.")

    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


def signaler_exception_expedition():
    """
    Crée un rapport d'exception lié à une expédition.
    Appelle : dao.signaler_exception(procede, description, no_colis)
    """
    sous_titre("RAPPORT D'EXCEPTION — EXPÉDITION")
    try:
        bons = dao.get_bons_expedition()
        afficher_tableau(
            colonnes=[
                ("id",       "N° Bon",   10),
                ("no_colis", "N° Colis", 10),
                ("statut",   "Statut",   14),
            ],
            lignes=bons
        )

        no_colis = saisir("\nN° du colis concerné (ex: COL0003)")
        if no_colis is None:
            return

        description = saisir("Décrivez l'anomalie constatée")
        if description is None:
            return

        if not confirmer("Enregistrer ce rapport d'exception"):
            print("  Opération annulée.")
            pause()
            return

        dao.signaler_exception(
            procede="expedition",
            description=description,
            no_colis=no_colis,
            id_personnel=""
        )
        print(f"\n  [OK] Rapport d'exception enregistré pour le colis '{no_colis}'.")

    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


# =============================================================================
# MODULE 3 — INVENTAIRE
# =============================================================================

def menu_inventaire():
    """Sous-menu de consultation de l'inventaire."""
    while True:
        sous_titre("INVENTAIRE")
        print("   1. Voir tous les produits")
        print("   2. Rechercher un produit")
        print("   3. Voir les cellules de stockage")
        print("   4. Proposer un emplacement pour un colis")
        print("   0. Retour au menu principal")
        ligne()

        choix = input("  >>> Votre choix : ").strip().lower()

        if choix == "aide":
            afficher_aide()
        elif choix == "1":
            voir_produits()
        elif choix == "2":
            rechercher_produit()
        elif choix == "3":
            voir_cellules()
        elif choix == "4":
            proposer_emplacement()
        elif choix == "0":
            return
        else:
            print("  ERREUR [E-TBI-01] Option invalide. Choisissez un numéro parmi les options affichées.")


def voir_produits():
    """
    Affiche tous les produits de l'inventaire.
    Données source : dao.get_produits()
    Types disponibles : materiel, logiciel, emballage
    """
    sous_titre("INVENTAIRE — TOUS LES PRODUITS")
    try:
        # Filtre optionnel par type
        print("  Filtrer par type : 1=Tous  2=Matériel  3=Logiciel  4=Emballage")
        choix_type = input("  >>> Votre choix [1] : ").strip() or "1"

        filtre = {"1": None, "2": "materiel", "3": "logiciel", "4": "emballage"}
        type_filtre = filtre.get(choix_type)

        produits = dao.get_produits()
        if type_filtre:
            produits = [p for p in produits if p.get("type") == type_filtre]

        if not produits:
            print("  Aucun produit trouvé.")
        else:
            afficher_tableau(
                colonnes=[
                    ("ref",  "Référence",   12),
                    ("nom",  "Désignation", 32),
                    ("type", "Type",        12),
                    ("qte",  "Stock",        8),
                    ("zone", "Zone/Empl.",  16),
                ],
                lignes=produits
            )
            print(f"\n  Total : {len(produits)} produit(s)")
            stock_total = sum(p.get("qte", 0) for p in produits)
            print(f"  Stock total : {stock_total} unités")

    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


def rechercher_produit():
    """
    Recherche un produit par référence ou désignation (insensible à la casse).
    Données source : dao.get_produits()
    """
    sous_titre("RECHERCHE D'UN PRODUIT")
    try:
        terme = saisir("Référence ou désignation (ou une partie)")
        if terme is None:
            return

        produits = dao.get_produits()
        terme_lower = terme.lower()
        resultats = [
            p for p in produits
            if terme_lower in p.get("ref", "").lower()
            or terme_lower in p.get("nom", "").lower()
        ]

        if not resultats:
            print(f"  ERREUR [E-TBI-04] Aucun produit trouvé pour '{terme}'.")
        else:
            afficher_tableau(
                colonnes=[
                    ("ref",  "Référence",   12),
                    ("nom",  "Désignation", 34),
                    ("type", "Type",        12),
                    ("qte",  "Stock",        8),
                    ("zone", "Zone/Empl.",  16),
                ],
                lignes=resultats
            )

            # Détail des emplacements pour le premier résultat
            if len(resultats) == 1:
                p = resultats[0]
                emplacements = p.get("emplacements") or [p.get("emplacement", "—")]
                print(f"\n  Emplacements détaillés : {', '.join(emplacements)}")

    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


def voir_cellules():
    """
    Affiche toutes les cellules de stockage avec taux d'occupation.
    Données source : dao.get_cellules()
    """
    sous_titre("CELLULES DE STOCKAGE")
    try:
        cellules = dao.get_cellules()
        if not cellules:
            print("  Aucune cellule enregistrée.")
        else:
            # Résumé par zone
            zones = sorted(set(c.get("zone", "?") for c in cellules))
            print("  Résumé par zone :")
            for zone in zones:
                cel_zone = [c for c in cellules if c.get("zone") == zone]
                libres = sum(1 for c in cel_zone if c.get("dispo") == "libre")
                print(f"    Zone {zone} : {len(cel_zone)} cellules, {libres} libres")

            ligne()
            print("  Détail des cellules :")
            afficher_tableau(
                colonnes=[
                    ("id",        "Cellule",      10),
                    ("zone",      "Zone",          6),
                    ("dispo",     "Disponibilité",16),
                    ("pct",       "Occupation %", 13),
                    ("masse",     "Masse (kg)",   12),
                    ("masse_max", "Masse max (kg)",15),
                ],
                lignes=cellules
            )

    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


def proposer_emplacement():
    """
    Propose automatiquement une cellule libre adaptée à un colis.
    Appelle : dao.proposer_emplacement(zone, masse)
    Logique : cherche la cellule libre avec le taux d'occupation le plus bas.
    """
    sous_titre("PROPOSITION D'EMPLACEMENT")
    try:
        # Saisie de la zone
        zone = saisir_choix(
            "Zone souhaitée (E0 / E1 / E2 / E3)",
            ["E0", "E1", "E2", "E3", "e0", "e1", "e2", "e3"]
        )
        if zone is None:
            return
        zone = zone.upper()

        # Saisie de la masse
        masse_str = saisir(
            "Masse du colis en kg (ex: 12.5)",
            validateur=lambda v: _is_float_pos(v),
            msg_erreur="Saisissez un nombre décimal positif.",
            exemple="12.5"
        )
        if masse_str is None:
            return
        masse = float(masse_str)

        # Appel DAO
        cellule = dao.proposer_emplacement(zone, masse)

        if not cellule:
            print(f"\n  ERREUR [E-TBI-05] Aucune cellule libre disponible en zone {zone}")
            print(f"  pour une masse de {masse} kg.")
        else:
            masse_dispo = cellule.get("masse_max", 0) - cellule.get("masse", 0)
            print(f"\n  [OK] Emplacement proposé :")
            print(f"       Cellule     : {cellule.get('id')}")
            print(f"       Zone        : {zone}")
            print(f"       Occupation  : {cellule.get('pct', 0)} %")
            print(f"       Masse dispo : {masse_dispo:.1f} kg")
            print(f"  L'emplacement est calculé selon les cellules libres et les masses disponibles.")

    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


def _is_float_pos(valeur):
    """Vérifie que la valeur est un nombre décimal positif."""
    try:
        return float(valeur) >= 0
    except ValueError:
        return False


# =============================================================================
# MODULE 4 — RAPPORTS D'EXCEPTION
# =============================================================================

def menu_rapports():
    """Sous-menu de gestion des rapports d'exception."""
    while True:
        sous_titre("RAPPORTS D'EXCEPTION")
        print("   1. Voir tous les rapports")
        print("   2. Filtrer par statut")
        print("   3. Prendre en charge un rapport")
        print("   4. Résoudre un rapport")
        print("   0. Retour au menu principal")
        ligne()

        choix = input("  >>> Votre choix : ").strip().lower()

        if choix == "aide":
            afficher_aide()
        elif choix == "1":
            voir_rapports()
        elif choix == "2":
            filtrer_rapports()
        elif choix == "3":
            prendre_en_charge_rapport()
        elif choix == "4":
            resoudre_rapport()
        elif choix == "0":
            return
        else:
            print("  ERREUR [E-TBI-01] Option invalide. Choisissez un numéro parmi les options affichées.")


def voir_rapports(statut=None):
    """
    Affiche les rapports d'exception, avec filtre optionnel sur le statut.
    Données source : dao.get_rapports(statut=statut)
    """
    sous_titre("RAPPORTS D'EXCEPTION")
    try:
        rapports = dao.get_rapports(statut=statut)
        if not rapports:
            print("  Aucun rapport d'exception enregistré.")
        else:
            afficher_tableau(
                colonnes=[
                    ("id",          "N° Rapport", 10),
                    ("procede",     "Procédé",    12),
                    ("date",        "Date",        18),
                    ("no_colis",    "N° Colis",   10),
                    ("statut",      "Statut",     12),
                    ("description", "Description",30),
                ],
                lignes=rapports
            )
            en_attente = sum(1 for r in rapports if r.get("statut") == "en_attente")
            print(f"\n  Total : {len(rapports)} rapport(s)  |  En attente : {en_attente}")
    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


def filtrer_rapports():
    """Filtre les rapports par statut choisi par l'utilisateur."""
    sous_titre("FILTRER LES RAPPORTS")
    print("  1. En attente")
    print("  2. En cours")
    print("  3. Résolus")
    choix = input("  >>> Votre choix : ").strip()

    mapping = {"1": "en_attente", "2": "en_cours", "3": "resolu"}
    statut = mapping.get(choix)
    if not statut:
        print("  ERREUR [E-TBI-01] Option invalide.")
        pause()
        return
    voir_rapports(statut=statut)


def prendre_en_charge_rapport():
    """
    Affecte un rapport à un personnel et le passe au statut 'en_cours'.
    Appelle : dao.prendre_en_charge_rapport(id_rap, id_personnel)
    """
    sous_titre("PRISE EN CHARGE D'UN RAPPORT")
    try:
        rapports = dao.get_rapports(statut="en_attente")
        if not rapports:
            print("  Aucun rapport en attente.")
            pause()
            return

        afficher_tableau(
            colonnes=[
                ("id",          "N° Rapport", 10),
                ("procede",     "Procédé",    12),
                ("no_colis",    "N° Colis",   10),
                ("description", "Description",36),
            ],
            lignes=rapports
        )

        id_rap = saisir("\nN° du rapport à prendre en charge")
        if id_rap is None:
            return

        # Vérification de l'existence (E-TBI-04)
        tous = dao.get_rapports()
        rapport = next((r for r in tous if r.get("id") == id_rap), None)
        if not rapport:
            print(f"  ERREUR [E-TBI-04] Rapport '{id_rap}' introuvable.")
            pause()
            return

        # Vérification du statut (E-TBI-05)
        if rapport.get("statut") != "en_attente":
            print(f"  ERREUR [E-TBI-05] Ce rapport est au statut '{statut_label(rapport.get('statut'))}'.")
            pause()
            return

        id_personnel = saisir("Votre identifiant personnel (ex: PER0001)")
        if id_personnel is None:
            return

        if not confirmer(f"Prendre en charge le rapport '{id_rap}'"):
            print("  Opération annulée.")
            pause()
            return

        dao.prendre_en_charge_rapport(id_rap, id_personnel)
        print(f"\n  [OK] Rapport '{id_rap}' pris en charge par '{id_personnel}'.")

    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


def resoudre_rapport():
    """
    Marque un rapport d'exception comme résolu.
    Appelle : dao.resoudre_rapport(id_rap, id_personnel)
    """
    sous_titre("RÉSOLUTION D'UN RAPPORT")
    try:
        rapports = dao.get_rapports(statut="en_cours")
        if not rapports:
            print("  Aucun rapport en cours. Prenez d'abord un rapport en charge.")
            pause()
            return

        afficher_tableau(
            colonnes=[
                ("id",          "N° Rapport", 10),
                ("procede",     "Procédé",    12),
                ("no_colis",    "N° Colis",   10),
                ("resolu_par",  "Pris en charge par",20),
                ("description", "Description",26),
            ],
            lignes=rapports
        )

        id_rap = saisir("\nN° du rapport à résoudre")
        if id_rap is None:
            return

        tous = dao.get_rapports()
        rapport = next((r for r in tous if r.get("id") == id_rap), None)
        if not rapport:
            print(f"  ERREUR [E-TBI-04] Rapport '{id_rap}' introuvable.")
            pause()
            return

        if rapport.get("statut") != "en_cours":
            print(f"  ERREUR [E-TBI-05] Ce rapport est au statut '{statut_label(rapport.get('statut'))}'.")
            pause()
            return

        id_personnel = saisir("Votre identifiant personnel")
        if id_personnel is None:
            return

        if not confirmer(f"Marquer le rapport '{id_rap}' comme résolu"):
            print("  Opération annulée.")
            pause()
            return

        dao.resoudre_rapport(id_rap, id_personnel)
        print(f"\n  [OK] Rapport '{id_rap}' résolu par '{id_personnel}'.")
        print(f"  Date de résolution : {datetime.now().strftime('%Y-%m-%d %H:%M')}")

    except Exception as e:
        journaliser("E-TBI-06", str(e))
        print("  ERREUR [E-TBI-06] Erreur système. Contactez le responsable informatique.")
    pause()


# =============================================================================
# BOUCLE PRINCIPALE
# =============================================================================

def main():
    """
    Point d'entrée du TBI.
    Boucle principale avec gestion du timeout (E-TBI-07) et des exceptions.
    """
    # Affichage d'un message de bienvenue
    titre("SGE — Système de Gestion d'Entrepôts  |  SAC")
    print("  Démarrage du mode dialogue (TBI)...")
    print(f"  Données chargées depuis : {AE_PATH}")
    time.sleep(0.5)

    while True:
        try:
            afficher_menu_principal()

            # Lecture du choix avec mesure du temps (E-TBI-07)
            debut = time.time()
            choix = input("  >>> Votre choix : ").strip().lower()
            elapsed = time.time() - debut

            # Timeout dépassé (E-TBI-07)
            if elapsed > TIMEOUT_SECONDES:
                print("\n  ERREUR [E-TBI-07] Session expirée après inactivité. Retour au menu principal.")
                continue

            if choix == "aide":
                afficher_aide()
            elif choix == "1":
                menu_reception()
            elif choix == "2":
                menu_expedition()
            elif choix == "3":
                menu_inventaire()
            elif choix == "4":
                menu_rapports()
            elif choix == "0":
                print("\n  Fermeture du SGE. À bientôt.")
                break
            else:
                # Option invalide au menu principal (E-TBI-01)
                print("  ERREUR [E-TBI-01] Option invalide. Choisissez un numéro entre 0 et 4.")

        except KeyboardInterrupt:
            # Ctrl+C : sortie propre
            print("\n\n  Interruption clavier détectée (Ctrl+C). Fermeture du SGE.")
            break
        except Exception as e:
            # Erreur système inattendue (E-TBI-06)
            journaliser("E-TBI-06", str(e))
            print("  ERREUR [E-TBI-06] Une erreur inattendue est survenue.")
            print("  Contactez le responsable informatique. Retour au menu principal.")


# =============================================================================
# POINT D'ENTRÉE
# =============================================================================
if __name__ == "__main__":
    main()
