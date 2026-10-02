-- Распределяем пользователей по количеству активных дней за весь доступный период.
-- Значения более 10 дней объединяем в группу 11+.
-- Пользователям без записей в userentry присваиваем 0 активных дней.
-- Фильтр позволяет выбрать период регистрации пользователей.

WITH user_activity AS (
    SELECT
        u.id AS user_id,
        COUNT(DISTINCT ue.entry_at::date) AS active_days
    FROM users AS u
    LEFT JOIN userentry AS ue
        ON u.id = ue.user_id
    WHERE u.id > 94
        [[AND {{registration_period}}]]
    GROUP BY u.id
),

activity_groups AS (
    SELECT
        CASE
            WHEN active_days > 10 THEN '11+'
            ELSE active_days::text
        END AS active_days_group,
        CASE
            WHEN active_days > 10 THEN 11
            ELSE active_days
        END AS sort_order
    FROM user_activity
),

activity_distribution AS (
    SELECT
        active_days_group,
        sort_order,
        COUNT(*) AS users
    FROM activity_groups
    GROUP BY
        active_days_group,
        sort_order
)

SELECT
    active_days_group,
    users,
    ROUND(
        users * 100.0 / SUM(users) OVER (),
        2
    ) AS users_pct
FROM activity_distribution
ORDER BY sort_order;
