SELECT *
FROM {{ ref('daily_summary') }}
WHERE avg_tip_pct_card < 0
