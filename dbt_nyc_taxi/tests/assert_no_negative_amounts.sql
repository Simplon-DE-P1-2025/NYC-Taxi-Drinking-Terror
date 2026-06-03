SELECT *
FROM {{ ref('stg_yellow_trips') }}
WHERE fare_amount < 0
   OR total_amount < 0
