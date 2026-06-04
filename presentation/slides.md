---
marp: true
theme: default
paginate: true
style: |
  section {
    font-family: 'Segoe UI', Arial, sans-serif;
  }
  section.lead h1 {
    font-size: 2.2rem;
  }
  code {
    font-size: 0.85em;
  }
---

<!-- _class: lead -->

# NYC Yellow Taxi — Pipeline de données
### Analyse des trajets 2024–2025

**Simplon — Promotion Data Engineering P1 2025**
Prénom A · Prénom B · Prénom C

---

## Sommaire

1. Contexte & objectifs
2. Architecture technique
3. Ingestion des données
4. Transformations dbt
5. Analyses & KPIs clés
6. Dashboard Streamlit
7. Difficultés & solutions
8. Conclusion

---

## Contexte & objectifs

- **Source** : NYC TLC Yellow Taxi — fichiers Parquet mensuels (2024 + début 2025)
- **Volume** : ~40–60 millions de trajets
- **Objectif** : construire un pipeline de données end-to-end, du fichier brut aux KPIs analytiques

**Périmètre du projet (3 jours, 3 personnes)**
- Ingestion automatisée vers Snowflake
- Nettoyage et transformations via dbt
- Analyses agrégées et dashboard interactif

---

## Architecture technique

```
NYC TLC (Parquet)
    │
    ▼
[Python ingestion]  →  Snowflake RAW.yellow_taxi_trips
                              │
                        dbt (staging)
                              │
                    STAGING.stg_yellow_trips
                        (nettoyage + colonnes calculées)
                              │
             ┌────────────────┼───────────────────┐
             ▼                ▼                   ▼
    FINAL.daily_summary  FINAL.zone_analysis  FINAL.hourly_patterns
```

**Stack** : Snowflake · dbt Core ≥1.8 · Python ≥3.10 · GitHub Actions · uv

---

## Ingestion

- Téléchargement des fichiers Parquet depuis l'API NYC TLC
- `PUT` vers un stage Snowflake interne
- `COPY INTO` avec `MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE`

**Défi : schémas hétérogènes 2024 vs 2025**
- 2025 introduit `cbd_congestion_fee` (taxe de congestion, effective le 5 janvier)
- Solution : colonnes manquantes chargées en `NULL` automatiquement

**Défi : types inconsistants entre mois**
- Ex. `passenger_count` : `DOUBLE` ou `INT64` selon le fichier
- Solution : types permissifs (`NUMBER`, `FLOAT`) dans la table `RAW`

---

## Transformations dbt — Staging

**Modèle** : `stg_yellow_trips` (vue)

Règles de nettoyage appliquées :
- `fare_amount >= 0` et `total_amount >= 0`
- `tpep_dropoff_datetime > tpep_pickup_datetime`
- `trip_distance > 0 AND trip_distance < 100`

Colonnes calculées :
| Colonne | Formule |
|---|---|
| `trip_duration_min` | `DATEDIFF('minute', pickup, dropoff)` |
| `avg_speed_mph` | `trip_distance / (duration / 60)` |
| `tip_rate` | `tip_amount / fare_amount` (carte uniquement) |
| `time_of_day` | night / morning / afternoon / evening |
| `distance_category` | short / medium / long |

---

## Transformations dbt — Marts

**`daily_summary`** (table)
> KPIs agrégés par jour : volume, revenus, durée et vitesse moyennes

**`zone_analysis`** (table)
> Performance par zone géographique TLC : zones les plus actives, revenus par zone, taux de pourboire

**`hourly_patterns`** (table)
> Patterns temporels heure par heure : pics de demande, heures de rush, corrélations météo/trafic

---

## KPIs & analyses clés

<!-- TODO : compléter avec les chiffres réels une fois develop finalisé -->

- Volume total de trajets analysés : **~XX millions**
- Durée moyenne d'un trajet : **XX min**
- Zone de départ la plus active : **XX**
- Heure de pointe dominante : **XXh**
- Taux de pourboire moyen (paiement carte) : **XX%**

---

## Dashboard Streamlit

<!-- TODO : ajouter captures d'écran du dashboard Snowflake une fois disponible -->

- Interface déployée sur **Snowflake Streamlit**
- Accès direct aux tables `FINAL` sans export
- Visualisations : …

---

## Difficultés & solutions

| Difficulté | Solution retenue |
|---|---|
| Schémas Parquet variables selon les mois | Types permissifs + `MATCH_BY_COLUMN_NAME` |
| `tip_amount` biaisé pour paiements cash | Filtre `payment_type = 1` avant calcul |
| Environnements dev/prod partagés sur un seul compte Snowflake | Schéma de dev par personne via `env_var` |
| Coût des requêtes sur 40M+ lignes | Warehouse XS + auto-suspend + `LIMIT` en exploration |

---

<!-- _class: lead -->

## Conclusion

- Pipeline end-to-end fonctionnel en **3 jours**
- Architecture **medallion** reproductible (RAW → STAGING → FINAL)
- Données de qualité validées par **tests dbt** à chaque couche
- Dashboard opérationnel sur Snowflake

**Ce qu'on ferait avec plus de temps**
- Orchestration Airflow / Dagster
- Prédiction de la demande (ML)
- Intégration données météo NYC

---

<!-- _class: lead -->

# Merci

Questions ?

**Repo** : github.com/Simplon-DE-P1-2025/NYC-Taxi-Drinking-Terror
