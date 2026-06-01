import os

import snowflake.connector
from dotenv import load_dotenv

load_dotenv()


def get_snowflake_connection() -> snowflake.connector.SnowflakeConnection:
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role="NYC_TAXI_ROLE",
        warehouse="NYC_TAXI_WH",
        database="NYC_TAXI_DB",
    )
