-- P99 thresholds computed from raw data: distance <= 35 km, duration <= 75 min

WITH source AS (
    SELECT * FROM {{ source('raw', 'yellow_taxi_trips') }}
),

zones AS (
    SELECT * FROM {{ ref('taxi_zone_lookup') }}
),

renamed AS (
    SELECT
        -- surrogate key
        {{ dbt_utils.generate_surrogate_key([
            'src.vendorid',
            'src.tpep_pickup_datetime',
            'src.tpep_dropoff_datetime',
            'src.pulocationid',
            'src.dolocationid',
            'src.fare_amount'
        ]) }} AS trip_id,

        -- identifiers
        src.vendorid                     AS vendor_id,
        src.pulocationid                 AS pickup_location_id,
        src.dolocationid                 AS dropoff_location_id,
        src.ratecodeid::INT              AS rate_code_id,
        src.payment_type                 AS payment_type_id,

        -- timestamps
        src.tpep_pickup_datetime         AS pickup_datetime,
        src.tpep_dropoff_datetime        AS dropoff_datetime,
        DATE(src.tpep_pickup_datetime)   AS pickup_date,

        -- time dimensions
        EXTRACT(HOUR FROM src.tpep_pickup_datetime)                              AS pickup_hour,
        DAYOFWEEK(src.tpep_pickup_datetime)                                      AS pickup_day_of_week,
        IFF(DAYOFWEEK(src.tpep_pickup_datetime) IN (0, 6), TRUE, FALSE)         AS is_weekend,
        IFF(
            EXTRACT(HOUR FROM src.tpep_pickup_datetime) BETWEEN 7 AND 9
            OR EXTRACT(HOUR FROM src.tpep_pickup_datetime) BETWEEN 16 AND 19,
            TRUE, FALSE
        )                                                                         AS is_rush_hour,

        -- time-of-day bucket
        CASE
            WHEN EXTRACT(HOUR FROM src.tpep_pickup_datetime) BETWEEN 5  AND 7  THEN 'Early morning (5-8)'
            WHEN EXTRACT(HOUR FROM src.tpep_pickup_datetime) BETWEEN 8  AND 11 THEN 'Morning (8-12)'
            WHEN EXTRACT(HOUR FROM src.tpep_pickup_datetime) BETWEEN 12 AND 16 THEN 'Afternoon (12-17)'
            WHEN EXTRACT(HOUR FROM src.tpep_pickup_datetime) BETWEEN 17 AND 20 THEN 'Evening (17-21)'
            WHEN EXTRACT(HOUR FROM src.tpep_pickup_datetime) BETWEEN 21 AND 23
                OR EXTRACT(HOUR FROM src.tpep_pickup_datetime) = 0              THEN 'Night (21-1)'
            ELSE 'Late night (1-5)'
        END AS time_of_day,

        -- trip metrics (metric system)
        COALESCE(src.passenger_count::INT, 0)                                              AS passenger_count,
        ROUND(src.trip_distance * 1.60934, 2)                                              AS trip_distance_km,
        DATEDIFF('minute', src.tpep_pickup_datetime, src.tpep_dropoff_datetime)            AS trip_duration_minutes,
        ROUND(
            DIV0NULL(
                src.trip_distance * 1.60934,
                DATEDIFF('minute', src.tpep_pickup_datetime, src.tpep_dropoff_datetime) / 60
            ),
            2
        )                                                                                   AS speed_kmh,

        -- financials
        src.fare_amount,
        COALESCE(src.extra, 0)                  AS extra,
        COALESCE(src.mta_tax, 0)                AS mta_tax,
        src.tip_amount,
        COALESCE(src.tolls_amount, 0)           AS tolls_amount,
        COALESCE(src.improvement_surcharge, 0)  AS improvement_surcharge,
        COALESCE(src.congestion_surcharge, 0)   AS congestion_surcharge,
        COALESCE(src.airport_fee, 0)            AS airport_fee,
        COALESCE(src.cbd_congestion_fee, 0)     AS cbd_congestion_fee,
        src.total_amount,
        ROUND(DIV0NULL(src.fare_amount, NULLIF(src.trip_distance * 1.60934, 0)), 2) AS fare_per_km,

        -- tip_percentage is only meaningful for card payments (payment_type = 1)
        ROUND(
            IFF(src.payment_type = 1, DIV0NULL(src.tip_amount, NULLIF(src.fare_amount, 0)) * 100, NULL),
            2
        )                                                                            AS tip_percentage,

        -- flags
        src.store_and_fwd_flag,

        -- zone enrichment
        pz.borough      AS pickup_borough,
        pz.zone         AS pickup_zone,
        pz.service_zone AS pickup_service_zone,
        dz.borough      AS dropoff_borough,
        dz.zone         AS dropoff_zone,
        dz.service_zone AS dropoff_service_zone,
        IFF(pz.service_zone = 'Airports' OR dz.service_zone = 'Airports', TRUE, FALSE) AS is_airport_trip,

        -- ingestion metadata
        src._loaded_at,
        src._source_file

    FROM source src
    LEFT JOIN zones pz ON src.pulocationid = pz.locationid
    LEFT JOIN zones dz ON src.dolocationid = dz.locationid
    WHERE
        src.tpep_pickup_datetime  >= '2024-01-01'
        AND src.tpep_pickup_datetime  <= '2025-12-31'
        AND src.tpep_dropoff_datetime  > src.tpep_pickup_datetime
        AND src.trip_distance          > 0
        AND src.trip_distance * 1.60934 <= 35          -- P99 ~ 32 km
        AND DATEDIFF('minute', src.tpep_pickup_datetime, src.tpep_dropoff_datetime) <= 75  -- P99 ~ 71 min
        AND src.fare_amount            >= 0
        AND src.total_amount           >= 0
        AND src.payment_type           IN (1, 2, 3, 4, 5, 6)
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY src.vendorid, src.tpep_pickup_datetime, src.tpep_dropoff_datetime,
                     src.pulocationid, src.dolocationid, src.fare_amount
        ORDER BY src._loaded_at DESC
    ) = 1
),

final AS (
    SELECT
        *,

        -- distance category
        CASE
            WHEN trip_distance_km <= 1  THEN '0-1 km'
            WHEN trip_distance_km <= 5  THEN '1-5 km'
            WHEN trip_distance_km <= 10 THEN '5-10 km'
            WHEN trip_distance_km <= 20 THEN '10-20 km'
            ELSE '20+ km'
        END AS distance_category,

        -- duration category
        CASE
            WHEN trip_duration_minutes <= 5  THEN '0-5 min'
            WHEN trip_duration_minutes <= 15 THEN '5-15 min'
            WHEN trip_duration_minutes <= 30 THEN '15-30 min'
            WHEN trip_duration_minutes <= 60 THEN '30-60 min'
            ELSE '60+ min'
        END AS duration_category,

        -- fare category
        CASE
            WHEN fare_amount <= 10  THEN '$0-10'
            WHEN fare_amount <= 25  THEN '$10-25'
            WHEN fare_amount <= 50  THEN '$25-50'
            WHEN fare_amount <= 100 THEN '$50-100'
            ELSE '$100+'
        END AS fare_category,

        -- tip category (NULL for non-card payments)
        CASE
            WHEN payment_type_id != 1                THEN NULL
            WHEN tip_percentage IS NULL
              OR tip_percentage = 0                   THEN 'No tip'
            WHEN tip_percentage <= 10                THEN 'Low (1-10%)'
            WHEN tip_percentage <= 20                THEN 'Standard (10-20%)'
            ELSE 'Generous (20%+)'
        END AS tip_category,

        -- party size
        CASE
            WHEN passenger_count = 1              THEN 'Solo'
            WHEN passenger_count = 2              THEN 'Pair'
            WHEN passenger_count BETWEEN 3 AND 4  THEN 'Small group (3-4)'
            WHEN passenger_count >= 5             THEN 'Large group (5+)'
            ELSE 'Unknown'
        END AS party_size,

        -- speed category
        CASE
            WHEN speed_kmh <= 10 THEN 'Crawl (0-10)'
            WHEN speed_kmh <= 20 THEN 'Slow (10-20)'
            WHEN speed_kmh <= 40 THEN 'Normal (20-40)'
            ELSE 'Fast (40+)'
        END AS speed_category

    FROM renamed
)

SELECT * FROM final
