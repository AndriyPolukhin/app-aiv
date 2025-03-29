CREATE OR REPLACE FUNCTION refresh_timeline_metrics(
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_interval TEXT DEFAULT 'month' -- 'day', 'week', 'month', 'quarter'
)
RETURNS VOID AS $$
DECLARE
    current_period DATE;
    end_period DATE;
    period_interval INTERVAL;
    impact_data JSON;
BEGIN
    -- Set default period if not specified
    IF p_start_date IS NULL THEN
        p_start_date := (SELECT MIN(commit_date)::DATE FROM commits);
    END IF;

    IF p_end_date IS NULL THEN
        p_end_date := CURRENT_DATE;
    END IF;

    -- Convert interval string to PostgreSQL interval
    CASE p_interval
        WHEN 'day' THEN period_interval := INTERVAL '1 day';
        WHEN 'week' THEN period_interval := INTERVAL '1 week';
        WHEN 'month' THEN period_interval := INTERVAL '1 month';
        WHEN 'quarter' THEN period_interval := INTERVAL '3 months';
        ELSE period_interval := INTERVAL '1 month';
    END CASE;

    -- Loop through each time period
    current_period := p_start_date;
    WHILE current_period <= p_end_date LOOP
        -- Calculate end of current period
        CASE p_interval
            WHEN 'day' THEN end_period := current_period;
            WHEN 'week' THEN end_period := current_period + INTERVAL '6 days';
            WHEN 'month' THEN end_period := (current_period + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
            WHEN 'quarter' THEN end_period := (current_period + INTERVAL '3 months' - INTERVAL '1 day')::DATE;
        END CASE;

        -- Create temporary tables for period-specific data
        CREATE TEMPORARY TABLE period_commits AS
        SELECT *
        FROM commits c
        WHERE c.commit_date::DATE BETWEEN current_period AND end_period;

        CREATE TEMPORARY TABLE period_issues AS
        WITH issue_data AS (
            SELECT
                ji.issue_id,
                ji.project_id,
                ji.author_id,
                ji.creation_date,
                ji.resolution_date,
                ji.category,
                (SELECT MIN(pc.commit_date) FROM period_commits pc WHERE pc.jira_issue_id = ji.issue_id) AS first_commit_date,
                (SELECT COUNT(*) FROM period_commits pc WHERE pc.jira_issue_id = ji.issue_id) AS total_commits,
                (SELECT COUNT(*) FROM period_commits pc WHERE pc.jira_issue_id = ji.issue_id AND pc.ai_used = true) AS ai_commits,
                (SELECT EXISTS(SELECT 1 FROM period_commits pc WHERE pc.jira_issue_id = ji.issue_id AND pc.ai_used = true)) AS has_ai_commits
            FROM
                jira_issues ji
            WHERE
                EXISTS (SELECT 1 FROM period_commits pc WHERE pc.jira_issue_id = ji.issue_id)
                AND (ji.resolution_date BETWEEN current_period AND end_period)
        )
        SELECT * FROM issue_data;

        -- Calculate period metrics
        CREATE TEMPORARY TABLE period_metrics AS
        SELECT
            COUNT(*) AS total_issues,
            SUM(CASE WHEN has_ai_commits THEN 1 ELSE 0 END) AS ai_assisted_issues,
            SUM(CASE WHEN NOT has_ai_commits THEN 1 ELSE 0 END) AS non_ai_assisted_issues,
            AVG(CASE WHEN has_ai_commits THEN days_between(first_commit_date, resolution_date) ELSE NULL END) AS avg_cycle_time_with_ai,
            AVG(CASE WHEN NOT has_ai_commits THEN days_between(first_commit_date, resolution_date) ELSE NULL END) AS avg_cycle_time_without_ai
        FROM
            period_issues;

        -- Extract metric values
        SELECT
            total_issues,
            ai_assisted_issues,
            non_ai_assisted_issues,
            COALESCE(avg_cycle_time_with_ai, 0) AS avg_cycle_time_with_ai,
            COALESCE(avg_cycle_time_without_ai, 0) AS avg_cycle_time_without_ai,
            CASE
                WHEN COALESCE(avg_cycle_time_without_ai, 0) > 0
                THEN ((avg_cycle_time_without_ai - COALESCE(avg_cycle_time_with_ai, 0)) / avg_cycle_time_without_ai) * 100
                ELSE 0
            END AS impact_percentage,
            CASE
                WHEN total_issues > 0
                THEN (ai_assisted_issues::FLOAT / total_issues) * 100
                ELSE 0
            END AS adoption_percentage
        INTO
            impact_data
        FROM
            period_metrics;

        -- Build detailed metrics JSON
        SELECT json_build_object(
            'period', json_build_object(
                'start', current_period,
                'end', end_period,
                'interval', p_interval
            ),
            'summary', json_build_object(
                'totalIssues', impact_data.total_issues,
                'aiAssistedIssues', impact_data.ai_assisted_issues,
                'nonAiAssistedIssues', impact_data.non_ai_assisted_issues,
                'avgCycleTimeWithAi', impact_data.avg_cycle_time_with_ai,
                'avgCycleTimeWithoutAi', impact_data.avg_cycle_time_without_ai,
                'cycleTimeImpactPercentage', impact_data.impact_percentage,
                'aiAdoptionPercentage', impact_data.adoption_percentage
            ),
            'topCategories', (
                SELECT json_agg(json_build_object(
                    'category', category,
                    'count', count,
                    'aiPercentage', (ai_count::FLOAT / count) * 100
                ))
                FROM (
                    SELECT
                        category,
                        COUNT(*) AS count,
                        SUM(CASE WHEN has_ai_commits THEN 1 ELSE 0 END) AS ai_count
                    FROM
                        period_issues
                    GROUP BY
                        category
                    ORDER BY
                        count DESC
                    LIMIT 5
                ) top_cats
            ),
            'topRepositories', (
                SELECT json_agg(json_build_object(
                    'repoId', repo_id,
                    'commitCount', commit_count,
                    'aiPercentage', (ai_commits::FLOAT / commit_count) * 100
                ))
                FROM (
                    SELECT
                        repo_id,
                        COUNT(*) AS commit_count,
                        SUM(CASE WHEN ai_used THEN 1 ELSE 0 END) AS ai_commits
                    FROM
                        period_commits
                    GROUP BY
                        repo_id
                    ORDER BY
                        commit_count DESC
                    LIMIT 5
                ) top_repos
            )
        ) INTO impact_data;

        -- Insert or update the materialized metrics
        INSERT INTO timeline_metrics_materialized (
            time_period,
            total_issues,
            ai_assisted_issues,
            non_ai_assisted_issues,
            avg_cycle_time_with_ai,
            avg_cycle_time_without_ai,
            cycle_time_impact_percentage,
            ai_adoption_percentage,
            last_calculated,
            metrics_json
        ) VALUES (
            current_period,
            impact_data.total_issues,
            impact_data.ai_assisted_issues,
            impact_data.non_ai_assisted_issues,
            impact_data.avg_cycle_time_with_ai,
            impact_data.avg_cycle_time_without_ai,
            impact_data.impact_percentage,
            impact_data.adoption_percentage,
            CURRENT_TIMESTAMP,
            impact_data
        )
        ON CONFLICT (time_period) DO UPDATE SET
            total_issues = EXCLUDED.total_issues,
            ai_assisted_issues = EXCLUDED.ai_assisted_issues,
            non_ai_assisted_issues = EXCLUDED.non_ai_assisted_issues,
            avg_cycle_time_with_ai = EXCLUDED.avg_cycle_time_with_ai,
            avg_cycle_time_without_ai = EXCLUDED.avg_cycle_time_without_ai,
            cycle_time_impact_percentage = EXCLUDED.cycle_time_impact_percentage,
            ai_adoption_percentage = EXCLUDED.ai_adoption_percentage,
            last_calculated = EXCLUDED.last_calculated,
            metrics_json = EXCLUDED.metrics_json;

        -- Clean up temporary tables
        DROP TABLE period_commits;
        DROP TABLE period_issues;
        DROP TABLE period_metrics;

        -- Move to next period
        current_period := current_period + period_interval;
    END LOOP;
END;
$$ LANGUAGE plpgsql;