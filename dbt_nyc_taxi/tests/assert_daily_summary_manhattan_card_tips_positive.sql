-- Manhattan card-paying passengers should leave a positive average tip every month.
-- NYC taxi POS systems display 20/25/30% tip buttons by default, and Manhattan's
-- tourist and business-traveler base tips consistently. With thousands of card
-- payments per month, the monthly average should never reach zero.
-- Rows returned = months where Manhattan avg tip is zero or negative → anomaly.
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
WHERE monthly_avg_tip_pct <= 0
