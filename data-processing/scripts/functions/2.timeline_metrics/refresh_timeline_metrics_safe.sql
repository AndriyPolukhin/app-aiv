CREATE OR REPLACE FUNCTION refresh_timeline_metrics_safe(
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_interval TEXT DEFAULT 'month',
    p_batch_size INTEGER DEFAULT 100,
    p_max_retries INTEGER DEFAULT 2,
    p_incremental BOOLEAN DEFAULT TRUE
)
RETURNS VOID AS $$
DECLARE
    current_period DATE;
    period_interval INTERVAL;
    processed_count INTEGER := 0;
BEGIN
    -- Conservative initialization of parameters
    p_start_date := COALESCE(p_start_date,
        (SELECT MIN(commit_date)::DATE FROM commits));
    p_end_date := COALESCE(p_end_date, CURRENT_DATE);

    period_interval := CASE p_interval
        WHEN 'day' THEN INTERVAL '1 day'
        WHEN 'week' THEN INTERVAL '1 week'
        WHEN 'month' THEN INTERVAL '1 month'
        WHEN 'quarter' THEN INTERVAL '3 months'
        ELSE INTERVAL '1 month'
    END;

    current_period := p_start_date;
    WHILE current_period <= p_end_date LOOP
        -- Comprehensive Metrics Calculation with Null Safety
        WITH period_commits AS (
            SELECT *
            FROM commits c
            WHERE c.commit_date::DATE BETWEEN
                current_period AND
                (current_period + period_interval - INTERVAL '1 day')::DATE
        ),
        period_issues AS (
            SELECT
                ji.issue_id,
                ji.project_id,
                COUNT(pc.commit_id) AS total_commits,
                COUNT(pc.commit_id) FILTER (WHERE pc.ai_used) AS ai_commits,
                BOOL_OR(pc.ai_used) AS has_ai_commits
            FROM
                jira_issues ji
            LEFT JOIN period_commits pc ON ji.issue_id = pc.jira_issue_id
            GROUP BY
                ji.issue_id, ji.project_id
        ),
        metrics_calculation AS (
            SELECT
                -- Explicit Null Handling with Coalesce
                COALESCE(COUNT(*), 0) AS total_issues,
                COALESCE(
                    SUM(CASE WHEN has_ai_commits THEN 1 ELSE 0 END),
                    0
                ) AS ai_assisted_issues,
                COALESCE(
                    SUM(CASE WHEN NOT has_ai_commits THEN 1 ELSE 0 END),
                    0
                ) AS non_ai_assisted_issues,

                -- Cycle Time with Explicit Null Management
                COALESCE(
                    AVG(CASE WHEN has_ai_commits THEN total_commits ELSE NULL END),
                    0::FLOAT
                ) AS avg_cycle_time_with_ai,

                COALESCE(
                    AVG(CASE WHEN NOT has_ai_commits THEN total_commits ELSE NULL END),
                    0::FLOAT
                ) AS avg_cycle_time_without_ai,

                -- AI Adoption Percentage with Divide-by-Zero Protection
                CASE
                    WHEN COUNT(*) > 0
                    THEN (
                        SUM(CASE WHEN has_ai_commits THEN 1 ELSE 0 END)::FLOAT /
                        COUNT(*)
                    ) * 100
                    ELSE 0
                END AS ai_adoption_percentage,

                -- Cycle Time Impact Calculation
                COALESCE(
                    (AVG(CASE WHEN has_ai_commits THEN total_commits ELSE NULL END) /
                     NULLIF(AVG(CASE WHEN NOT has_ai_commits THEN total_commits ELSE NULL END), 0) - 1)
                    * 100,
                    0
                ) AS cycle_time_impact_percentage
            FROM
                period_issues
        )
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
        )
        SELECT
            current_period,
            total_issues,
            ai_assisted_issues,
            non_ai_assisted_issues,
            avg_cycle_time_with_ai,
            avg_cycle_time_without_ai,
            cycle_time_impact_percentage,
            ai_adoption_percentage,
            CURRENT_TIMESTAMP,
            json_build_object(
                'total_issues', total_issues,
                'ai_assisted_issues', ai_assisted_issues,
                'cycle_metrics', json_build_object(
                    'with_ai', avg_cycle_time_with_ai,
                    'without_ai', avg_cycle_time_without_ai
                )
            )
        FROM metrics_calculation
        ON CONFLICT (time_period) DO UPDATE SET
            total_issues = EXCLUDED.total_issues,
            ai_assisted_issues = EXCLUDED.ai_assisted_issues,
            non_ai_assisted_issues = EXCLUDED.non_ai_assisted_issues,
            avg_cycle_time_with_ai = EXCLUDED.avg_cycle_time_with_ai,
            avg_cycle_time_without_ai = EXCLUDED.avg_cycle_time_without_ai,
            cycle_time_impact_percentage = EXCLUDED.cycle_time_impact_percentage,
            ai_adoption_percentage = EXCLUDED.ai_adoption_percentage,
            last_calculated = CURRENT_TIMESTAMP,
            metrics_json = EXCLUDED.metrics_json;

        current_period := current_period + period_interval;
        processed_count := processed_count + 1;
    END LOOP;

    RAISE NOTICE 'Processed % time periods successfully', processed_count;
END;
$$ LANGUAGE plpgsql;