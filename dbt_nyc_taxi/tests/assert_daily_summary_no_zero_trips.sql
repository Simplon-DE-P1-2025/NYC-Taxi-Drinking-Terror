SELECT *
FROM {{ ref('daily_summary') }}
WHERE total_trips <= 0
