-- =====================================================================
-- LabTrack - Données de test (entièrement fictives)
--
-- Usage (après schema.sql) :  sqlite3 db/labtrack.db < db/seed.sql
--
-- Comptes de test : mot de passe "labtrack123" pour tout le monde.
-- Hash au format "scrypt$<sel_hex>$<hash_hex>", compatible avec Node :
--   crypto.scryptSync(mdp, Buffer.from(sel, 'hex'), 64).toString('hex')
--
-- Le jeu couvre tous les statuts d'échantillon et d'analyse, un produit
-- non conforme (whey 80 g annoncés / 62 g mesurés), un rejet suivi d'une
-- revalidation, et des analyses non affectées.
-- =====================================================================

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

-- Vide les données de test (les tables de référence sont conservées)
DELETE FROM action;
DELETE FROM validation;
DELETE FROM analyse;
DELETE FROM echantillon;
DELETE FROM type_analyse;
DELETE FROM client;
DELETE FROM utilisateur;
DELETE FROM sqlite_sequence
 WHERE name IN ('action', 'validation', 'analyse', 'echantillon',
                'type_analyse', 'client', 'utilisateur');

-- ---------------------------------------------------------------------
-- Utilisateurs : un par rôle + un 2e technicien
-- ---------------------------------------------------------------------
INSERT INTO utilisateur (id_utilisateur, nom, prenom, adresse_mail, mot_de_passe, role, date_inscription) VALUES
    (1, 'Martin',  'Claire', 'claire.martin@labtrack.test',
        'scrypt$4c34930f0ddb386c42c1361449aa0589$75045710c4d8884d9f66c055071ef05574a971e97ddb46df9ea3997a031e6f1af3818750aa97f2b33238bc5efd72f3d0f02fdaffefadcc203546d9b0bab1b6a8',
        'ACCUEIL',      '2026-09-01 09:00:00'),
    (2, 'Durand',  'Lucas',  'lucas.durand@labtrack.test',
        'scrypt$8af1ed73d23f0d38598de188e3ec1cdb$33b450915d3692335bdabf7a5d3f9286ef7cf712e766638142502cdbdbef1eb8611ab27a15d6f0519a91a7a6ad9f5e6b88332bf2c25dbc61ac3a17c272e54a13',
        'TECHNICIEN',   '2026-09-01 09:05:00'),
    (3, 'Petit',   'Sarah',  'sarah.petit@labtrack.test',
        'scrypt$bf84cbf991e82bb80201ae03644e5108$1ebcede2c2b83c36464d1edd3ee704307e39df564934522648145081709aacf4bcfaf714e2f91feb980a046d01b3d4a05797c40327badee80f2eeecb235d27be',
        'TECHNICIEN',   '2026-09-15 10:00:00'),
    (4, 'Moreau',  'Julien', 'julien.moreau@labtrack.test',
        'scrypt$7a97749eeb09503f716363d4ec04f2c2$792e0fa35b39586eb1dbddbf2f4ed46f7e3f429c5d20509b531a517c5442050fa499db5c0edb74ffbcebd9b23391c8df58370aa82660d340a35d2e19c135b394',
        'RESP_QUALITE', '2026-09-01 09:10:00'),
    (5, 'Bernard', 'Sophie', 'sophie.bernard@labtrack.test',
        'scrypt$f28b8962cd0ba12f86454646de1a4a0b$1ebd06ec2625ebbeb632c1b14395bf0450ef47609ec4d62b540b6077dd4c61a55a97341010e3a1acde32939d06801866538ba593b7d981c06d32883bd5a69b27',
        'RESP_LABO',    '2026-09-01 08:30:00');

-- ---------------------------------------------------------------------
-- Clients (marques de compléments)
-- ---------------------------------------------------------------------
INSERT INTO client (id_client, nom, email, adresse, telephone) VALUES
    (1, 'NutriForce',      'qualite@nutriforce.test', '12 rue des Sports, Lyon',    '04 72 00 00 01'),
    (2, 'MuscleLab',       'contact@musclelab.test',  '5 avenue du Stade, Nantes',  '02 40 00 00 02'),
    (3, 'VitaPerf',        'labo@vitaperf.test',      '8 bd Olympique, Lille',      '03 20 00 00 03');

-- ---------------------------------------------------------------------
-- Catalogue des types d'analyses (tolérance en %)
-- ---------------------------------------------------------------------
INSERT INTO type_analyse (id_type_analyse, libelle, unite, tolerance) VALUES
    (1, 'Teneur en protéines', 'g/100 g',  10),
    (2, 'Teneur en créatine',  'g/100 g',   5),
    (3, 'Teneur en caféine',   'mg/dose',  10),
    (4, 'Teneur en glucides',  'g/100 g',  10),
    (5, 'Teneur en lipides',   'g/100 g',  15),
    (6, 'Teneur en sodium',    'mg/100 g', 20);

-- ---------------------------------------------------------------------
-- Échantillons : un par statut au minimum
-- ---------------------------------------------------------------------
INSERT INTO echantillon (id_echantillon, id_client, reference, produit, numero_lot, date_reception, statut) VALUES
    (1, 1, 'ECH-2026-001', 'Whey Isolate Vanille',    'NF-2610-A', '2026-11-02 09:15:00', 'TERMINE'),
    (2, 2, 'ECH-2026-002', 'Créatine Monohydrate',    'ML-2610-07','2026-11-03 10:40:00', 'RAPPORT_EMIS'),
    (3, 3, 'ECH-2026-003', 'Pré-workout Fruits Rouges','VP-2611-12','2026-11-12 14:05:00', 'EN_ANALYSE'),
    (4, 1, 'ECH-2026-004', 'Whey Chocolat',           'NF-2611-B', '2026-11-16 08:50:00', 'EN_ANALYSE'),
    (5, 2, 'ECH-2026-005', 'Gainer Banane',           'ML-2611-03','2026-11-25 11:20:00', 'RECU'),
    (6, 3, 'ECH-2026-006', 'Créatine HCl',            'VP-2609-01','2026-10-05 09:30:00', 'ARCHIVE'),
    (7, 2, 'ECH-2026-007', 'Whey Native',             'ML-2611-09','2026-11-24 15:45:00', 'EN_ANALYSE');

-- ---------------------------------------------------------------------
-- Analyses
-- conforme = |mesurée - déclarée| / déclarée * 100 <= tolérance
-- ---------------------------------------------------------------------
INSERT INTO analyse (id_analyse, id_echantillon, id_type_analyse, id_utilisateur,
                     valeur_declaree, valeur_mesuree, date_mesure, conforme, statut) VALUES
    -- Éch. 1 : l'exemple du brainstorming, 80 g annoncés, 62 g mesurés (écart 22,5 % > 10 %)
    ( 1, 1, 1, 2,  80.0,  62.0, '2026-11-04 10:00:00', 0, 'VALIDEE'),
    ( 2, 1, 4, 2,   5.0,   5.3, '2026-11-04 11:30:00', 1, 'VALIDEE'),        -- écart 6 %
    -- Éch. 2 : rejetée une fois puis revalidée (voir table validation)
    ( 3, 2, 2, 3,  99.0,  98.1, '2026-11-07 09:45:00', 1, 'VALIDEE'),        -- écart 0,9 %
    -- Éch. 3 : une analyse en attente de validation, une en cours
    ( 4, 3, 3, 2, 200.0, 214.0, '2026-11-20 14:10:00', 1, 'RESULTAT_SAISI'), -- écart 7 %
    ( 5, 3, 6, 3, 150.0,  NULL,  NULL,                 NULL, 'EN_COURS'),
    -- Éch. 4 : rejetée, retournée au technicien
    ( 6, 4, 1, 3,  75.0,  58.0, '2026-11-18 16:20:00', 0, 'REJETEE'),        -- écart 22,7 %
    -- Éch. 5 : tout juste reçu, analyses pas encore affectées
    ( 7, 5, 1, NULL, 20.0, NULL, NULL, NULL, 'A_FAIRE'),
    ( 8, 5, 4, NULL, 70.0, NULL, NULL, NULL, 'A_FAIRE'),
    -- Éch. 6 : archivé
    ( 9, 6, 2, 2, 100.0,  97.5, '2026-10-07 10:00:00', 1, 'VALIDEE'),        -- écart 2,5 %
    -- Éch. 7 : affectées, à faire (page "mes analyses à faire")
    (10, 7, 1, 3,  82.0,  NULL, NULL, NULL, 'A_FAIRE'),
    (11, 7, 5, 2,   6.5,  NULL, NULL, NULL, 'A_FAIRE');

-- ---------------------------------------------------------------------
-- Validations (responsable qualité, niveau 2)
-- ---------------------------------------------------------------------
INSERT INTO validation (id_validation, id_analyse, id_utilisateur, decision, motif, date_validation, niveau) VALUES
    (1, 1, 4, 'VALIDEE', 'Écart confirmé après contre-mesure : produit non conforme', '2026-11-05 09:00:00', 2),
    (2, 2, 4, 'VALIDEE', NULL,                                                         '2026-11-05 09:05:00', 2),
    (3, 3, 4, 'REJETEE', 'Étalon de référence périmé, refaire la mesure',              '2026-11-06 15:30:00', 2),
    (4, 3, 4, 'VALIDEE', NULL,                                                         '2026-11-07 11:00:00', 2),
    (5, 6, 4, 'REJETEE', 'Écart incohérent avec le lot précédent, vérifier la pesée',  '2026-11-19 10:15:00', 2),
    (6, 9, 4, 'VALIDEE', NULL,                                                         '2026-10-08 09:00:00', 2);

-- ---------------------------------------------------------------------
-- Journal d'historique (extrait : parcours complet de l'échantillon 1
-- + rejet de l'analyse 6 + une connexion)
-- type_action : 1 CREATION, 2 MODIFICATION, 4 CHANGEMENT_STATUT,
--   5 AFFECTATION, 6 SAISIE_RESULTAT, 7 VALIDATION, 8 REJET, 9 CONNEXION
-- entite : 1 UTILISATEUR, 4 ECHANTILLON, 5 ANALYSE
-- ---------------------------------------------------------------------
INSERT INTO action (id_utilisateur, id_type_action, id_entite, id_cible, details_action, date_action) VALUES
    (1, 1, 4, 1, 'Réception de l''échantillon ECH-2026-001',                     '2026-11-02 09:15:00'),
    (1, 1, 5, 1, 'Ajout analyse protéines (déclaré 80 g/100 g)',                  '2026-11-02 09:16:00'),
    (1, 1, 5, 2, 'Ajout analyse glucides (déclaré 5 g/100 g)',                    '2026-11-02 09:16:30'),
    (5, 5, 5, 1, 'Affectation à Lucas Durand',                                    '2026-11-03 08:30:00'),
    (5, 5, 5, 2, 'Affectation à Lucas Durand',                                    '2026-11-03 08:30:30'),
    (2, 4, 4, 1, 'Statut RECU -> EN_ANALYSE',                                     '2026-11-04 09:30:00'),
    (2, 6, 5, 1, 'Résultat protéines saisi : 62 g/100 g',                         '2026-11-04 10:00:00'),
    (2, 6, 5, 2, 'Résultat glucides saisi : 5.3 g/100 g',                         '2026-11-04 11:30:00'),
    (4, 7, 5, 1, 'Analyse validée : produit non conforme',                        '2026-11-05 09:00:00'),
    (4, 7, 5, 2, 'Analyse validée',                                               '2026-11-05 09:05:00'),
    (4, 4, 4, 1, 'Statut EN_ANALYSE -> TERMINE (toutes les analyses validées)',  '2026-11-05 09:05:10'),
    (3, 6, 5, 6, 'Résultat protéines saisi : 58 g/100 g',                         '2026-11-18 16:20:00'),
    (4, 8, 5, 6, 'Analyse rejetée : écart incohérent avec le lot précédent',      '2026-11-19 10:15:00'),
    (5, 9, 1, 5, 'Connexion',                                                     '2026-11-27 08:45:00');

COMMIT;
