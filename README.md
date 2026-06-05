# NYC Yellow Taxi — Pipeline de données end-to-end

Pipeline de données complet sur les trajets de taxis jaunes de New York (NYC TLC Yellow Taxi), couvrant la période **2024 – début 2025** (~40–60 millions de lignes). Projet réalisé en 3 jours par 3 personnes dans le cadre de la formation **Data Engineering — Simplon Promotion P1 2025**.

**Équipe** : Ashley · Matthieu · Lounes

---

## Sommaire

- [Contexte et objectifs](#contexte-et-objectifs)
- [Architecture](#architecture)
- [Choix techniques](#choix-techniques)
- [Prérequis](#prérequis)
- [Installation et configuration](#installation-et-configuration)
- [Lancer le pipeline](#lancer-le-pipeline)
- [Structure du dépôt](#structure-du-dépôt)
- [Modèles de données](#modèles-de-données)
- [Tests qualité](#tests-qualité)
- [CI/CD](#cicd)
- [Difficultés rencontrées](#difficultés-rencontrées)
- [Pistes d'amélioration](#pistes-damélioration)
- [Contribuer au projet](#contribuer-au-projet)

---

## Contexte et objectifs

La **NYC TLC** (Taxi & Limousine Commission) publie chaque mois les données de tous les trajets de taxis jaunes de New York sous forme de fichiers Parquet (~200–500 MB par mois). L'objectif du projet est de construire un pipeline de données end-to-end :

1. **Ingérer** les fichiers Parquet bruts dans un Data Warehouse Snowflake
2. **Nettoyer et enrichir** les données via des transformations dbt
3. **Produire des tables analytiques** (KPIs par jour, par zone géographique, par heure)
4. **Automatiser** l'ensemble via GitHub Actions (pas d'Airflow, pas de Docker)

---

## Architecture

Le pipeline suit une architecture **medallion** en trois couches :

```
NYC TLC (fichiers Parquet mensuels)
         │
         ▼
[ingestion/load_to_raw.py]
         │  PUT → stage Snowflake
         │  COPY INTO
         ▼
NYC_TAXI_DB.RAW.yellow_taxi_trips        ← données brutes, types permissifs
         │
         │  dbt (staging)
         ▼
STAGING.stg_yellow_trips                 ← vue : nettoyage + colonnes calculées
         │
         ├──────────────────────────────────────────────┐
         │  dbt (marts)                                 │
         ▼                      ▼                       ▼
FINAL.daily_summary     FINAL.zone_analysis    FINAL.hourly_patterns
KPIs agrégés/jour       analyse par zone TLC   patterns par heure
```

**Objets Snowflake** (noms fixes) :

| Objet | Valeur |
|---|---|
| Warehouse | `NYC_TAXI_WH` (taille XS, auto-suspend) |
| Base de données | `NYC_TAXI_DB` |
| Schémas | `RAW`, `STAGING`, `FINAL` |
| Rôle | `NYC_TAXI_ROLE` |

---

## Choix techniques

### Snowflake comme Data Warehouse

Snowflake a été choisi pour sa capacité à charger nativement des fichiers Parquet via des stages internes, son isolation compute/storage (facturation à l'usage, cruciale pour un compte d'essai), et sa compatibilité native avec dbt. Le warehouse en taille **XS** suffit pour les transformations analytiques et limite la consommation de crédits.

### dbt Core pour les transformations

dbt impose une structure claire (sources déclarées, modèles référencés, tests intégrés, documentation) et génère automatiquement le lineage. Le choix de dbt Core (open-source, sans serveur) était cohérent avec GitHub Actions comme orchestrateur. Les matérialisations choisies — `view` pour le staging, `table` pour les marts — reflètent le compromis fraîcheur/performance : le staging n'a pas besoin d'être matérialisé, les marts agrégés sont coûteux à recalculer à chaque requête.

### uv comme gestionnaire d'environnement

`uv` a été préféré à `pip` + `venv` pour sa rapidité et la commande `uv run --env-file` qui charge les variables d'environnement sans activation manuelle du venv — ce qui rend les commandes reproductibles sur Windows, macOS et Linux sans modification.

### GitHub Actions comme orchestrateur

Pas d'Airflow, pas de Prefect, pas de Docker — GitHub Actions couvre le besoin : déclenchement sur push/merge, scheduling mensuel via cron, gestion des secrets. Trois workflows distincts couvrent les trois environnements (CI sur PR, preprod sur `develop`, prod sur `main`).

### Schéma de dev par personne

Pour éviter les collisions sur le compte Snowflake partagé, chaque développeur écrit dans son propre schéma (`DBT_LOUNES`, `DBT_ASHLEY`, `DBT_MATTHIEU`) via la variable `DBT_USER`. Une macro `generate_schema_name` personnalisée contrôle ce comportement : en `dev`/`preprod`, tout atterrit dans le schéma de la cible ; en `prod`, les schémas `STAGING` et `FINAL` sont respectés.

---

## Prérequis

- **Python ≥ 3.10**
- **[uv](https://docs.astral.sh/uv/)** — gestionnaire d'environnement Python (`pip install uv` ou `brew install uv`)
- Un compte **Snowflake** avec les objets infra créés (voir [Initialisation Snowflake](#initialisation-snowflake))
- Accès au dépôt GitHub (pour les secrets CI/CD)

---

## Installation et configuration

### 1. Cloner le dépôt

```bash
git clone https://github.com/Simplon-DE-P1-2025/NYC-Taxi-Drinking-Terror.git
cd NYC-Taxi-Drinking-Terror
```

### 2. Installer les dépendances Python

```bash
uv venv
uv pip install -r requirements.txt
```

### 3. Configurer les variables d'environnement

```bash
cp .env.example .env
```

Renseigner `.env` :

```bash
SNOWFLAKE_ACCOUNT=<identifiant-compte>.snowflakecomputing.com
SNOWFLAKE_USER=<votre-username-snowflake>
SNOWFLAKE_PASSWORD=<votre-mot-de-passe>
DBT_USER=<VOTRE_PRENOM_EN_MAJUSCULES>   # ex: LOUNES → schéma dev DBT_LOUNES
DBT_PROFILES_DIR=.
```

> Le fichier `.env` est dans `.gitignore` — ne jamais le commiter.

### 4. Initialisation Snowflake (une seule fois)

Les scripts `snowflake/` créent l'infrastructure de base. Les exécuter **une seule fois** dans l'ordre, dans une session Snowflake avec un rôle ACCOUNTADMIN :

```sql
-- 1. Crée le warehouse, la base, les schémas, le rôle et les permissions
\i snowflake/00_setup.sql

-- 2. Crée la table RAW.yellow_taxi_trips avec toutes les colonnes
\i snowflake/01_raw_table.sql

-- 3. Configure un resource monitor pour limiter la consommation de crédits
\i snowflake/02_resource_monitor.sql
```

### 5. Installer les packages dbt

```bash
cd dbt_nyc_taxi
uv run --env-file ../.env dbt deps
```

### 6. Charger la seed zone TLC

```bash
uv run --env-file ../.env dbt seed
```

Ce seed charge `seeds/taxi_zone_lookup.csv` (265 zones TLC) dans Snowflake. Il est requis par le modèle staging pour enrichir chaque trajet avec le borough de départ/arrivée.

---

## Lancer le pipeline

### Ingestion (depuis la racine du projet)

```bash
# Charger un mois précis
uv run python ingestion/load_to_raw.py --year 2024 --month 01

# Backfill toute l'année 2024
for month in 01 02 03 04 05 06 07 08 09 10 11 12; do
  uv run python ingestion/load_to_raw.py --year 2024 --month $month
done

# Dernier mois disponible (mode pipeline automatisé)
uv run python ingestion/load_to_raw.py --last-available
```

Le script est **idempotent** : si un mois est déjà chargé, il est ignoré sans écrire de doublons.

### Transformations dbt (depuis `dbt_nyc_taxi/`)

```bash
cd dbt_nyc_taxi

uv run --env-file ../.env dbt run       # exécute les modèles (staging + marts)
uv run --env-file ../.env dbt test      # lance tous les tests qualité
uv run --env-file ../.env dbt build     # run + test en une commande
uv run --env-file ../.env dbt compile   # vérifie le SQL sans toucher Snowflake
```

> Ne jamais utiliser `--target prod` en local. La cible `prod` est réservée à GitHub Actions.

### Ordre complet pour un setup from scratch

```
1. snowflake/00_setup.sql          → infra Snowflake
2. snowflake/01_raw_table.sql      → table RAW
3. snowflake/02_resource_monitor.sql → monitoring coûts
4. dbt deps                        → packages dbt
5. dbt seed                        → zones TLC
6. ingestion/load_to_raw.py        → données brutes
7. dbt build                       → transformations + tests
```

---

## Structure du dépôt

```
NYC-Taxi-Drinking-Terror/
│
├── .github/workflows/
│   ├── dbt_ci.yml          # validation SQL sur chaque PR (dbt compile)
│   ├── dbt_preprod.yml     # dbt build preprod au merge sur develop
│   ├── dbt_deploy.yml      # dbt build prod au merge sur main
│   └── pipeline.yml        # ingestion mensuelle + prod (cron ou manuel)
│
├── ingestion/
│   ├── load_to_raw.py      # point d'entrée CLI (download → PUT → COPY INTO)
│   └── utils.py            # fonctions utilitaires (connexion, téléchargement, Snowflake)
│
├── snowflake/
│   ├── 00_setup.sql        # warehouse, base, schémas, rôle (setup one-shot)
│   ├── 01_raw_table.sql    # table RAW.yellow_taxi_trips
│   └── 02_resource_monitor.sql  # resource monitor Snowflake
│
├── dbt_nyc_taxi/
│   ├── models/
│   │   ├── staging/
│   │   │   ├── stg_yellow_trips.sql   # nettoyage + enrichissement
│   │   │   ├── _sources.yml           # déclaration source RAW
│   │   │   └── _models.yml            # tests génériques + documentation
│   │   └── marts/
│   │       ├── daily_summary.sql      # KPIs agrégés par jour
│   │       ├── zone_analysis.sql      # analyse par zone TLC
│   │       ├── hourly_patterns.sql    # patterns par heure
│   │       └── _models.yml
│   ├── tests/                         # tests singuliers (SQL qui retourne les violations)
│   ├── seeds/                         # taxi_zone_lookup.csv (265 zones TLC)
│   ├── macros/
│   │   └── generate_schema_name.sql   # routing schéma dev/preprod/prod
│   └── dbt_project.yml
│
├── docs/
│   └── architecture.md
│
├── presentation/
│   └── slides.md                      # slides Marp pour la présentation
│
├── .env.example
├── pyproject.toml
└── requirements.txt
```

---

## Modèles de données

### `stg_yellow_trips` — Staging (vue)

Nettoyage et enrichissement des données brutes. Filtres appliqués :

| Règle | Valeur |
|---|---|
| Période | 2024-01-01 → 2025-12-31 |
| Distance | > 0 mi et ≤ seuil P99 (~35 km) |
| Durée | > 0 et ≤ seuil P99 (~75 min) |
| Montants | `fare_amount >= 0`, `total_amount >= 0` |
| Cohérence temporelle | `dropoff > pickup` |

Colonnes calculées principales :

| Colonne | Description |
|---|---|
| `trip_id` | Surrogate key (dbt_utils) |
| `trip_distance_km` | Distance en km |
| `trip_duration_minutes` | Durée en minutes |
| `speed_kmh` | Vitesse moyenne |
| `tip_percentage` | Taux de pourboire (NULL si paiement non-carte) |
| `is_rush_hour` / `is_weekend` | Flags temporels |
| `time_of_day` | Tranche horaire (6 buckets) |
| `pickup_borough` / `dropoff_borough` | Borough enrichi depuis la seed TLC |
| `is_airport_trip` | TRUE si course aéroport |

> **Important** : `tip_percentage` est calculé uniquement pour `payment_type = 1` (carte). Les paiements cash ne renseignent pas `tip_amount` dans les données TLC — inclure le cash dans la moyenne biaiserait le taux vers le bas.

### `daily_summary` — Mart (table)

KPIs agrégés par jour et par borough : volume de trajets, revenus totaux, durée et vitesse moyennes, taux de pourboire carte.

### `zone_analysis` — Mart (table)

Performance par zone géographique TLC : zones les plus actives au départ et à l'arrivée, revenus et pourboires moyens par zone, activité totale.

### `hourly_patterns` — Mart (table)

Patterns temporels par heure de la journée : volume de trajets, vitesse moyenne, revenus, identification des heures de pointe.

---

## Tests qualité

Deux niveaux de tests dbt :

**Tests génériques** (déclarés dans les `_models.yml`) : `not_null`, `unique`, `accepted_values`, `relationships`, `dbt_utils.unique_combination_of_columns`.

**Tests singuliers** (fichiers SQL dans `dbt_nyc_taxi/tests/`) — chaque requête retourne les lignes en violation (0 ligne = OK) :

| Test | Modèle | Règle vérifiée |
|---|---|---|
| `assert_no_negative_amounts` | `stg_yellow_trips` | Aucun montant négatif après nettoyage |
| `assert_rush_hour_above_average_trips` | `hourly_patterns` | Les heures de pointe (7h–9h, 16h–19h) dépassent la moyenne en semaine |
| `assert_zone_activity_coherent` | `zone_analysis` | `total_zone_activity >= trips_as_origin` (invariant arithmétique) |
| `assert_daily_summary_manhattan_busiest_borough` | `daily_summary` | Manhattan est toujours le borough avec le plus de départs (~70 % du volume TLC) |
| `assert_daily_summary_weekday_trips_exceed_weekend` | `daily_summary` | Les jours de semaine ont plus de trajets que le week-end |
| `assert_daily_summary_manhattan_card_tips_positive` | `daily_summary` | Le taux de pourboire carte à Manhattan est ≥ 15 % |

---

## CI/CD

Trois workflows GitHub Actions couvrent le cycle de vie complet :

```
PR ouverte         → dbt_ci.yml       → dbt compile          (validation SQL, 0 écriture Snowflake)
Merge sur develop  → dbt_preprod.yml  → dbt build preprod     (schéma DBT_PREPROD)
Merge sur main     → dbt_deploy.yml   → dbt build prod        (STAGING + FINAL)
Cron (15/mois)     → pipeline.yml     → ingestion + dbt prod
```

Les secrets Snowflake (`SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`) sont stockés dans les GitHub Actions Secrets du dépôt — jamais dans le code.

---

## Difficultés rencontrées

### Schémas Parquet hétérogènes entre 2024 et 2025

La taxe de congestion CBD est entrée en vigueur le 5 janvier 2025, ajoutant une colonne `cbd_congestion_fee` absente de tous les fichiers 2024. Une approche naïve par position des colonnes aurait échoué au `COPY INTO`.

**Solution** : `MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE` dans le `COPY INTO` — Snowflake mappe par nom, les colonnes absentes du Parquet sont chargées à `NULL`, les colonnes inconnues sont ignorées. La table `RAW` déclare toutes les colonnes connues avec des types permissifs.

### Types Parquet inconsistants selon les mois

`passenger_count` est parfois un `DOUBLE`, parfois un `INT64` selon le mois. Snowflake rejette le chargement si le type Parquet ne correspond pas au type de la colonne cible.

**Solution** : types permissifs dans la table `RAW` (`NUMBER`, `FLOAT`, `TIMESTAMP_NTZ`). La rigueur typologique est imposée en staging, pas en ingestion.

### Isolation des environnements sur un compte partagé

Trois développeurs travaillant en parallèle sur un seul compte Snowflake risquaient de s'écraser mutuellement leurs tables.

**Solution** : macro `generate_schema_name` qui redirige toutes les écritures `dev` vers `DBT_<PRENOM>`. Chaque développeur a son propre espace de travail isolé, sans configuration supplémentaire.

### Biais du taux de pourboire sur les paiements cash

`tip_amount` n'est renseigné que pour les paiements carte dans les données TLC. Un calcul naïf sur l'ensemble des trajets aurait produit un taux artificiellement bas (~8 % vs ~22 % en réalité).

**Solution** : `tip_percentage` est calculé uniquement sur `payment_type = 1` dans le staging, avec une valeur `NULL` explicite pour les autres modes de paiement.

### Discipline de coût sur un compte d'essai

40–60 millions de lignes à scanner sans contrôle peut épuiser les crédits Snowflake en quelques heures d'exploration.

**Solution** : warehouse en taille XS, resource monitor configuré (`snowflake/02_resource_monitor.sql`), `LIMIT` systématique en exploration, suspension automatique du warehouse.

---

## Pistes d'amélioration

**Orchestration** : remplacer le cron GitHub Actions par un orchestrateur dédié (Dagster, Prefect, Astronomer) pour la gestion des dépendances entre tâches, les retry automatiques et l'observabilité.

**Données complémentaires** : enrichir avec les données météo NYC (API Open-Meteo, déjà accessible gratuitement) pour mesurer l'impact de la pluie/neige sur la demande — une corrélation souvent évoquée mais jamais quantifiée dans ce dataset.

**Prédiction de la demande** : avec 12+ mois de données, entraîner un modèle de série temporelle (Prophet ou LSTM) pour prédire le volume de trajets par zone et par heure — utile pour l'optimisation de la flotte.

**Tests de volume** : ajouter des tests dbt sur les seuils de volume (ex. : un jour avec moins de 50 000 trajets est suspect) pour détecter les mois incomplets ou les incidents d'ingestion.

**Incrémental sur le staging** : le modèle `stg_yellow_trips` est actuellement matérialisé en `view`, ce qui recalcule tout à chaque query. Passer à une matérialisation `incremental` sur la clé `pickup_date` réduirait significativement les coûts en production.

**Dashboard** : le Streamlit Snowflake couvre l'essentiel, mais une intégration Metabase ou Superset permettrait des analyses ad-hoc plus flexibles sans coder.

---

## Contribuer au projet

### Workflow Git

```bash
# 1. Toujours partir de develop
git checkout develop
git pull origin develop

# 2. Créer une branche feature
git checkout -b feat/ma-feature       # nouvelle fonctionnalité
git checkout -b fix/mon-correctif     # correction de bug
git checkout -b docs/ma-doc           # documentation

# 3. Développer et tester en local
cd dbt_nyc_taxi
uv run --env-file ../.env dbt build   # run + test combinés

# 4. Ouvrir une PR vers develop
# La CI lance dbt compile automatiquement sur la PR
```

### Règles de contribution

- **Ne jamais commiter directement sur `main` ou `develop`** — toujours passer par une PR
- **Toujours lancer `dbt test` avant d'ouvrir une PR** — la CI ne remplace pas les tests locaux
- **Tout nouveau modèle dbt** doit avoir une entrée de documentation et au moins un test dans `_models.yml`
- **Ne jamais commiter de credentials** — `.env`, `profiles.yml` avec des valeurs en dur, clés API
- **Conventional Commits** : `feat:`, `fix:`, `docs:`, `test:`, `chore:`

### Convention de nommage

| Type | Préfixe |
|---|---|
| Modèles staging | `stg_` |
| Tests singuliers | `assert_<modèle>_<règle>.sql` |
| Branches feature | `feat/` |
| Branches fix | `fix/` |
| Branches docs | `docs/` |

### Ajouter un nouveau modèle dbt

1. Créer le fichier SQL dans `dbt_nyc_taxi/models/marts/`
2. Déclarer le modèle dans `_models.yml` avec description et tests
3. Lancer `dbt build --select mon_modele` pour vérifier localement
4. Ouvrir une PR — la CI valide le SQL automatiquement

---

> Dépôt **public** — ne jamais y faire figurer de credentials, identifiants de compte ou données personnelles.
