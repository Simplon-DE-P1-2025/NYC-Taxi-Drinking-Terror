# Ingestion — NYC Yellow Taxi → Snowflake RAW

Ce module télécharge les fichiers Parquet mensuels publiés par la NYC TLC et les charge dans la table `NYC_TAXI_DB.RAW.yellow_taxi_trips`.

## Fichiers

| Fichier | Rôle |
|---|---|
| `load_to_raw.py` | Point d'entrée CLI — orchestre le flux pour un mois donné |
| `utils.py` | Fonctions utilitaires réutilisables (connexion, téléchargement, Snowflake) |

---

## Utilisation

```bash
# Mois explicite
uv run python ingestion/load_to_raw.py --year 2024 --month 01

# Dernier mois disponible (pipeline automatisé)
uv run python ingestion/load_to_raw.py --last-available

# Backfill en boucle (exemple : toute l'année 2024)
for month in 01 02 03 04 05 06 07 08 09 10 11 12; do
  uv run python ingestion/load_to_raw.py --year 2024 --month $month
done
```

Variables d'environnement requises (via `.env` en local, secrets GitHub Actions en CI) :

```
SNOWFLAKE_ACCOUNT=...
SNOWFLAKE_USER=...
SNOWFLAKE_PASSWORD=...
```

---

## Flux d'exécution

```
load_to_raw.py
│
├── parse_args()
│     Lit les arguments CLI : --year/--month ou --last-available
│
├── [si --last-available] resolve_last_available()   ← utils.py
│     Envoie des HEAD requests depuis current_month-2
│     jusqu'à trouver un fichier disponible (max 6 mois en arrière)
│     Retourne (year, month)
│
└── ingest_month(year, month)
      │
      ├── 1. source_filename(year, month)             ← utils.py
      │         "yellow_tripdata_2024-01.parquet"
      │
      ├── 2. build_source_url(year, month)            ← utils.py
      │         "https://d37ci6vzurychx.../yellow_tripdata_2024-01.parquet"
      │
      ├── 3. get_snowflake_connection()               ← utils.py
      │         Connexion via variables d'environnement
      │         Rôle : NYC_TAXI_ROLE / WH : NYC_TAXI_WH / DB : NYC_TAXI_DB
      │
      ├── 4. is_already_loaded(conn, year, month)     ← utils.py
      │         SELECT COUNT(1) WHERE _source_file ILIKE '%filename%'
      │         → si > 0 : skip immédiat (idempotence)
      │
      ├── 5. download_parquet(url, local_path)        ← utils.py
      │         Téléchargement streaming en chunks de 8 MB
      │         Fichier écrit dans un répertoire temporaire
      │         Lève FileNotFoundError si HTTP 404
      │
      ├── 6. upload_to_stage(conn, local_path)        ← utils.py
      │         PUT vers @NYC_TAXI_DB.RAW.nyc_taxi_stage
      │         AUTO_COMPRESS=FALSE (conserve l'extension .parquet)
      │         OVERWRITE=TRUE (sûr en cas de re-run après échec)
      │         ↳ le répertoire temporaire est supprimé ici
      │
      ├── 7. copy_into_raw(conn, filename)            ← utils.py
      │         COPY INTO RAW.yellow_taxi_trips
      │         MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
      │         INCLUDE_METADATA (_source_file, _loaded_at)
      │         Retourne le nombre de lignes chargées
      │
      └── 8. remove_from_stage(conn, filename)        ← utils.py
                REMOVE @nyc_taxi_stage/filename
                Nettoyage du stage après chargement réussi
```

---

## Détail des fonctions (`utils.py`)

### Connexion

**`get_snowflake_connection()`**
Ouvre une connexion Snowflake à partir des variables d'environnement. Toujours utilisée dans un bloc `try/finally` pour garantir la fermeture avec `conn.close()`.

---

### Construction des identifiants

**`source_filename(year, month) → str`**
Retourne le nom du fichier Parquet TLC : `yellow_tripdata_YYYY-MM.parquet`. Utilisé comme identifiant stable dans `_source_file` et pour référencer le fichier dans le stage Snowflake.

**`build_source_url(year, month) → str`**
Construit l'URL de téléchargement à partir de `TLC_BASE_URL` et des paramètres année/mois. Exemple : `https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet`.

---

### Idempotence

**`is_already_loaded(conn, year, month) → bool`**
Interroge `RAW.yellow_taxi_trips` pour vérifier si des lignes existent déjà avec `_source_file` contenant ce nom de fichier. Si oui, tout le reste du flux est court-circuité — aucun téléchargement, aucune écriture Snowflake.

Cela rend le script sûr à relancer en cas d'interruption ou d'erreur réseau sans créer de doublons.

---

### Détection du dernier mois disponible

**`resolve_last_available(lookback_months=6) → tuple[int, int]`**
La TLC publie ses données avec environ 2 mois de décalage. Cette fonction part de `current_month - 2` et envoie des requêtes HTTP HEAD (légères, sans télécharger le fichier) jusqu'à recevoir un `200 OK`. Remonte jusqu'à 6 mois en arrière avant de lever une `RuntimeError`.

Utilisée exclusivement pour le run automatisé (`--last-available`) déclenché par le cron GitHub Actions.

---

### Téléchargement

**`download_parquet(url, dest_path) → None`**
Télécharge le fichier Parquet en streaming par chunks de 8 MB vers un fichier local temporaire. Le streaming évite de charger un fichier de 200–500 MB entièrement en mémoire. Le fichier temporaire est créé par `ingest_month` dans un `TemporaryDirectory` supprimé automatiquement après le PUT.

---

### Stage Snowflake

**`upload_to_stage(conn, local_path) → None`**
Envoie le fichier local vers le stage interne Snowflake `@NYC_TAXI_DB.RAW.nyc_taxi_stage` via la commande `PUT`. Le stage est une zone tampon intermédiaire obligatoire : Snowflake ne peut pas charger directement depuis une URL HTTP externe, il faut passer par un stage.

Options importantes :
- `AUTO_COMPRESS=FALSE` : conserve l'extension `.parquet` telle quelle (sinon Snowflake ajouterait `.gz` et le `COPY INTO` ne trouverait plus le fichier)
- `OVERWRITE=TRUE` : permet de re-PUT sans erreur si le fichier est déjà présent dans le stage suite à un échec partiel

**`remove_from_stage(conn, filename) → None`**
Supprime le fichier du stage après un `COPY INTO` réussi. Le stage est un espace de stockage temporaire facturé — le nettoyage est systématique.

---

### Chargement en table

**`copy_into_raw(conn, filename) → int`**
Exécute le `COPY INTO` depuis le stage vers `RAW.yellow_taxi_trips`. Retourne le nombre de lignes chargées.

Deux options clés gèrent la compatibilité de schéma :

**`MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE`**
Snowflake mappe les colonnes du Parquet vers les colonnes de la table par leur nom (insensible à la casse), au lieu de les mapper par position. Conséquences :
- Une colonne absente du Parquet (ex: `cbd_congestion_fee` dans les fichiers 2024) est chargée à `NULL`
- Une colonne présente dans le Parquet mais absente de la table (ex: future nouvelle colonne TLC) est ignorée sans erreur

**`INCLUDE_METADATA`**
Peuple automatiquement les colonnes de métadonnées qui n'existent pas dans le Parquet :
- `_source_file` ← `METADATA$FILENAME` : nom du fichier dans le stage
- `_loaded_at` ← `METADATA$START_SCAN_TIME` : horodatage du chargement

Sans `INCLUDE_METADATA`, ces colonnes seraient `NULL` et l'idempotence ne fonctionnerait pas.

---

## Gestion des schémas hétérogènes

| Situation | Comportement |
|---|---|
| Fichier 2024 sans `cbd_congestion_fee` | Colonne chargée à `NULL` |
| Fichier 2025 avec `cbd_congestion_fee` | Colonne renseignée normalement |
| Futur fichier avec une nouvelle colonne inconnue | Colonne ignorée, chargement sans erreur |
| Futur fichier sans une colonne existante dans RAW | Colonne chargée à `NULL` |
