-- Рассчитываем retention месячных когорт на контрольных днях.
-- Для каждого дня используем только полностью наблюдаемые когорты.
-- Дополнительно выводим исходный размер каждой когорты.
-- Фильтр позволяет выбрать период регистрации пользователей.

WITH base_users AS (
    SELECT
        id AS user_id,
        date_joined::date AS registration_date,
        DATE_TRUNC('month', date_joined)::date AS cohort_month
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
    SELECT retention_day
    FROM (
        VALUES (1), (3), (7), (14), (30), (60), (90)
    ) AS t(retention_day)
),

-- Размер когорты и последняя дата регистрации в ней.
cohort_bounds AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_size,
        MAX(registration_date) AS last_registration_date
    FROM base_users
    GROUP BY cohort_month
),

cohort_retention AS (
    SELECT
        bu.cohort_month,
        cb.cohort_size,
        rd.retention_day,

        ROUND(
            COUNT(e.user_id) * 100.0 / COUNT(*),
            2
        ) AS retention_pct

    FROM base_users AS bu

    JOIN cohort_bounds AS cb
        ON cb.cohort_month = bu.cohort_month

    CROSS JOIN retention_days AS rd
    CROSS JOIN observation AS o

    LEFT JOIN entries AS e
        ON e.user_id = bu.user_id
       AND e.entry_date =
           bu.registration_date + rd.retention_day

    WHERE cb.last_registration_date + rd.retention_day
          <= o.observation_end

    GROUP BY
        bu.cohort_month,
        cb.cohort_size,
        rd.retention_day
)

SELECT
    TO_CHAR(cohort_month, 'YYYY-MM') AS "Когорта",
    cohort_size AS "Размер когорты",

    MAX(retention_pct) FILTER (
        WHERE retention_day = 1
    ) AS d1,

    MAX(retention_pct) FILTER (
        WHERE retention_day = 3
    ) AS d3,

    MAX(retention_pct) FILTER (
        WHERE retention_day = 7
    ) AS d7,

    MAX(retention_pct) FILTER (
        WHERE retention_day = 14
    ) AS d14,

    MAX(retention_pct) FILTER (
        WHERE retention_day = 30
    ) AS d30,

    MAX(retention_pct) FILTER (
        WHERE retention_day = 60
    ) AS d60,

    MAX(retention_pct) FILTER (
        WHERE retention_day = 90
    ) AS d90

FROM cohort_retention

GROUP BY
    cohort_month,
    cohort_size

ORDER BY cohort_month;
