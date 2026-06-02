import argparse
import os
import sys
import tempfile

from utils import (
    build_source_url,
    copy_into_raw,
    download_parquet,
    get_snowflake_connection,
    is_already_loaded,
    remove_from_stage,
    resolve_last_available,
    source_filename,
    upload_to_stage,
)


def ingest_month(year: int, month: int) -> None:
    filename = source_filename(year, month)
    url = build_source_url(year, month)

    conn = get_snowflake_connection()
    try:
        if is_already_loaded(conn, year, month):
            print(f"[skip] {filename} already loaded — nothing to do")
            return

        print(f"[download] {url}")
        with tempfile.TemporaryDirectory() as tmpdir:
            local_path = os.path.join(tmpdir, filename)
            download_parquet(url, local_path)

            print(f"[upload] staging {filename}")
            upload_to_stage(conn, local_path)

        print(f"[copy] loading into RAW.yellow_taxi_trips")
        rows_loaded = copy_into_raw(conn, filename)

        print(f"[cleanup] removing {filename} from stage")
        remove_from_stage(conn, filename)

        print(f"[done] {filename}: {rows_loaded:,} rows loaded")
    finally:
        conn.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Ingest NYC Yellow Taxi Parquet data into Snowflake RAW schema"
    )
    parser.add_argument("--year", type=int, help="Year (e.g. 2024)")
    parser.add_argument("--month", type=int, help="Month (e.g. 1 or 01)")
    parser.add_argument(
        "--last-available",
        action="store_true",
        help="Auto-detect and ingest the latest published TLC month",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.last_available:
        if args.year or args.month:
            print("error: --last-available cannot be combined with --year/--month", file=sys.stderr)
            sys.exit(1)
        print("[resolve] detecting last available TLC month...")
        year, month = resolve_last_available()
        print(f"[resolve] target: {year}-{month:02d}")
    elif args.year and args.month:
        year, month = args.year, args.month
    else:
        print(
            "error: provide either --last-available or both --year and --month",
            file=sys.stderr,
        )
        sys.exit(1)

    ingest_month(year, month)


if __name__ == "__main__":
    main()
