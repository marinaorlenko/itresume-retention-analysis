-- Сравниваем D7 и D30 retention в зависимости от количества активных дней пользователя в D0–D2.
-- В расчёт включаем только пользователей, для которых полностью доступен D30.
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

-- Считаем количество активных дней в D0–D2.
early_activity AS (
    SELECT
        bu.user_id,
        bu.registration_date,
        COUNT(
            DISTINCT CASE
                WHEN e.entry_date BETWEEN bu.registration_date
                                      AND bu.registration_date + 2
                THEN e.entry_date
            END
        ) AS early_active_days
    FROM base_users AS bu
    LEFT JOIN entries AS e
        ON e.user_id = bu.user_id
    GROUP BY
        bu.user_id,
        bu.registration_date
),

-- Определяем возвращение пользователя на D7 и D30.
user_retention AS (
    SELECT
        ea.user_id,
        ea.registration_date,
        ea.early_active_days,

        MAX(
            CASE
                WHEN e.entry_date = ea.registration_date + 7
                THEN 1 ELSE 0
            END
        ) AS retained_d7,

        MAX(
            CASE
                WHEN e.entry_date = ea.registration_date + 30
                THEN 1 ELSE 0
            END
        ) AS retained_d30

    FROM early_activity AS ea
    LEFT JOIN entries AS e
        ON e.user_id = ea.user_id
    GROUP BY
        ea.user_id,
        ea.registration_date,
        ea.early_active_days
)

SELECT
    ur.early_active_days,
    COUNT(*) AS users,

    SUM(ur.retained_d7) AS retained_d7,
    ROUND(
        AVG(ur.retained_d7) * 100,
        2
    ) AS "D7 retention",

    SUM(ur.retained_d30) AS retained_d30,
    ROUND(
        AVG(ur.retained_d30) * 100,
        2
    ) AS "D30 retention"

FROM user_retention AS ur
CROSS JOIN observation AS o

WHERE ur.registration_date + 30 <= o.observation_end
    [[AND ur.early_active_days IN ({{active_days}})]]

GROUP BY ur.early_active_days
ORDER BY ur.early_active_days;
