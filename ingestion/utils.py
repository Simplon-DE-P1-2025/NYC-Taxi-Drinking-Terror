import os
import requests
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import snowflake.connector
from dotenv import load_dotenv

load_dotenv()

TLC_BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"


def get_snowflake_connection() -> snowflake.connector.SnowflakeConnection:
    account = os.environ["SNOWFLAKE_ACCOUNT"].removesuffix(".snowflakecomputing.com")
    return snowflake.connector.connect(
        account=account,
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role="NYC_TAXI_ROLE",
        warehouse="NYC_TAXI_WH",
        database="NYC_TAXI_DB",
    )


def build_source_url(year: int, month: int) -> str:
    return f"{TLC_BASE_URL}/yellow_tripdata_{year:04d}-{month:02d}.parquet"


def source_filename(year: int, month: int) -> str:
    return f"yellow_tripdata_{year:04d}-{month:02d}.parquet"


def is_already_loaded(
    conn: snowflake.connector.SnowflakeConnection, year: int, month: int
) -> bool:
    filename = source_filename(year, month)
    cur = conn.cursor()
    cur.execute(
        "SELECT COUNT(1) FROM NYC_TAXI_DB.RAW.yellow_taxi_trips "
        "WHERE _source_file ILIKE %s LIMIT 1",
        (f"%{filename}%",),
    )
    return cur.fetchone()[0] > 0


def resolve_last_available(lookback_months: int = 6) -> tuple[int, int]:
    """Find the most recent month for which TLC data is published (typically ~2-month lag)."""
    now = datetime.now(timezone.utc)
    year, month = now.year, now.month - 2
    if month <= 0:
        year -= 1
        month += 12

    for _ in range(lookback_months):
        url = build_source_url(year, month)
        try:
            resp = requests.head(url, timeout=10, allow_redirects=True)
            if resp.status_code == 200:
                return year, month
        except requests.RequestException:
            pass
        month -= 1
        if month <= 0:
            year -= 1
            month += 12

    raise RuntimeError(f"No available TLC file found in the last {lookback_months} months")


def download_parquet(url: str, dest_path: str) -> None:
    resp = requests.get(url, stream=True, timeout=(10, 300))
    if resp.status_code == 404:
        raise FileNotFoundError(f"TLC data file not found: {url}")
    resp.raise_for_status()
    with open(dest_path, "wb") as f:
        for chunk in resp.iter_content(chunk_size=8 * 1024 * 1024):
            f.write(chunk)


def upload_to_stage(
    conn: snowflake.connector.SnowflakeConnection, local_path: str
) -> None:
    file_uri = Path(local_path).as_uri()
    conn.cursor().execute(
        f"PUT '{file_uri}' @NYC_TAXI_DB.RAW.nyc_taxi_stage AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
    )


def copy_into_raw(
    conn: snowflake.connector.SnowflakeConnection, filename: str
) -> int:
    """Load staged Parquet into RAW table.

    MATCH_BY_COLUMN_NAME handles schema differences across months (e.g. cbd_congestion_fee
    absent in 2024 files → NULL) and future new columns (unknown columns → ignored).
    INCLUDE_METADATA populates _source_file and _loaded_at without manual UPDATE.
    """
    cur = conn.cursor()
    cur.execute(f"""
        COPY INTO NYC_TAXI_DB.RAW.yellow_taxi_trips
        FROM @NYC_TAXI_DB.RAW.nyc_taxi_stage/{filename}
        FILE_FORMAT = (TYPE = PARQUET USE_LOGICAL_TYPE = TRUE)
        MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
        INCLUDE_METADATA = (
            _source_file = METADATA$FILENAME,
            _loaded_at = METADATA$START_SCAN_TIME
        )
        PURGE = FALSE
    """)
    rows = cur.fetchall()
    # COPY INTO result: (file, status, rows_parsed, rows_loaded, ...)
    return sum(int(row[3]) for row in rows if row[1] in ("LOADED", "PARTIALLY_LOADED"))


def remove_from_stage(
    conn: snowflake.connector.SnowflakeConnection, filename: str
) -> None:
    conn.cursor().execute(f"REMOVE @NYC_TAXI_DB.RAW.nyc_taxi_stage/{filename}")
