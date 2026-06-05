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

C'est tout. Aucun fichier `~/.dbt/profiles.yml` à créer manuellement.

## Commandes courantes

Toutes les commandes se lancent depuis ce dossier (`dbt_nyc_taxi/`).  
Le flag `--env-file ../.env` charge les variables Snowflake depuis la racine du projet — pas besoin de `source` manuel :

```bash
uv run --env-file ../.env dbt deps          # installe les packages (à faire une fois)
uv run --env-file ../.env dbt seed          # charge taxi_zone_lookup.csv dans Snowflake
uv run --env-file ../.env dbt run           # exécute les modèles
uv run --env-file ../.env dbt test          # lance les tests qualité
uv run --env-file ../.env dbt build         # run + test en une seule commande
uv run --env-file ../.env dbt compile       # vérifie le SQL sans toucher Snowflake
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
uv run --env-file ../.env dbt run --target dev      # par défaut
uv run --env-file ../.env dbt run --target preprod
uv run --env-file ../.env dbt run --target prod     # ne jamais lancer en local
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

## Modèles

### `stg_yellow_trips` (staging)

Vue de nettoyage et d'enrichissement sur `RAW.yellow_taxi_trips`.

**Filtres appliqués**
- Période : `2024-01-01` → `2025-12-31`
- Durée positive (`dropoff > pickup`)
- Distance > 0 mi et ≤ 35 km (seuil P99 ~ 32 km)
- Durée ≤ 75 min (seuil P99 ~ 71 min)
- `fare_amount >= 0` et `total_amount >= 0`

**Colonnes calculées**
| Colonne | Description |
|---|---|
| `trip_id` | Surrogate key (dbt_utils) |
| `trip_distance_km` | Distance convertie en km |
| `trip_duration_minutes` | Durée en minutes |
| `speed_kmh` | Vitesse moyenne en km/h |
| `fare_per_km` | Tarif par km |
| `tip_percentage` | Taux de pourboire en % (NULL si paiement non-carte) |
| `is_weekend` / `is_rush_hour` | Flags temporels |
| `time_of_day` | Tranche horaire (6 buckets) |
| `pickup_borough` / `dropoff_borough` | Enrichissement zones TLC |
| `is_airport_trip` | TRUE si course aéroport |
| `distance_category` / `duration_category` / `fare_category` / `tip_category` / `party_size` / `speed_category` | Catégories analytiques |

**Tests generics** : `trip_id` (not_null + unique), `vendor_id`, `pickup_datetime`, `dropoff_datetime`, `payment_type_id` (accepted_values 1-6), `fare_amount`, `total_amount`, `trip_distance_km`, `trip_duration_minutes`, `_loaded_at`, `_source_file`.

**Test singulier** : `tests/assert_no_negative_amounts.sql` — vérifie qu'aucune ligne n'a `fare_amount < 0` ou `total_amount < 0`.

**Seed requis** : `taxi_zone_lookup` (265 zones TLC, chargé via `dbt seed`).

## profiles.yml

Le fichier `profiles.yml` est commité dans ce dossier. Il ne contient aucune valeur sensible — tout passe par `env_var()` qui lit depuis `.env`. Le fichier `.env` lui-même n'est jamais commité.
