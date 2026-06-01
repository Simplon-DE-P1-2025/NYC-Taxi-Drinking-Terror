-- =============================================================
-- 01_raw_table.sql
-- À exécuter après 00_setup.sql, avec le rôle NYC_TAXI_ROLE
-- Crée la table d'atterrissage des fichiers Parquet TLC
-- =============================================================

USE ROLE NYC_TAXI_ROLE;
USE WAREHOUSE NYC_TAXI_WH;
USE DATABASE NYC_TAXI_DB;
USE SCHEMA RAW;

-- -------------------------------------------------------------
-- Stage interne pour le chargement des fichiers Parquet
-- -------------------------------------------------------------
CREATE STAGE IF NOT EXISTS nyc_taxi_stage
  FILE_FORMAT = (TYPE = 'PARQUET')
  COMMENT = 'Stage interne pour les fichiers yellow_tripdata Parquet';

-- -------------------------------------------------------------
-- Table brute — types permissifs pour absorber les variations
-- entre fichiers 2024 et 2025 (schémas hétérogènes)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS yellow_taxi_trips (

    -- Identifiants de course
    vendorid                NUMBER,
    tpep_pickup_datetime    TIMESTAMP_NTZ,
    tpep_dropoff_datetime   TIMESTAMP_NTZ,

    -- Passagers & distance
    passenger_count         FLOAT,        -- parfois DOUBLE, parfois INT64 selon le mois
    trip_distance           FLOAT,

    -- Localisation TLC
    ratecodeid              FLOAT,
    store_and_fwd_flag      VARCHAR(1),
    pulocationid            NUMBER,
    dolocationid            NUMBER,

    -- Paiement
    payment_type            NUMBER,
    fare_amount             FLOAT,
    extra                   FLOAT,
    mta_tax                 FLOAT,
    tip_amount              FLOAT,        -- renseigné uniquement si payment_type = 1 (carte)
    tolls_amount            FLOAT,
    improvement_surcharge   FLOAT,
    total_amount            FLOAT,
    congestion_surcharge    FLOAT,
    airport_fee             FLOAT,

    -- Colonne 2025 uniquement (tarification congestion, entrée en vigueur 05/01/2025)
    -- NULL pour tous les fichiers 2024 grâce à MATCH_BY_COLUMN_NAME
    cbd_congestion_fee      FLOAT,

    -- Colonnes de traçabilité du chargement
    _loaded_at              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    _source_file            VARCHAR

)
COMMENT = 'Données brutes TLC Yellow Taxi 2024-2025, chargées via COPY INTO';
