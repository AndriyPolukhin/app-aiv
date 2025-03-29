CREATE OR REPLACE FUNCTION get_project_metrics_optimized(
    p_max_age_hours INTEGER DEFAULT 24,
    p_force_refresh BOOLEAN DEFAULT FALSE,
    p_project_id INTEGER DEFAULT NULL
)
RETURNS SETOF JSON AS $$
DECLARE
    refresh_cutoff TIMESTAMP;
    project_record RECORD;
BEGIN
    refresh_cutoff := CURRENT_TIMESTAMP - (p_max_age_hours || ' hours')::INTERVAL;

    -- Refresh metrics if stale or forced
    IF p_force_refresh THEN
        PERFORM refresh_project_metrics(p_project_id);
    ELSE
        -- Selectively refresh stale project metrics
        FOR project_record IN
            SELECT DISTINCT j.project_id
            FROM jira_issues j
            LEFT JOIN project_metrics_materialized pm ON j.project_id = pm.project_id
            WHERE (p_project_id IS NULL OR j.project_id = p_project_id)
            AND (pm.project_id IS NULL OR pm.last_calculated < refresh_cutoff)
        LOOP
            PERFORM refresh_project_metrics(project_record.project_id);
        END LOOP;
    END IF;

    -- Return materialized metrics
    FOR project_record IN
        SELECT
            json_build_object(
                'projectId', project_id,
                'totalIssuesAnalyzed', total_issues_analyzed,
                'issuesWithAi', issues_with_ai,
                'issuesWithoutAi', issues_without_ai,
                'avgCycleTimeWithAi', avg_cycle_time_with_ai,
                'avgCycleTimeWithoutAi', avg_cycle_time_without_ai,
                'cycleTimeImpactPercentage', cycle_time_impact_percentage,
                'avgCommitsWithAi', avg_commits_with_ai,
                'avgCommitsWithoutAi', avg_commits_without_ai,
                'lastUpdated', last_calculated,
                'detailedStats', metrics_json->'detailedStats'
            ) AS project_metrics_json
        FROM
            project_metrics_materialized
        WHERE
            (p_project_id IS NULL OR project_id = p_project_id)
        ORDER BY
            project_id
    LOOP
        RETURN NEXT project_record.project_metrics_json;
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;