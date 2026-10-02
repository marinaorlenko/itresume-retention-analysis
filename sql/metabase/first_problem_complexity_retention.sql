-- Определяем первую задачу пользователя в D0–D2 и сравниваем D7 retention по уровням её сложности.
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

-- Находим первый CodeRun пользователя в D0–D2.
first_run AS (
    SELECT DISTINCT ON (cr.user_id)
        cr.user_id,
        bu.registration_date,
        cr.problem_id,
        cr.created_at AS first_run_at
    FROM coderun AS cr
    JOIN base_users AS bu
        ON bu.user_id = cr.user_id
    WHERE cr.created_at::date
          BETWEEN bu.registration_date
              AND bu.registration_date + 2
    ORDER BY
        cr.user_id,
        cr.created_at
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
        fr.user_id,
        fr.registration_date,
        problem.complexity,

        CASE
            WHEN rd7.user_id IS NOT NULL THEN 1
            ELSE 0
        END AS retained_d7

    FROM first_run AS fr

    JOIN problem
        ON problem.id = fr.problem_id
        [[AND {{complexity}}]]

    LEFT JOIN retained_d7 AS rd7
        ON rd7.user_id = fr.user_id
)

SELECT
    ud.complexity,
    COUNT(*) AS users,
    SUM(ud.retained_d7) AS retained_d7,

    ROUND(
        AVG(ud.retained_d7) * 100,
        2
    ) AS d7_retention_pct

FROM user_data AS ud
CROSS JOIN observation AS o

WHERE ud.registration_date + 7 <= o.observation_end

GROUP BY ud.complexity
ORDER BY ud.complexity;
