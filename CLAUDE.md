# CLAUDE.md

Contexte projet pour Claude Code, lu automatiquement à chaque session.
Doc en français · code, identifiants et commentaires en anglais.

---

## Vue d'ensemble

Pipeline de données end-to-end sur les trajets de taxis jaunes de New York (NYC TLC Yellow Taxi), période **2024 + début 2025** (~40-60M lignes, fichiers Parquet mensuels). Projet d'étude, 3 personnes, 3 jours.

Objectif : ingérer les données brutes, les nettoyer, les transformer et produire des tables analytiques + des KPIs, le tout orchestré automatiquement.

## Stack

- **Snowflake** — Data Warehouse, architecture medallion `RAW → STAGING → FINAL`
- **dbt Core** (`>=1.8`) — transformations SQL, tests qualité, documentation
- **Python** (`>=3.10`) + `snowflake-connector-python` — ingestion des Parquet
- **GitHub Actions** — orchestration (pas d'Airflow, pas de Docker)
- **uv** — gestion de l'environnement Python

## Architecture des données

```
RAW.yellow_taxi_trips          → données brutes Parquet, types permissifs
  └── STAGING.clean_trips       → stg_yellow_trips : nettoyage + colonnes calculées
        ├── FINAL.daily_summary    → KPIs agrégés par jour
        ├── FINAL.zone_analysis    → analyse par zone géographique TLC
        └── FINAL.hourly_patterns  → patterns temporels heure par heure
```

Objets Snowflake (noms fixes, ne pas dévier) :
`NYC_TAXI_WH` (warehouse, taille **XS**), `NYC_TAXI_DB` (base), schémas `RAW` / `STAGING` / `FINAL`, rôle `NYC_TAXI_ROLE`.

## Structure du dépôt

```
.github/workflows/   pipeline.yml (ingestion + dbt), dbt_ci.yml (tests sur PR)
ingestion/           load_to_raw.py (download → PUT stage → COPY INTO), utils.py
snowflake/           00_setup.sql, 01_raw_table.sql, 02_resource_monitor.sql
dbt_nyc_taxi/        projet dbt (models/staging, models/marts, seeds, tests, macros)
docs/                architecture.md, rapport_analyse.md
```

Les scripts `snowflake/*.sql` sont des scripts d'infra à exécuter **une seule fois** (setup). Le pipeline récurrent vit dans `ingestion/` (extraction → RAW) et `dbt_nyc_taxi/` (transformation).

## Environnement & commandes

Privilégier `uv run` partout pour rester compatible Windows / macOS / Linux (évite l'activation manuelle du venv).

```bash
# Setup initial
uv venv
uv pip install -r requirements.txt

# Ingestion (toujours tester sur 1 mois avant de scaler)
uv run python ingestion/load_to_raw.py --year 2025 --month 01

# dbt (depuis dbt_nyc_taxi/)
cd dbt_nyc_taxi
uv run dbt deps        # installe les packages (dbt-utils)
uv run dbt seed        # charge taxi_zone_lookup.csv
uv run dbt run         # exécute les modèles
uv run dbt test        # tests qualité
uv run dbt build       # run + test combinés
uv run dbt docs generate && uv run dbt docs serve
```

## Conventions de code

**Langue** : prose/doc/README en français ; noms de variables, fonctions, modèles, colonnes et commentaires en anglais.

**SQL / dbt** :
- Mots-clés SQL en MAJUSCULES, identifiants en `snake_case`.
- Une CTE par étape logique, nommée explicitement ; `SELECT` final qui assemble les CTE.
- Pas de `SELECT *` dans les modèles `marts` (lister les colonnes).
- Modèles `staging` préfixés `stg_`, un modèle par source.
- Référencer les sources via `{{ source(...) }}` et les modèles via `{{ ref(...) }}`, jamais en dur.

**Python** :
- Respecter PEP 8, type hints sur les signatures de fonctions.
- Aucune logique métier dans le `__main__` ; fonctions testables dans `utils.py`.

**Commits** : convention Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`).

## Conventions dbt

- **Matérialisations** : `staging` en `view`, `marts` en `table` (configuré dans `dbt_project.yml`).
- **Schéma de dev par personne** : la cible `dev` écrit dans `DBT_<PRENOM>` (via `env_var`), pour éviter les collisions sur le compte partagé. La cible `prod` (utilisée par GitHub Actions) écrit dans `STAGING` / `FINAL`.
- Tests génériques (`not_null`, `unique`, `accepted_values`, `relationships`) déclarés dans les `_models.yml` ; tests métier custom dans `tests/`.
- Tout nouveau modèle doit avoir une entrée de documentation et au moins un test avant merge.

## Règles critiques — garde-fous

> **⚠️ Le dépôt est PUBLIC.** Aucune donnée sensible ne doit jamais y figurer.

- **Jamais de secret en dur** dans le code (mot de passe, identifiant de compte Snowflake, clé). Toujours via variables d'environnement (`os.environ[...]` en Python, `env_var(...)` en dbt). Si une valeur ressemble à un credential — elle va dans `.env`, jamais dans un fichier suivi.
- `profiles.yml`, `.env`, `target/`, `dbt_packages/`, `logs/` sont dans `.gitignore` — ne jamais les forcer (`git add -f` interdit).
- **Ne jamais commit directement sur `main` ni `develop`.** Toujours une branche feature (`feat/...`, `fix/...`) puis une PR.
- **Toujours lancer `uv run dbt test` avant d'ouvrir une PR.**
- Ne jamais exécuter `dbt run` avec la cible `prod` en local ; utiliser la cible `dev` (schéma personnel).
- **Discipline de coût (compte d'essai, $400 de crédits)** : garder le warehouse en **XS**, auto-suspend court. Pendant l'exploration des données RAW, toujours utiliser `LIMIT` pour ne pas scanner ~40M lignes inutilement.

## Spécificités du dataset — pièges à connaître

- **Schémas hétérogènes 2024 vs 2025** : les fichiers 2025 ont une colonne `cbd_congestion_fee` (tarification de congestion, entrée en vigueur le 5 janvier 2025) absente des fichiers 2024. La table `RAW` déclare **toutes** les colonnes, et le `COPY INTO` utilise `MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE` pour que les colonnes manquantes se chargent en `NULL`.
- **Types Parquet inconsistants entre mois** (ex. `passenger_count` parfois DOUBLE, parfois INT64) — la table `RAW` utilise des types permissifs (`NUMBER`/`FLOAT`, `TIMESTAMP_NTZ`).
- **`tip_amount` n'est renseigné que pour les paiements carte** (`payment_type = 1`). Le taux de pourboire ne se calcule que sur ce sous-ensemble, sinon il est biaisé.
- Les données TLC sont publiées avec ~2 mois de décalage.
- Source des fichiers : `https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_YYYY-MM.parquet`.

## Transformations attendues (dans `clean_trips` / marts)

Règles de nettoyage (à appliquer dans `stg_yellow_trips`) :
- Exclure les montants négatifs (`fare_amount >= 0`, `total_amount >= 0`).
- Exclure les trajets incohérents (`tpep_dropoff_datetime > tpep_pickup_datetime`).
- Filtrer les distances aberrantes (`trip_distance > 0 AND trip_distance < 100`).
- Gérer les valeurs manquantes (`passenger_count`, zones) explicitement.

Colonnes calculées :
- `trip_duration_min` = `DATEDIFF('minute', pickup, dropoff)` (garder > 0 et borné).
- `avg_speed_mph` = `trip_distance / NULLIF(trip_duration_min / 60, 0)`.
- Dimensions temporelles : `pickup_hour`, `pickup_date`, `pickup_dow`, `pickup_month`.
- `tip_rate` = `tip_amount / NULLIF(fare_amount, 0)` (uniquement `payment_type = 1`).
- Catégorie de distance (short / medium / long) et période de la journée (night / morning / afternoon / evening) via `CASE`.

## Workflow Git

1. Brancher depuis `develop` : `git checkout -b feat/ma-feature`
2. Développer, tester localement (`dbt run` puis `dbt test` en cible `dev`)
3. PR vers `develop`, ≥ 1 reviewer, CI verte
4. `develop → main` à la fin de chaque sprint validé

## Équipe & périmètres

| Membre | Périmètre principal |
|--------|---------------------|
| [Prénom A] | Infra Snowflake + Ingestion + Monitoring |
| [Prénom B] | dbt Staging + Qualité |
| [Prénom C] | Analytics (marts) + Rapport + Dashboard |

> Adapter les prénoms. Chacun review les PR des autres.
