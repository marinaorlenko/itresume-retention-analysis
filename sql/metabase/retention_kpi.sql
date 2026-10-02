-- Рассчитываем основные KPI для выбранного периода регистрации:
-- количество пользователей, D7, D30 и Rolling D30 retention.
-- Для retention учитываем только пользователей, для которых соответствующий период
-- наблюдения уже завершён.

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

user_activity AS (
    SELECT
        bu.user_id,
        bu.registration_date,

        MAX(
            CASE
                WHEN ue.entry_at::date = bu.registration_date + 7
                THEN 1 ELSE 0
            END
        ) AS retained_d7,

        MAX(
            CASE
                WHEN ue.entry_at::date = bu.registration_date + 30
                THEN 1 ELSE 0
            END
        ) AS retained_d30,

        MAX(ue.entry_at::date) AS last_entry_date

    FROM base_users AS bu
    LEFT JOIN userentry AS ue
        ON ue.user_id = bu.user_id

    GROUP BY
        bu.user_id,
        bu.registration_date
)

SELECT
    COUNT(*) AS users,

    ROUND(
        AVG(retained_d7) FILTER (
            WHERE registration_date + 7 <= observation_end
        ) * 100,
        2
    ) AS d7_retention,

    ROUND(
        AVG(retained_d30) FILTER (
            WHERE registration_date + 30 <= observation_end
        ) * 100,
        2
    ) AS d30_retention,

    ROUND(
        AVG(
            CASE
                WHEN last_entry_date >= registration_date + 30
                THEN 1.0 ELSE 0.0
            END
        ) FILTER (
            WHERE registration_date + 30 <= observation_end
        ) * 100,
        2
    ) AS rolling_d30

FROM user_activity
CROSS JOIN observation;
