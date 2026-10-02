-- Сравниваем D7 retention пользователей с CodeSubmit в первые три дня после регистрации и без него.
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

-- Пользователи, у которых был хотя бы один CodeSubmit в D0–D2.
early_codesubmit AS (
    SELECT DISTINCT
        bu.user_id
    FROM base_users AS bu
    JOIN codesubmit AS cs
        ON cs.user_id = bu.user_id
       AND cs.created_at::date
           BETWEEN bu.registration_date
               AND bu.registration_date + 2
),

-- Пользователи, вернувшиеся на платформу на D7.
retained_d7 AS (
    SELECT DISTINCT
        bu.user_id
    FROM base_users AS bu
    JOIN userentry AS ue
        ON ue.user_id = bu.user_id
       AND ue.entry_at::date = bu.registration_date + 7
),

user_data AS (
    SELECT
        bu.user_id,
        bu.registration_date,

        CASE
            WHEN ecs.user_id IS NOT NULL THEN 1
            ELSE 0
        END AS has_early_codesubmit,

        CASE
            WHEN rd7.user_id IS NOT NULL THEN 1
            ELSE 0
        END AS retained_d7

    FROM base_users AS bu
    LEFT JOIN early_codesubmit AS ecs
        ON ecs.user_id = bu.user_id
    LEFT JOIN retained_d7 AS rd7
        ON rd7.user_id = bu.user_id
)

SELECT
    CASE
        WHEN ud.has_early_codesubmit = 1 THEN 'Был CodeSubmit'
        ELSE 'Не было CodeSubmit'
    END AS codesubmit_group,

    COUNT(*) AS users,
    SUM(ud.retained_d7) AS retained_d7,

    ROUND(
        AVG(ud.retained_d7) * 100,
        2
    ) AS d7_retention_pct

FROM user_data AS ud
CROSS JOIN observation AS o

WHERE ud.registration_date + 7 <= o.observation_end

GROUP BY ud.has_early_codesubmit
ORDER BY ud.has_early_codesubmit;
