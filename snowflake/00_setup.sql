-- =============================================================
-- 00_setup.sql
-- À exécuter UNE SEULE FOIS avec le rôle ACCOUNTADMIN
-- Crée l'ensemble de l'infrastructure Snowflake du projet
-- =============================================================

USE ROLE ACCOUNTADMIN;

-- -------------------------------------------------------------
-- Warehouse
-- -------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS NYC_TAXI_WH
  WITH
    WAREHOUSE_SIZE   = 'X-SMALL',
    AUTO_SUSPEND     = 60,          -- suspend après 60s d'inactivité
    AUTO_RESUME      = TRUE,
    INITIALLY_SUSPENDED = TRUE,
    COMMENT          = 'Warehouse principal NYC Taxi project';

-- Le resource monitor est créé dans 02_resource_monitor.sql,
-- qui attache également le monitor au warehouse.

-- -------------------------------------------------------------
-- Base de données et schémas (architecture medallion)
-- -------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS NYC_TAXI_DB;

CREATE SCHEMA IF NOT EXISTS NYC_TAXI_DB.RAW;
CREATE SCHEMA IF NOT EXISTS NYC_TAXI_DB.STAGING;
CREATE SCHEMA IF NOT EXISTS NYC_TAXI_DB.FINAL;

-- -------------------------------------------------------------
-- Rôle projet
-- -------------------------------------------------------------
CREATE ROLE IF NOT EXISTS NYC_TAXI_ROLE;

-- Droits sur le warehouse
GRANT USAGE ON WAREHOUSE NYC_TAXI_WH TO ROLE NYC_TAXI_ROLE;

-- Droits sur la base et les schémas
GRANT USAGE ON DATABASE NYC_TAXI_DB TO ROLE NYC_TAXI_ROLE;

GRANT USAGE, CREATE TABLE, CREATE VIEW, CREATE STAGE
  ON SCHEMA NYC_TAXI_DB.RAW     TO ROLE NYC_TAXI_ROLE;
GRANT USAGE, CREATE TABLE, CREATE VIEW
  ON SCHEMA NYC_TAXI_DB.STAGING TO ROLE NYC_TAXI_ROLE;
GRANT USAGE, CREATE TABLE, CREATE VIEW
  ON SCHEMA NYC_TAXI_DB.FINAL   TO ROLE NYC_TAXI_ROLE;

-- Droits futurs (pour les objets créés plus tard par dbt)
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA NYC_TAXI_DB.RAW     TO ROLE NYC_TAXI_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA NYC_TAXI_DB.STAGING TO ROLE NYC_TAXI_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA NYC_TAXI_DB.FINAL   TO ROLE NYC_TAXI_ROLE;
GRANT ALL PRIVILEGES ON FUTURE VIEWS  IN SCHEMA NYC_TAXI_DB.STAGING TO ROLE NYC_TAXI_ROLE;
GRANT ALL PRIVILEGES ON FUTURE VIEWS  IN SCHEMA NYC_TAXI_DB.FINAL   TO ROLE NYC_TAXI_ROLE;

-- -------------------------------------------------------------
-- Users membres de l'équipe
-- Remplacer <USERNAME_X> et <PASSWORD_X> avant d'exécuter
-- Les mots de passe ne doivent jamais être committés dans le repo
-- -------------------------------------------------------------
CREATE USER IF NOT EXISTS "SIMPLON"
  PASSWORD            = '<PASSWORD_A>'
  DEFAULT_ROLE        = NYC_TAXI_ROLE
  DEFAULT_WAREHOUSE   = NYC_TAXI_WH
  DEFAULT_NAMESPACE   = NYC_TAXI_DB
  MUST_CHANGE_PASSWORD = FALSE;

CREATE USER IF NOT EXISTS "MATTHIEU.NAVARRO"
  PASSWORD            = '<PASSWORD_B>'
  DEFAULT_ROLE        = NYC_TAXI_ROLE
  DEFAULT_WAREHOUSE   = NYC_TAXI_WH
  DEFAULT_NAMESPACE   = NYC_TAXI_DB
  MUST_CHANGE_PASSWORD = FALSE;

CREATE USER IF NOT EXISTS "LOUNESABDOU"
  PASSWORD            = '<PASSWORD_C>'
  DEFAULT_ROLE        = NYC_TAXI_ROLE
  DEFAULT_WAREHOUSE   = NYC_TAXI_WH
  DEFAULT_NAMESPACE   = NYC_TAXI_DB
  MUST_CHANGE_PASSWORD = FALSE;

-- User dédié GitHub Actions (pas de connexion UI nécessaire)
CREATE USER IF NOT EXISTS "nyc_taxi_ci"
  PASSWORD            = '<PASSWORD_CI>'
  DEFAULT_ROLE        = NYC_TAXI_ROLE
  DEFAULT_WAREHOUSE   = NYC_TAXI_WH
  DEFAULT_NAMESPACE   = NYC_TAXI_DB
  MUST_CHANGE_PASSWORD = FALSE
  COMMENT             = 'Service account for GitHub Actions CI/CD';

-- Attribuer le rôle à tous les users
GRANT ROLE NYC_TAXI_ROLE TO USER "SIMPLON";
GRANT ROLE NYC_TAXI_ROLE TO USER "MATTHIEU.NAVARRO";
GRANT ROLE NYC_TAXI_ROLE TO USER "LOUNESABDOU";
GRANT ROLE NYC_TAXI_ROLE TO USER "nyc_taxi_ci";
