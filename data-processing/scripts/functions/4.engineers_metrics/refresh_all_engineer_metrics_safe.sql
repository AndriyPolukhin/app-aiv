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
    end_period DATE;
    period_interval INTERVAL;
    last_processed_period DATE;
    processed_count INTEGER := 0;
    retry_count INTEGER;
    impact_metrics RECORD;
BEGIN
    -- Set conservative memory limits
    SET LOCAL work_mem = '32MB';
    SET LOCAL maintenance_work_mem = '64MB';
    SET LOCAL temp_buffers = '8MB';

    -- Determine start and end dates
    IF p_start_date IS NULL THEN
        p_start_date := (SELECT MIN(commit_date)::DATE FROM commits);
    END IF;

    IF p_end_date IS NULL THEN
        p_end_date := CURRENT_DATE;
    END IF;

    -- Incremental processing logic
    IF p_incremental THEN
        SELECT MAX(time_period) INTO last_processed_period
        FROM timeline_metrics_materialized;

        IF last_processed_period IS NOT NULL THEN
            p_start_date := last_processed_period;
        END IF;
    ELSE
        -- Full refresh: delete existing data
        PERFORM batch_delete('timeline_metrics_materialized', p_batch_size);
    END IF;

    -- Convert interval string to PostgreSQL interval
    period_interval := CASE p_interval
        WHEN 'day' THEN INTERVAL '1 day'
        WHEN 'week' THEN INTERVAL '1 week'
        WHEN 'month' THEN INTERVAL '1 month'
        WHEN 'quarter' THEN INTERVAL '3 months'
        ELSE INTERVAL '1 month'
    END;

    -- Iterate through periods with retry mechanism
    current_period := p_start_date;
    WHILE current_period <= p_end_date LOOP
        FOR retry_count IN 0..p_max_retries LOOP
            BEGIN
                -- Comprehensive metrics calculation
                WITH period_commits AS (
                    SELECT *
                    FROM commits c
                    WHERE c.commit_date::DATE BETWEEN current_period AND
                        (current_period + period_interval - INTERVAL '1 day')::DATE
                ),
                period_issues AS (
                    SELECT
                        ji.issue_id,
                        ji.project_id,
                        ji.category,
                        ji.creation_date,
                        ji.resolution_date,
                        COUNT(pc.commit_id) AS total_commits,
                        COUNT(pc.commit_id) FILTER (WHERE pc.ai_used) AS ai_commits,
                        BOOL_OR(pc.ai_used) AS has_ai_commits
                    FROM
                        jira_issues ji
                    JOIN period_commits pc ON ji.issue_id = pc.jira_issue_id
                    GROUP BY
                        ji.issue_id, ji.project_id, ji.category,
                        ji.creation_date, ji.resolution_date
                ),
                metrics_calculation AS (
                    SELECT
                        COUNT(*) AS total_issues,
                        SUM(CASE WHEN has_ai_commits THEN 1 ELSE 0 END) AS ai_assisted_issues,
                        SUM(CASE WHEN NOT has_ai_commits THEN 1 ELSE 0 END) AS non_ai_assisted_issues,

                        -- Cycle Time Calculations
                        AVG(CASE WHEN has_ai_commits THEN
                            days_between(creation_date, resolution_date)
                            ELSE NULL END) AS avg_cycle_time_with_ai,

                        AVG(CASE WHEN NOT has_ai_commits THEN
                            days_between(creation_date, resolution_date)
                            ELSE NULL END) AS avg_cycle_time_without_ai,

                        -- AI Adoption and Impact Percentage
                        CASE
                            WHEN COUNT(*) > 0
                            THEN (SUM(CASE WHEN has_ai_commits THEN 1 ELSE 0 END)::FLOAT / COUNT(*)) * 100
                            ELSE 0
                        END AS ai_adoption_percentage,

                        CASE
                            WHEN AVG(CASE WHEN NOT has_ai_commits THEN days_between(creation_date, resolution_date) ELSE NULL END) > 0
                            THEN (
                                (AVG(CASE WHEN NOT has_ai_commits THEN days_between(creation_date, resolution_date) ELSE NULL END) -
                                 AVG(CASE WHEN has_ai_commits THEN days_between(creation_date, resolution_date) ELSE NULL END)) /
                                AVG(CASE WHEN NOT has_ai_commits THEN days_between(creation_date, resolution_date) ELSE NULL END)
                            ) * 100
                            ELSE 0
                        END AS cycle_time_impact_percentage,

                        -- Metrics JSON Construction
                        json_build_object(
                            'period', json_build_object(
                                'start', current_period,
                                'end', current_period + period_interval - INTERVAL '1 day',
                                'interval', p_interval
                            ),
                            'summary', json_build_object(
                                'totalIssues', COUNT(*),
                                'aiAssistedIssues', SUM(CASE WHEN has_ai_commits THEN 1 ELSE 0 END),
                                'nonAiAssistedIssues', SUM(CASE WHEN NOT has_ai_commits THEN 1 ELSE 0 END)
                            )
                        ) AS metrics_json
                    FROM
                        period_issues
                )
                SELECT
                    total_issues,
                    ai_assisted_issues,
                    non_ai_assisted_issues,
                    COALESCE(avg_cycle_time_with_ai, 0) AS avg_cycle_time_with_ai,
                    COALESCE(avg_cycle_time_without_ai, 0) AS avg_cycle_time_without_ai,
                    COALESCE(cycle_time_impact_percentage, 0) AS cycle_time_impact_percentage,
                    COALESCE(ai_adoption_percentage, 0) AS ai_adoption_percentage,
                    metrics_json
                INTO impact_metrics
                FROM metrics_calculation;

                -- Comprehensive Insertion with Full Column Mapping
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
                    impact_metrics.total_issues,
                    impact_metrics.ai_assisted_issues,
                    impact_metrics.non_ai_assisted_issues,
                    impact_metrics.avg_cycle_time_with_ai,
                    impact_metrics.avg_cycle_time_without_ai,
                    impact_metrics.cycle_time_impact_percentage,
                    impact_metrics.ai_adoption_percentage,
                    CURRENT_TIMESTAMP,
                    impact_metrics.metrics_json
                )
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

                processed_count := processed_count + 1;
                EXIT;  -- Success, exit retry loop

            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'Error processing period %: %',
                    current_period, SQLERRM;

                IF retry_count = p_max_retries THEN
                    RAISE EXCEPTION 'Failed to process period % after % attempts',
                        current_period, p_max_retries;
                END IF;

                PERFORM pg_sleep(1);  -- Wait before retry
            END;
        END LOOP;

        -- Move to next period
        current_period := current_period + period_interval;
    END LOOP;

    -- Cleanup and final logging
    RESET work_mem;
    RESET maintenance_work_mem;
    RESET temp_buffers;

    RAISE NOTICE 'Successfully processed % time periods', processed_count;
END;
$$ LANGUAGE plpgsql;