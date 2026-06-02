# Configuration dbt — NYC Taxi

## Mise en place locale

Copier `.env.example` à la racine du projet en `.env` et renseigner ses valeurs :

```bash
cp ../.env.example ../.env
```

```bash
# .env
SNOWFLAKE_ACCOUNT=<compte>.snowflakecomputing.com
SNOWFLAKE_USER=<username>
SNOWFLAKE_PASSWORD=<mot-de-passe>
DBT_USER=LOUNES        # en majuscules — détermine votre schéma dev
DBT_PROFILES_DIR=.     # pointe dbt vers dbt_nyc_taxi/profiles.yml
```

Puis sourcer le fichier avant toute commande dbt :

```bash
source ../.env
```

C'est tout. Aucun fichier `~/.dbt/profiles.yml` à créer manuellement.

## Commandes courantes

Toutes les commandes se lancent depuis ce dossier (`dbt_nyc_taxi/`) :

```bash
uv run dbt deps          # installe les packages (à faire une fois)
uv run dbt seed          # charge taxi_zone_lookup.csv dans Snowflake
uv run dbt run           # exécute les modèles
uv run dbt test          # lance les tests qualité
uv run dbt build         # run + test en une seule commande
uv run dbt compile       # vérifie le SQL sans toucher Snowflake
```

## Cibles (targets)

Le fichier `profiles.yml` définit trois cibles. La cible active par défaut est `dev`.

| Cible | Schéma Snowflake | Usage |
|---|---|---|
| `dev` | `DBT_<DBT_USER>` (ex: `DBT_LOUNES`) | Développement local, isolé par personne |
| `preprod` | `DBT_PREPROD` | Déclenché automatiquement sur push `develop` |
| `prod` | `STAGING` + `FINAL` | Déclenché automatiquement sur push `main` |

Pour cibler explicitement une cible :

```bash
uv run dbt run --target dev      # par défaut
uv run dbt run --target preprod
uv run dbt run --target prod     # ne jamais lancer en local
```

> Ne jamais lancer `--target prod` en local. La cible `prod` est réservée à GitHub Actions.

## Résolution des schémas

La macro `generate_schema_name` (`macros/generate_schema_name.sql`) contrôle où dbt écrit les modèles :

- **Cible `prod`** → respecte les schémas déclarés dans `dbt_project.yml` : `STAGING` pour les modèles staging, `FINAL` pour les marts.
- **Toute autre cible** (`dev`, `preprod`) → tous les modèles atterrissent dans le schéma de la cible (`DBT_LOUNES`, `DBT_PREPROD`), sans séparation staging/marts.

Sans cette macro, dbt concatènerait les deux noms et produirait des schémas parasites comme `DBT_LOUNES_STAGING`.

## Structure des modèles

```
models/
  staging/    → vues (stg_*) : nettoyage et typage des données brutes
  marts/      → tables : agrégats et KPIs exposés aux analyses
```

Les matérialisations sont configurées dans `dbt_project.yml` :
- `staging` → `view`
- `marts` → `table`

## profiles.yml

Le fichier `profiles.yml` est commité dans ce dossier. Il ne contient aucune valeur sensible — tout passe par `env_var()` qui lit depuis `.env`. Le fichier `.env` lui-même n'est jamais commité.
