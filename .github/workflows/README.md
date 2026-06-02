# Workflows GitHub Actions

## Vue d'ensemble

```
PR ouverte    → dbt_ci.yml      → dbt compile        (validation SQL, pas d'écriture Snowflake)
Merge develop → dbt_preprod.yml → dbt build preprod   (schéma DBT_PREPROD)
Merge main    → dbt_deploy.yml  → dbt build prod      (STAGING / FINAL)
Manuel/cron   → pipeline.yml    → ingestion + prod
```

## Détail des workflows

### `dbt_ci.yml` — Validation sur PR

Se déclenche sur chaque PR vers `develop` ou `main`.

Lance `dbt compile` : vérifie que le SQL est valide et que toutes les références (`ref`, `source`, Jinja) se résolvent correctement. **Aucune connexion Snowflake, aucun schéma créé.**

### `dbt_preprod.yml` — Build pré-production

Se déclenche au merge sur `develop`.

Lance `dbt build --target preprod` : matérialise tous les modèles et exécute les tests dans le schéma `DBT_PREPROD`. C'est le vrai filet de sécurité avant la prod.

### `dbt_deploy.yml` — Déploiement production

Se déclenche au merge sur `main` si des fichiers `dbt_nyc_taxi/**` ont changé.

Lance `dbt build --target prod` : déploie dans les schémas `STAGING` et `FINAL`. Aucune action manuelle requise.

### `pipeline.yml` — Ingestion mensuelle

Se déclenche le 15 de chaque mois (ou manuellement via `workflow_dispatch`).

Télécharge le fichier Parquet TLC du mois, le charge dans `RAW`, puis lance `dbt build --target prod`. À utiliser pour ingérer un mois spécifique : Actions → Pipeline ingestion + dbt → Run workflow.

## Cibles dbt

| Cible | Schéma | Utilisé par |
|---|---|---|
| `dev` | `DBT_<PRENOM>` | Chaque dev en local |
| `preprod` | `DBT_PREPROD` | GitHub Actions sur `develop` |
| `prod` | `STAGING` / `FINAL` | GitHub Actions sur `main` et pipeline mensuel |

## Configuration locale

Copier `.env.example` en `.env` et renseigner ses credentials. Le `profiles.yml` est déjà dans `dbt_nyc_taxi/` — rien d'autre à faire.

```bash
cp .env.example .env
# remplir SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD, DBT_USER
```
