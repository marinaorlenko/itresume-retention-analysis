-- Количество регистраций по месяцам и изменение относительно предыдущего месяца.
-- Фильтр позволяет выбрать период регистрации пользователей.

WITH monthly_registrations AS (
    SELECT
        DATE_TRUNC('month', date_joined)::date AS registration_month,
        COUNT(*) AS registrations
    FROM users
    WHERE id > 94
        [[AND {{registration_period}}]]
    GROUP BY registration_month
)

SELECT
    registration_month,
    registrations,
    ROUND(
        (
            registrations * 1.0
            / NULLIF(
                LAG(registrations) OVER (ORDER BY registration_month),
                0
            )
            - 1
        ) * 100,
        2
    ) AS growth_pct
FROM monthly_registrations
ORDER BY registration_month;
