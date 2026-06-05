SELECT *
FROM {{ ref('daily_summary') }}
WHERE pickup_month != DATE_TRUNC('month', pickup_date)
