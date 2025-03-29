CREATE OR REPLACE FUNCTION get_team_metrics_optimized(
    p_max_age_hours INTEGER DEFAULT 24,
    p_force_refresh BOOLEAN DEFAULT FALSE
)
RETURNS SETOF JSON AS $$
DECLARE
    refresh_cutoff TIMESTAMP;
    team_record RECORD;
    team_info RECORD;
BEGIN
    refresh_cutoff := CURRENT_TIMESTAMP - (p_max_age_hours || ' hours')::INTERVAL;

    -- Refresh metrics if stale or forced
    IF p_force_refresh THEN
        PERFORM refresh_team_metrics();
    ELSE
        -- Selectively refresh stale team metrics
        FOR team_record IN
            SELECT team_id
            FROM teams t
            LEFT JOIN team_metrics_materialized tm ON t.team_id = tm.team_id
            WHERE tm.team_id IS NULL OR tm.last_calculated < refresh_cutoff
        LOOP
            PERFORM refresh_team_metrics(team_record.team_id);
        END LOOP;
    END IF;

    -- Return materialized metrics joined with team info
    FOR team_record IN
        SELECT
            json_build_object(
                'teamId', tm.team_id,
                'teamName', t.team_name,
                'engineerCount', array_length(string_to_array(t.engineer_ids, ','), 1),
                'totalIssuesAnalyzed', tm.total_issues,
                'issuesWithAi', tm.issues_with_ai,
                'issuesWithoutAi', tm.issues_without_ai,
                'avgCycleTimeWithAi', tm.avg_cycle_time_with_ai,
                'avgCycleTimeWithoutAi', tm.avg_cycle_time_without_ai,
                'cycleTimeImpactPercentage', tm.cycle_time_impact_percentage,
                'aiAdoptionRate', tm.ai_adoption_rate,
                'topCategories', tm.top_categories,
                'lastUpdated', tm.last_calculated
            ) AS team_metrics_json
        FROM
            team_metrics_materialized tm
            JOIN teams t ON tm.team_id = t.team_id
        ORDER BY
            tm.team_id
    LOOP
        RETURN NEXT team_record.team_metrics_json;
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;