-- Показываем, какая доля зарегистрированных пользователей хотя бы раз совершала
-- основные действия на платформе.
-- Каждый пользователь учитывается в каждом действии только один раз.
-- Фильтр позволяет выбрать период регистрации пользователей.

WITH base_users AS (
    SELECT id AS user_id
    FROM users
    WHERE id > 94
        [[AND {{registration_period}}]]
),

entry_users AS (
    SELECT DISTINCT ue.user_id
    FROM userentry AS ue
    JOIN base_users AS bu
        ON bu.user_id = ue.user_id
),

run_users AS (
    SELECT DISTINCT cr.user_id
    FROM coderun AS cr
    JOIN base_users AS bu
        ON bu.user_id = cr.user_id
),

submit_users AS (
    SELECT DISTINCT cs.user_id
    FROM codesubmit AS cs
    JOIN base_users AS bu
        ON bu.user_id = cs.user_id
),

successful_users AS (
    SELECT DISTINCT cs.user_id
    FROM codesubmit AS cs
    JOIN base_users AS bu
        ON bu.user_id = cs.user_id
    WHERE cs.is_false = 0
),

test_users AS (
    SELECT DISTINCT ts.user_id
    FROM teststart AS ts
    JOIN base_users AS bu
        ON bu.user_id = ts.user_id
),

activity_counts AS (
    SELECT
        COUNT(*) AS registered_users,
        COUNT(e.user_id) AS users_with_entry,
        COUNT(r.user_id) AS users_with_run,
        COUNT(s.user_id) AS users_with_submit,
        COUNT(ss.user_id) AS users_with_successful_submit,
        COUNT(t.user_id) AS users_with_test_start
    FROM base_users AS bu
    LEFT JOIN entry_users AS e
        ON bu.user_id = e.user_id
    LEFT JOIN run_users AS r
        ON bu.user_id = r.user_id
    LEFT JOIN submit_users AS s
        ON bu.user_id = s.user_id
    LEFT JOIN successful_users AS ss
        ON bu.user_id = ss.user_id
    LEFT JOIN test_users AS t
        ON bu.user_id = t.user_id
)

SELECT
    activity,
    users,
    ROUND(
        users * 100.0 / NULLIF(registered_users, 0),
        2
    ) AS users_pct
FROM activity_counts
CROSS JOIN LATERAL (
    VALUES
        ('Зарегистрировались', registered_users),
        ('Заходили на платформу', users_with_entry),
        ('Запускали код', users_with_run),
        ('Отправляли решение', users_with_submit),
        ('Успешно решали задачу', users_with_successful_submit),
        ('Начинали тест', users_with_test_start)
) AS activity_data(activity, users);
