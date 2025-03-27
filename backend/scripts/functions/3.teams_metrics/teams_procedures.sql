CREATE OR REPLACE PROCEDURE refresh_team_metrics()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Refresh materialized table
    INSERT INTO team_metrics_materialized (
        team_id,
        total_issues,
        issues_with_ai,
        issues_without_ai,
        avg_cycle_time_with_ai,
        avg_cycle_time_without_ai,
        cycle_time_impact_percentage,
        ai_adoption_rate,
        top_categories,
        last_calculated,
        metrics_json
    )
    SELECT
        team_id,
        total_issues,
        issues_with_ai,
        issues_without_ai,
        avg_cycle_time_with_ai,
        avg_cycle_time_without_ai,
        cycle_time_impact_percentage,
        ai_adoption_rate,
        top_categories,
        CURRENT_TIMESTAMP,
        json_build_object(
            'summary', json_build_object(
                'totalIssuesAnalyzed', total_issues,
                'issuesWithAi', issues_with_ai,
                'issuesWithoutAi', issues_without_ai,
                'avgCycleTimeWithAi', avg_cycle_time_with_ai,
                'avgCycleTimeWithoutAi', avg_cycle_time_without_ai,
                'cycleTimeImpactPercentage', cycle_time_impact_percentage,
                'aiAdoptionRate', ai_adoption_rate
            ),
            'categories', top_categories
        )
    FROM
        team_metrics_view
    ON CONFLICT (team_id) DO UPDATE SET
        total_issues = EXCLUDED.total_issues,
        issues_with_ai = EXCLUDED.issues_with_ai,
        issues_without_ai = EXCLUDED.issues_without_ai,
        avg_cycle_time_with_ai = EXCLUDED.avg_cycle_time_with_ai,
        avg_cycle_time_without_ai = EXCLUDED.avg_cycle_time_without_ai,
        cycle_time_impact_percentage = EXCLUDED.cycle_time_impact_percentage,
        ai_adoption_rate = EXCLUDED.ai_adoption_rate,
        top_categories = EXCLUDED.top_categories,
        last_calculated = EXCLUDED.last_calculated,
        metrics_json = EXCLUDED.metrics_json;
END;
$$;



CREATE OR REPLACE PROCEDURE get_team_metrics(
    p_max_age_hours INTEGER DEFAULT 24,
    p_force_refresh BOOLEAN DEFAULT FALSE
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Refresh metrics if stale or forced
    IF p_force_refresh THEN
        CALL refresh_team_metrics();
    ELSE
        PERFORM refresh_team_metrics()
        WHERE EXISTS (
            SELECT 1
            FROM team_metrics_materialized
            WHERE last_calculated < CURRENT_TIMESTAMP - (p_max_age_hours || ' hours')::INTERVAL
        );
    END IF;

    -- Return metrics
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
    JOIN
        teams t ON tm.team_id = t.team_id
    ORDER BY
        tm.team_id;
END;
$$;