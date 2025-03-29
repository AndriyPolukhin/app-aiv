CREATE MATERIALIZED VIEW cycle_time_summary AS
-- Use the same query as above
    WITH issue_cycle_times AS (
    SELECT
        j.issue_id,
        j.creation_date,
        j.resolution_date,
        MIN(c.commit_date) AS first_commit_date,
        MAX(c.commit_date) AS last_commit_date,
        (j.resolution_date - MIN(c.commit_date)) AS cycle_time_days,
        BOOL_OR(c.ai_used) AS has_ai_assistance
    FROM jira_issues j
    JOIN commits c ON j.issue_id = c.jira_issue_id
    GROUP BY j.issue_id, j.creation_date, j.resolution_date
    HAVING MIN(c.commit_date) IS NOT NULL
    ),
    ai_usage_classification AS (
    SELECT
        issue_id,
        cycle_time_days,
        CASE
        WHEN has_ai_assistance THEN 'ai_assisted'
        ELSE 'non_ai_assisted'
        END AS assistance_type
    FROM issue_cycle_times
    )
    SELECT
    assistance_type,
    COUNT(issue_id) AS issue_count,
    AVG(cycle_time_days) AS avg_cycle_time_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cycle_time_days) AS median_cycle_time_days,
    MIN(cycle_time_days) AS min_cycle_time_days,
    MAX(cycle_time_days) AS max_cycle_time_days
    FROM ai_usage_classification
    GROUP BY assistance_type;