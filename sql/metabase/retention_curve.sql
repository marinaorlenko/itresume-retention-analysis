-- Рассчитываем N-day retention для контрольных дней D1, D3, D7, D14, D30, D60 и D90.
-- Фильтр позволяет выбрать период регистрации пользователей.

WITH base_users AS (
    SELECT
        id AS user_id,
        date_joined::date AS registration_date
    FROM users
    WHERE id > 94
        [[AND {{registration_period}}]]
),

observation AS (
    SELECT
        MAX(entry_at::date) AS observation_end
    FROM userentry
    WHERE user_id > 94
),

entries AS (
    SELECT DISTINCT
        ue.user_id,
        ue.entry_at::date AS entry_date
    FROM userentry AS ue
    JOIN base_users AS bu
        ON bu.user_id = ue.user_id
),

retention_days AS (
    SELECT UNNEST(ARRAY[1, 3, 7, 14, 30, 60, 90]) AS retention_day
)

SELECT
    rd.retention_day,
    COUNT(*) AS eligible_users,
    COUNT(e.user_id) AS retained_users,
    ROUND(
        COUNT(e.user_id) * 100.0 / COUNT(*),
        2
    ) AS retention_pct
FROM retention_days AS rd
CROSS JOIN base_users AS bu
CROSS JOIN observation AS o
LEFT JOIN entries AS e
    ON e.user_id = bu.user_id
    AND e.entry_date = bu.registration_date + rd.retention_day
WHERE bu.registration_date + rd.retention_day <= o.observation_end
GROUP BY rd.retention_day
ORDER BY rd.retention_day;
