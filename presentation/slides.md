---
marp: true
theme: default
paginate: true
html: true
style: |
  /* ── Palette ─────────────────────────────────────────────── */
  :root {
    --yellow:  #F7C800;
    --black:   #1C1C1C;
    --gray:    #F5F5F5;
    --border:  #E0E0E0;
  }

  /* ── Slide de base ───────────────────────────────────────── */
  section {
    font-family: 'Segoe UI', Arial, sans-serif;
    font-size: 21px;
    color: var(--black);
    background: #FFFFFF;
    padding: 55px 64px 48px;
    background-image: repeating-linear-gradient(
      90deg,
      var(--yellow) 0px,  var(--yellow) 14px,
      var(--black)  14px, var(--black)  28px
    );
    background-size: 100% 12px;
    background-repeat: no-repeat;
    background-position: top left;
  }

  h1 {
    font-size: 1.5rem;
    color: var(--black);
    border-bottom: 3px solid var(--yellow);
    padding-bottom: 8px;
    margin: 0 0 22px 0;
  }

  h2 { font-size: 1.15rem; margin: 18px 0 6px; }
  h3 { font-size: 1rem; color: #555; margin: 12px 0 4px; }

  ul, ol { line-height: 1.75; margin: 0; padding-left: 24px; }
  li { margin-bottom: 3px; }

  strong { color: var(--black); }

  code {
    background: #F0F0F0;
    border-radius: 3px;
    padding: 1px 5px;
    font-size: 0.83em;
  }

  pre {
    background: #1C1C1C !important;
    border-left: 4px solid var(--yellow);
    border-radius: 4px;
    padding: 14px 18px !important;
    font-size: 0.76em;
    line-height: 1.5;
  }

  pre code {
    background: transparent !important;
    color: #E8E8E8;
    padding: 0;
    font-size: 1em;
  }

  table { width: 100%; border-collapse: collapse; font-size: 0.82em; }
  th {
    background: var(--yellow);
    color: var(--black);
    padding: 8px 12px;
    text-align: left;
    font-weight: 700;
  }
  td { padding: 7px 12px; border-bottom: 1px solid var(--border); }
  tr:nth-child(even) td { background: var(--gray); }

  blockquote {
    background: #FFFBE6;
    border-left: 4px solid var(--yellow);
    padding: 10px 16px;
    margin: 14px 0;
    border-radius: 0 4px 4px 0;
    font-size: 0.88em;
    color: #555;
  }

  section::after { font-size: 13px; color: #AAAAAA; }

  /* ── Slide titre (lead) ──────────────────────────────────── */
  section.lead {
    background: var(--black);
    background-image:
      repeating-linear-gradient(
        90deg,
        var(--yellow) 0px,  var(--yellow) 20px,
        var(--black)  20px, var(--black)  40px
      ),
      repeating-linear-gradient(
        90deg,
        var(--yellow) 0px,  var(--yellow) 20px,
        var(--black)  20px, var(--black)  40px
      );
    background-size: 100% 18px, 100% 18px;
    background-position: top, bottom;
    background-repeat: no-repeat;
    color: var(--yellow);
    text-align: center;
    justify-content: center;
    padding: 60px 80px;
  }

  section.lead h1 {
    color: var(--yellow);
    border-bottom-color: var(--yellow);
    font-size: 2.1rem;
    margin-bottom: 16px;
  }

  section.lead h2 { color: #CCCCCC; font-size: 1.1rem; margin: 6px 0; font-weight: 400; }
  section.lead p   { color: #CCCCCC; margin: 6px 0; }
  section.lead strong { color: var(--yellow); }
  section.lead::after { color: transparent; }

  /* ── Carte lien dashboard ────────────────────────────────── */
  .link-card {
    background: var(--black);
    border: 2px solid var(--yellow);
    border-radius: 8px;
    padding: 22px 28px;
    margin: 28px 0 0;
    text-align: center;
  }

  .link-card .link-label {
    display: block;
    font-size: 0.78em;
    color: #AAAAAA;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    margin-bottom: 10px;
  }

  .link-card a {
    color: var(--yellow);
    font-family: 'Courier New', monospace;
    font-size: 0.72em;
    text-decoration: none;
    word-break: break-all;
    line-height: 1.5;
  }

  .link-card a::before {
    content: '→ ';
    font-style: normal;
  }
---

<!-- _class: lead -->

# NYC Yellow Taxi
## Pipeline de données end-to-end

**2024 – 2025 · ~70 millions de trajets**

Ashley · Matthieu · Lounes
*Simplon — Data Engineering P1 2025*

---

# Contexte & objectifs

La **NYC TLC** publie chaque mois les données de tous les Yellow Taxis (~200–500 MB/mois, format Parquet).

**Objectif : un pipeline end-to-end en 5 jours**

1. **Ingérer** les fichiers Parquet bruts → Snowflake
2. **Nettoyer & enrichir** via dbt (nettoyage, colonnes calculées)
3. **Agréger** en tables analytiques (KPIs jour / zone / heure)
4. **Automatiser** via GitHub Actions — sans Airflow, sans Docker

---

# Architecture — Multi-Stage

```
NYC TLC  (Parquet mensuel, ~300 MB)
    │
    ▼  Python · PUT stage · COPY INTO
RAW.yellow_taxi_trips          ← types permissifs, toutes colonnes
    │
    ▼  dbt staging (vue)
STAGING.stg_yellow_trips       ← nettoyage + 15 colonnes calculées
    │
    ├──────────────────┬──────────────────┐
    ▼                  ▼                  ▼
FINAL.daily_summary  FINAL.zone_analysis  FINAL.hourly_patterns
KPIs jour/borough    Analyse zone TLC     Patterns par heure
```

> Architecture **RAW → STAGING → FINAL** — chaque couche a un rôle clair et testable indépendamment.

---

# Stack technique

| Outil | Rôle | Pourquoi ce choix |
|---|---|---|
| **Snowflake** | Data Warehouse | Chargement Parquet natif via stages, isolation compute/storage, compatibilité dbt |
| **dbt Core** | Transformations SQL | Lineage auto, tests intégrés, open-source sans serveur |
| **Python + uv** | Ingestion | `uv run --env-file` — reproductible sur tous les OS sans activation manuelle |
| **GitHub Actions** | Orchestration | Déclencheurs push/merge + cron mensuel, secrets natifs |

---

# Ingestion

**Flux pour chaque mois :**

```
1. HEAD request → détecter le dernier mois disponible (décalage ~2 mois TLC)
2. Téléchargement streaming 8 MB/chunk → répertoire temporaire
3. PUT → stage Snowflake interne
4. COPY INTO RAW.yellow_taxi_trips
5. REMOVE du stage (facturation au stockage)
```

**Idempotence** : vérification `_source_file` avant téléchargement → aucun doublon en cas de re-run.

**Défi — schémas hétérogènes 2024 vs 2025**
`cbd_congestion_fee` apparaît en janvier 2025 (taxe de congestion NYC).
→ `MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE` : colonnes manquantes → `NULL`, inconnues → ignorées.

---

# Transformations dbt

**`stg_yellow_trips`** (vue) — filtres + enrichissement

| Filtre | Règle |
|---|---|
| Période | 2024-01-01 → 2025-12-31 |
| Distance | > 0 mi et ≤ P99 (~35 km) |
| Durée | > 0 et ≤ P99 (~75 min) |
| Montants | `fare_amount ≥ 0`, `total_amount ≥ 0` |

Colonnes clés : `trip_distance_km`, `speed_kmh`, `tip_percentage`\*, `is_rush_hour`, `pickup_borough`, `is_airport_trip`

> **\*** `tip_percentage` : paiement carte uniquement (`payment_type = 1`). Le cash ne remonte pas `tip_amount` — l'inclure biaiserait le taux de ~22 % vers ~8 %.

---

# Marts analytiques

**`daily_summary`** — KPIs agrégés par **jour × borough**
Volume de trajets, revenus totaux, durée et vitesse moyennes, taux de pourboire carte

**`zone_analysis`** — Performance par **zone TLC** (265 zones)
Zones les plus actives au départ/arrivée, revenus et pourboires moyens par zone

**`hourly_patterns`** — Patterns par **heure de la journée**
Volume, vitesse, revenus, identification des heures de pointe (7h–9h, 16h–19h)

---

# Qualité des données

**Tests génériques** sur chaque modèle : `not_null`, `unique`, `accepted_values`, `relationships`

**Tests métier singuliers** (SQL → 0 ligne = OK) :

| Test | Règle vérifiée |
|---|---|
| `assert_no_negative_amounts` | Aucun montant négatif après staging |
| `assert_rush_hour_above_average_trips` | Heures de pointe > moyenne en semaine |
| `assert_zone_activity_coherent` | `total_activity ≥ trips_as_origin` (invariant arithmétique) |
| `assert_manhattan_busiest_borough` | Manhattan = 1er borough chaque mois (~70 % du volume TLC) |
| `assert_weekday_trips_exceed_weekend` | Semaine > week-end chaque mois |
| `assert_manhattan_card_tips_positive` | Taux pourboire carte Manhattan ≥ 15 % |

---

# CI/CD — GitHub Actions

```
PR ouverte         →  dbt compile         validation SQL, 0 écriture Snowflake
Merge → develop    →  dbt build preprod   schéma DBT_PREPROD
Merge → main       →  dbt build prod      STAGING + FINAL
Cron le 15/mois    →  ingestion + prod    pipeline mensuel automatisé
```

**Isolation dev/prod** : macro `generate_schema_name` → chaque dev écrit dans `DBT_<PRENOM>`, prod dans `STAGING`/`FINAL`. Aucune collision sur le compte partagé.

**Secrets** : `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD` — GitHub Actions Secrets, jamais dans le code.

---

# Difficultés rencontrées

| Problème | Solution |
|---|---|
| Schémas Parquet différents 2024/2025 (`cbd_congestion_fee`) | `MATCH_BY_COLUMN_NAME` + types permissifs dans RAW |
| Types inconsistants entre mois (`INT64` vs `DOUBLE`) | Types permissifs dans RAW, rigueur imposée en staging uniquement |
| 3 devs sur 1 compte Snowflake partagé | Macro `generate_schema_name` → schéma isolé `DBT_<PRENOM>` par personne |
| Biais `tip_amount` sur paiements cash | Filtre `payment_type = 1` avant tout calcul du taux |
| Coût : 40–60M lignes sur compte d'essai ($400 crédits) | Warehouse XS + auto-suspend + resource monitor + `LIMIT` systématique |

---

# Dashboard Streamlit

- Interface déployée sur **Snowflake Streamlit** — accès direct aux tables `FINAL`
- Pas d'export de données : le compute reste dans Snowflake
- Visualisations interactives : volume par zone, patterns temporels, KPIs financiers

<div class="link-card">
  <span class="link-label">Dashboard interactif</span>
  <a href="https://app.snowflake.com/streamlit/eu-central-2.aws/ph28527/#/apps/3oufchb672ktihdcgkvx">app.snowflake.com/streamlit/eu-central-2.aws/ph28527/#/apps/3oufchb672ktihdcgkvx</a>
</div>

---

# Pistes d'amélioration

- **Orchestration** — Dagster ou Prefect pour le retry automatique et l'observabilité du DAG
- **Données météo** — API Open-Meteo (gratuite) pour quantifier l'impact pluie/neige sur la demande
- **Staging incrémental** — matérialisation `incremental` sur `pickup_date` pour réduire les coûts de scan
- **Prédiction de la demande** — modèle Prophet/LSTM sur 12+ mois pour anticiper le volume par zone
- **Tests de volume** — alertes si un jour < 50k trajets (détection d'ingestion incomplète)

---

<!-- _class: lead -->

# Merci

**Ce qu'on retient**
Pipeline end-to-end fonctionnel · Architecture Multi-Stage reproductible · Qualité validée à chaque couche

*Questions ?*

`github.com/Simplon-DE-P1-2025/NYC-Taxi-Drinking-Terror`
