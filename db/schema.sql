-- =====================================================================
-- LabTrack - Schéma de la base SQLite
-- Basé sur docs/UML_LabTrack_final.mdj
--
-- Usage :  sqlite3 db/labtrack.db < db/schema.sql
-- Le script supprime puis recrée toutes les tables : il est rejouable.
--
-- Conventions :
--   * Dates stockées en TEXT au format ISO 8601 ('2026-11-27 14:30:00').
--   * Booléens stockés en INTEGER (0 = faux, 1 = vrai).
--   * Statuts, rôles et décisions stockés en codes MAJUSCULES, contrôlés
--     par des CHECK (le frontend se charge de les afficher joliment).
--   * Les clés étrangères ne sont actives que si chaque connexion fait
--     "PRAGMA foreign_keys = ON;" (à faire aussi dans le backend Node).
-- =====================================================================

PRAGMA foreign_keys = OFF;

DROP TABLE IF EXISTS action;
DROP TABLE IF EXISTS validation;
DROP TABLE IF EXISTS analyse;
DROP TABLE IF EXISTS echantillon;
DROP TABLE IF EXISTS type_analyse;
DROP TABLE IF EXISTS client;
DROP TABLE IF EXISTS utilisateur;
DROP TABLE IF EXISTS type_action;
DROP TABLE IF EXISTS entite;

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- Utilisateur : les 4 rôles du labo
--   ACCUEIL       enregistre les échantillons reçus
--   TECHNICIEN    réalise les analyses et saisit les résultats
--   RESP_QUALITE  valide ou rejette les résultats
--   RESP_LABO     gère utilisateurs + catalogue, affecte les analyses
-- mot_de_passe : jamais en clair -> "scrypt$<sel_hex>$<hash_hex>"
-- ---------------------------------------------------------------------
CREATE TABLE utilisateur (
    id_utilisateur    INTEGER PRIMARY KEY AUTOINCREMENT,
    nom               VARCHAR(50)  NOT NULL,
    prenom            VARCHAR(50)  NOT NULL,
    adresse_mail      VARCHAR(255) NOT NULL UNIQUE,
    mot_de_passe      VARCHAR(255) NOT NULL,
    role              VARCHAR(50)  NOT NULL
                      CHECK (role IN ('ACCUEIL', 'TECHNICIEN', 'RESP_QUALITE', 'RESP_LABO')),
    date_inscription  DATETIME     NOT NULL DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- Client : marques / fabricants qui envoient leurs produits
-- ---------------------------------------------------------------------
CREATE TABLE client (
    id_client  INTEGER PRIMARY KEY AUTOINCREMENT,
    nom        VARCHAR(50) NOT NULL,
    email      VARCHAR(50),
    adresse    VARCHAR(50),
    telephone  VARCHAR(20)
);

-- ---------------------------------------------------------------------
-- Type_analyse : catalogue (ex. "Teneur en protéines", g/100 g, 10 %)
-- tolerance = écart maximal autorisé en POURCENTAGE de la valeur déclarée
-- ---------------------------------------------------------------------
CREATE TABLE type_analyse (
    id_type_analyse  INTEGER PRIMARY KEY AUTOINCREMENT,
    libelle          VARCHAR(255) NOT NULL UNIQUE,
    unite            VARCHAR(50)  NOT NULL,
    tolerance        DOUBLE       NOT NULL CHECK (tolerance >= 0)
);

-- ---------------------------------------------------------------------
-- Echantillon : un produit reçu par le labo (association "Appartenir")
-- Parcours : RECU -> EN_ANALYSE -> TERMINE -> RAPPORT_EMIS -> ARCHIVE
-- ---------------------------------------------------------------------
CREATE TABLE echantillon (
    id_echantillon  INTEGER PRIMARY KEY AUTOINCREMENT,
    id_client       INTEGER     NOT NULL REFERENCES client (id_client) ON DELETE RESTRICT,
    reference       VARCHAR(50) NOT NULL UNIQUE,
    produit         VARCHAR(50) NOT NULL,
    numero_lot      VARCHAR(50) NOT NULL,
    date_reception  DATETIME    NOT NULL DEFAULT (datetime('now')),
    statut          VARCHAR(50) NOT NULL DEFAULT 'RECU'
                    CHECK (statut IN ('RECU', 'EN_ANALYSE', 'TERMINE', 'RAPPORT_EMIS', 'ARCHIVE'))
);

-- ---------------------------------------------------------------------
-- Analyse : une mesure à faire sur un échantillon
--   "concerner" -> id_echantillon, "Porter_sur" -> id_type_analyse,
--   "affecter"  -> id_utilisateur (technicien, NULL tant que non affectée)
-- valeur_declaree : valeur de l'étiquette (saisie à l'accueil)
-- valeur_mesuree  : résultat du technicien (NULL tant que non saisi)
-- conforme        : calculé par l'appli (NULL tant que non mesuré)
-- Parcours : A_FAIRE -> EN_COURS -> RESULTAT_SAISI -> VALIDEE | REJETEE
--   (REJETEE : retour au technicien, qui refait la mesure)
-- ---------------------------------------------------------------------
CREATE TABLE analyse (
    id_analyse       INTEGER PRIMARY KEY AUTOINCREMENT,
    id_echantillon   INTEGER NOT NULL REFERENCES echantillon (id_echantillon) ON DELETE CASCADE,
    id_type_analyse  INTEGER NOT NULL REFERENCES type_analyse (id_type_analyse) ON DELETE RESTRICT,
    id_utilisateur   INTEGER          REFERENCES utilisateur (id_utilisateur) ON DELETE SET NULL,
    valeur_declaree  DOUBLE  NOT NULL,
    valeur_mesuree   DOUBLE,
    date_mesure      DATETIME,
    conforme         INTEGER CHECK (conforme IN (0, 1)),
    statut           VARCHAR(50) NOT NULL DEFAULT 'A_FAIRE'
                     CHECK (statut IN ('A_FAIRE', 'EN_COURS', 'RESULTAT_SAISI', 'VALIDEE', 'REJETEE')),
    -- Un résultat saisi / validé doit avoir une valeur mesurée
    CHECK (statut NOT IN ('RESULTAT_SAISI', 'VALIDEE') OR valeur_mesuree IS NOT NULL)
);

-- ---------------------------------------------------------------------
-- Validation : décision du responsable qualité ("subir" + "valider")
-- Une analyse peut avoir plusieurs validations (rejet puis revalidation).
-- niveau : 1 = saisie technicien, 2 = décision responsable qualité
-- Un rejet doit obligatoirement avoir un motif.
-- ---------------------------------------------------------------------
CREATE TABLE validation (
    id_validation    INTEGER PRIMARY KEY AUTOINCREMENT,
    id_analyse       INTEGER      NOT NULL REFERENCES analyse (id_analyse) ON DELETE CASCADE,
    id_utilisateur   INTEGER      NOT NULL REFERENCES utilisateur (id_utilisateur) ON DELETE RESTRICT,
    decision         VARCHAR(50)  NOT NULL CHECK (decision IN ('VALIDEE', 'REJETEE')),
    motif            VARCHAR(255),
    date_validation  DATETIME     NOT NULL DEFAULT (datetime('now')),
    niveau           INTEGER      NOT NULL DEFAULT 2 CHECK (niveau IN (1, 2)),
    CHECK (decision <> 'REJETEE' OR (motif IS NOT NULL AND trim(motif) <> ''))
);

-- ---------------------------------------------------------------------
-- Journal d'historique : Type_action + Entite + Action
-- ---------------------------------------------------------------------
CREATE TABLE type_action (
    id_type_action  INTEGER PRIMARY KEY AUTOINCREMENT,
    type            VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE entite (
    id_entite  INTEGER PRIMARY KEY AUTOINCREMENT,
    nom        VARCHAR(50) NOT NULL UNIQUE
);

-- id_cible : id de la ligne concernée dans la table désignée par id_entite
--            (ex. id_entite = ANALYSE et id_cible = 3 -> l'analyse n°3).
--            Pas de clé étrangère possible car la table cible varie :
--            c'est Action.journaliser() qui garantit que l'id existe.
-- Utilisé par journaliser(type, entite, id_cible, details)
--         et getHistorique(entite, id_cible).
CREATE TABLE action (
    id_action        INTEGER PRIMARY KEY AUTOINCREMENT,
    id_utilisateur   INTEGER      NOT NULL REFERENCES utilisateur (id_utilisateur) ON DELETE RESTRICT,
    id_type_action   INTEGER      NOT NULL REFERENCES type_action (id_type_action) ON DELETE RESTRICT,
    id_entite        INTEGER      NOT NULL REFERENCES entite (id_entite) ON DELETE RESTRICT,
    id_cible         INTEGER      NOT NULL,
    details_action   VARCHAR(255),
    date_action      DATETIME     NOT NULL DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- Index sur les clés étrangères et les recherches fréquentes
-- ---------------------------------------------------------------------
CREATE INDEX idx_echantillon_client   ON echantillon (id_client);
CREATE INDEX idx_echantillon_statut   ON echantillon (statut);
CREATE INDEX idx_analyse_echantillon  ON analyse (id_echantillon);
CREATE INDEX idx_analyse_type         ON analyse (id_type_analyse);
CREATE INDEX idx_analyse_technicien   ON analyse (id_utilisateur, statut);  -- page "mes analyses à faire"
CREATE INDEX idx_validation_analyse   ON validation (id_analyse);
CREATE INDEX idx_action_cible         ON action (id_entite, id_cible);      -- getHistorique(entite, id_cible)
CREATE INDEX idx_action_utilisateur   ON action (id_utilisateur);

-- ---------------------------------------------------------------------
-- Données de référence (nécessaires au fonctionnement, pas des tests)
-- ---------------------------------------------------------------------
INSERT INTO type_action (id_type_action, type) VALUES
    (1, 'CREATION'),
    (2, 'MODIFICATION'),
    (3, 'SUPPRESSION'),
    (4, 'CHANGEMENT_STATUT'),
    (5, 'AFFECTATION'),
    (6, 'SAISIE_RESULTAT'),
    (7, 'VALIDATION'),
    (8, 'REJET'),
    (9, 'CONNEXION');

INSERT INTO entite (id_entite, nom) VALUES
    (1, 'UTILISATEUR'),
    (2, 'CLIENT'),
    (3, 'TYPE_ANALYSE'),
    (4, 'ECHANTILLON'),
    (5, 'ANALYSE'),
    (6, 'VALIDATION');
