-- Сравниваем D7 retention пользователей в зависимости от того, с какими разделами платформы
-- они взаимодействовали в первые три дня:
-- только с задачами, только с тестами, с задачами и тестами или не проявляли такой активности.
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

-- Пользователи, работавшие с задачами в D0–D2.
early_task AS (
    SELECT
        bu.user_id
    FROM base_users AS bu
    JOIN (
        SELECT user_id, created_at::date AS activity_date
        FROM coderun

        UNION ALL

        SELECT user_id, created_at::date AS activity_date
        FROM codesubmit
    ) AS task_activity
        ON task_activity.user_id = bu.user_id
       AND task_activity.activity_date
           BETWEEN bu.registration_date
               AND bu.registration_date + 2
    GROUP BY bu.user_id
),

-- Пользователи, начинавшие тесты в D0–D2.
early_test AS (
    SELECT
        bu.user_id
    FROM base_users AS bu
    JOIN teststart AS ts
        ON ts.user_id = bu.user_id
       AND ts.created_at::date
           BETWEEN bu.registration_date
               AND bu.registration_date + 2
    GROUP BY bu.user_id
),

-- Пользователи, вернувшиеся на D7.
retained_d7 AS (
    SELECT
        bu.user_id
    FROM base_users AS bu
    JOIN userentry AS ue
        ON ue.user_id = bu.user_id
       AND ue.entry_at::date = bu.registration_date + 7
    GROUP BY bu.user_id
),

user_sections AS (
    SELECT
        bu.user_id,
        bu.registration_date,

        CASE
            WHEN etask.user_id IS NOT NULL
             AND etest.user_id IS NOT NULL
                THEN 'Задачи + тесты'
            WHEN etask.user_id IS NOT NULL
                THEN 'Только задачи'
            WHEN etest.user_id IS NOT NULL
                THEN 'Только тесты'
            ELSE 'Нет активности'
        END AS sections_group,

        CASE
            WHEN rd7.user_id IS NOT NULL THEN 1
            ELSE 0
        END AS retained_d7

    FROM base_users AS bu

    LEFT JOIN early_task AS etask
        ON etask.user_id = bu.user_id

    LEFT JOIN early_test AS etest
        ON etest.user_id = bu.user_id

    LEFT JOIN retained_d7 AS rd7
        ON rd7.user_id = bu.user_id
)

SELECT
    sections_group,
    COUNT(*) AS users,
    SUM(retained_d7) AS retained_d7,
    ROUND(AVG(retained_d7) * 100, 2) AS d7_retention_pct

FROM user_sections
CROSS JOIN observation AS o

WHERE user_sections.registration_date + 7 <= o.observation_end
    [[AND user_sections.sections_group IN ({{activity_type}})]]

GROUP BY sections_group
ORDER BY d7_retention_pct;
