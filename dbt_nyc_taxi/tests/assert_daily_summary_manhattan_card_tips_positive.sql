-- Manhattan card-paying passengers should average at least 15% tip each month.
-- NYC taxi POS systems display 20/25/30% tip buttons by default — 15% is the
-- cultural minimum for NYC tipping. Manhattan's tourist and business-traveler
-- base consistently tips above this threshold.
-- Rows returned = months where Manhattan avg tip falls below 15% → anomaly.
WITH manhattan_monthly_tip AS (
    SELECT
        pickup_month,
        AVG(avg_tip_pct_card) AS monthly_avg_tip_pct
    FROM {{ ref('daily_summary') }}
    WHERE pickup_borough = 'Manhattan'
      AND avg_tip_pct_card IS NOT NULL
    GROUP BY pickup_month
)
SELECT *
FROM manhattan_monthly_tip
WHERE monthly_avg_tip_pct < 15
