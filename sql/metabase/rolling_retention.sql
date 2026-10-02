-- Рассчитываем Rolling retention для контрольных дней D1, D3, D7, D14, D30, D60 и D90:
-- пользователь считается удержанным на Dn, если он заходил на платформу в день Dn или
-- в любой последующий день.
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

last_entries AS (
    SELECT
        bu.user_id,
        bu.registration_date,
        MAX(ue.entry_at::date) AS last_entry_date
    FROM base_users AS bu
    LEFT JOIN userentry AS ue
        ON ue.user_id = bu.user_id
    GROUP BY
        bu.user_id,
        bu.registration_date
),

retention_days AS (
    SELECT UNNEST(ARRAY[1, 3, 7, 14, 30, 60, 90]) AS retention_day
)

SELECT
    rd.retention_day,
    COUNT(*) AS eligible_users,

    COUNT(*) FILTER (
        WHERE le.last_entry_date
              >= le.registration_date + rd.retention_day
    ) AS retained_users,

    ROUND(
        COUNT(*) FILTER (
            WHERE le.last_entry_date
                  >= le.registration_date + rd.retention_day
        ) * 100.0
        / COUNT(*),
        2
    ) AS rolling_retention_pct

FROM retention_days AS rd
CROSS JOIN last_entries AS le
CROSS JOIN observation AS o

WHERE le.registration_date + rd.retention_day
      <= o.observation_end

GROUP BY rd.retention_day
ORDER BY rd.retention_day;
