CREATE OR REPLACE FUNCTION get_category_metrics_optimized(
    p_max_age_hours INTEGER DEFAULT 24,
    p_force_refresh BOOLEAN DEFAULT FALSE,
    p_category TEXT DEFAULT NULL
)
RETURNS SETOF JSON AS $$
DECLARE
    refresh_cutoff TIMESTAMP;
    category_record RECORD;
BEGIN
    refresh_cutoff := CURRENT_TIMESTAMP - (p_max_age_hours || ' hours')::INTERVAL;

    -- Refresh metrics if stale or forced
    IF p_force_refresh THEN
        PERFORM refresh_category_metrics(p_category);
    ELSE
        -- Selectively refresh stale category metrics
        FOR category_record IN
            SELECT DISTINCT j.category
            FROM jira_issues j
            LEFT JOIN category_metrics_materialized cm ON j.category = cm.category
            WHERE (p_category IS NULL OR j.category = p_category)
            AND (cm.category IS NULL OR cm.last_calculated < refresh_cutoff)
        LOOP
            PERFORM refresh_category_metrics(category_record.category);
        END LOOP;
    END IF;

    -- Return materialized metrics
    FOR category_record IN
        SELECT
            json_build_object(
                'category', category,
                'totalIssues', total_issues,
                'issuesWithAi', issues_with_ai,
                'issuesWithoutAi', issues_without_ai,
                'avgCycleTimeWithAi', avg_cycle_time_with_ai,
                'avgCycleTimeWithoutAi', avg_cycle_time_without_ai,
                'cycleTimeImpactPercentage', cycle_time_impact_percentage,
                'avgCommitsWithAi', avg_commits_with_ai,
                'avgCommitsWithoutAi', avg_commits_without_ai,
                'lastUpdated', last_calculated,
                'detailedStats', metrics_json->'detailedStats'
            ) AS category_metrics_json
        FROM
            category_metrics_materialized
        WHERE
            (p_category IS NULL OR category = p_category)
        ORDER BY
            category
    LOOP
        RETURN NEXT category_record.category_metrics_json;
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;