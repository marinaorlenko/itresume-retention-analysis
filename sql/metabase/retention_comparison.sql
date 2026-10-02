-- Сравниваем динамику N-day и Rolling retention от D1 до D90.
-- N-day retention показывает долю пользователей, активных точно в день Dn.
-- Rolling retention показывает долю пользователей, которые были активны
-- в день Dn или в любой последующий день.
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
    SELECT GENERATE_SERIES(1, 90) AS retention_day
),

retention AS (
    SELECT
        rd.retention_day,

        ROUND(
            COUNT(e.user_id) * 100.0 / COUNT(*),
            2
        ) AS n_day_retention,

        ROUND(
            COUNT(*) FILTER (
                WHERE le.last_entry_date
                      >= le.registration_date + rd.retention_day
            ) * 100.0 / COUNT(*),
            2
        ) AS rolling_retention

    FROM retention_days AS rd
    CROSS JOIN base_users AS bu
    CROSS JOIN observation AS o

    LEFT JOIN entries AS e
        ON e.user_id = bu.user_id
       AND e.entry_date = bu.registration_date + rd.retention_day

    LEFT JOIN last_entries AS le
        ON le.user_id = bu.user_id

    WHERE bu.registration_date + rd.retention_day
          <= o.observation_end

    GROUP BY rd.retention_day
)

SELECT
    retention_day,
    n_day_retention AS "N-day retention",
    rolling_retention AS "Rolling retention"
FROM retention
ORDER BY retention_day;
