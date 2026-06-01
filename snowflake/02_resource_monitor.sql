-- =============================================================
-- 02_resource_monitor.sql
-- À exécuter EN PREMIER avec le rôle ACCOUNTADMIN
-- Protège les crédits du compte d'essai ($400)
-- =============================================================

USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE RESOURCE MONITOR nyc_taxi_monitor
  WITH
    CREDIT_QUOTA = 20              -- alerte à 20 crédits/mois (~$40, soit 10% du budget)
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
      ON 50  PERCENT DO NOTIFY        -- email à 50%
      ON 80  PERCENT DO NOTIFY        -- email à 80%
      ON 100 PERCENT DO SUSPEND       -- suspend le warehouse à 100%
      ON 110 PERCENT DO SUSPEND_IMMEDIATE;  -- coupe immédiatement à 110%

-- Attacher le monitor au warehouse (créé dans 00_setup.sql)
ALTER WAREHOUSE NYC_TAXI_WH SET RESOURCE_MONITOR = nyc_taxi_monitor;
