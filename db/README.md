# Base de données LabTrack (SQLite)

| Fichier       | Rôle |
|---------------|------|
| `schema.sql`  | Crée (ou recrée) toutes les tables, les index et les données de référence (types d'action, entités). |
| `seed.sql`    | Remplit la base avec des données de test fictives. |
| `labtrack.db` | La base générée. **Non versionnée** (voir `.gitignore`) : chacun la recrée en local. |

## Créer la base

Depuis la racine du dépôt :

```bash
sqlite3 db/labtrack.db < db/schema.sql
sqlite3 db/labtrack.db < db/seed.sql
```

Relancer ces deux commandes remet la base à zéro.

## Comptes de test

Mot de passe : `labtrack123` pour tous.

| Email | Rôle |
|-------|------|
| claire.martin@labtrack.test | ACCUEIL |
| lucas.durand@labtrack.test | TECHNICIEN |
| sarah.petit@labtrack.test | TECHNICIEN |
| julien.moreau@labtrack.test | RESP_QUALITE |
| sophie.bernard@labtrack.test | RESP_LABO |

Les mots de passe sont hachés avec scrypt (module `crypto` intégré à Node, pas de bibliothèque à installer),
au format `scrypt$<sel_hex>$<hash_hex>` :

```js
const [, sel, hash] = stocke.split('$');
const ok = crypto.scryptSync(mdp, Buffer.from(sel, 'hex'), 64).toString('hex') === hash;
```

## Conventions

- Dates en texte ISO 8601 (`2026-11-27 14:30:00`), booléens en `0`/`1`.
- Statuts, rôles et décisions en codes majuscules (`A_FAIRE`, `RESP_QUALITE`…), vérifiés par des `CHECK`.
- `type_analyse.tolerance` est un pourcentage : conforme si `|mesurée − déclarée| / déclarée × 100 ≤ tolérance`.
- SQLite n'active les clés étrangères que si chaque connexion exécute `PRAGMA foreign_keys = ON;` : le backend doit le faire à l'ouverture.

## Passage de l'UML aux tables

Le schéma suit `docs/UML_LabTrack_final.mdj` : chaque classe devient une table, avec les mêmes attributs.

- Les associations deviennent des clés étrangères : `echantillon.id_client`, `analyse.id_echantillon`, `analyse.id_type_analyse`, `analyse.id_utilisateur` (technicien, nullable), `validation.id_analyse`, `validation.id_utilisateur`, `action.id_utilisateur`, `action.id_type_action`, `action.id_entite`.
- `action.id_cible` est l'id de l'objet concerné dans la table désignée par `id_entite` (ex. ANALYSE n°3). Ce n'est pas une clé étrangère, car la table cible varie : `journaliser()` doit vérifier que l'id existe.
