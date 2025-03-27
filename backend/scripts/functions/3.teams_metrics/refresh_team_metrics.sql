CREATE OR REPLACE FUNCTION refresh_team_metrics(p_team_id INTEGER DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
    team_record RECORD;
    impact_data JSON;
BEGIN
    -- Process all teams or just one specific team
    FOR team_record IN
        SELECT team_id
        FROM teams
        WHERE (p_team_id IS NULL OR team_id = p_team_id)
    LOOP
        -- Calculate metrics using existing function
        SELECT calculate_ai_impact(NULL, NULL, NULL, team_record.team_id) INTO impact_data;

        -- Insert or update materialized metrics
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
        ) VALUES (
            team_record.team_id,
            (impact_data->'summary'->>'totalIssuesAnalyzed')::INTEGER,
            (impact_data->'summary'->>'issuesWithAi')::INTEGER,
            (impact_data->'summary'->>'issuesWithoutAi')::INTEGER,
            (impact_data->'summary'->>'avgCycleTimeWithAi')::FLOAT,
            (impact_data->'summary'->>'avgCycleTimeWithoutAi')::FLOAT,
            (impact_data->'summary'->>'cycleTimeImpactPercentage')::FLOAT,
            CASE
                WHEN (impact_data->'summary'->>'totalIssuesAnalyzed')::INTEGER > 0
                THEN (impact_data->'summary'->>'issuesWithAi')::FLOAT / (impact_data->'summary'->>'totalIssuesAnalyzed')::FLOAT
                ELSE 0
            END,
            COALESCE(impact_data->'categories', '[]'::JSON),
            CURRENT_TIMESTAMP,
            impact_data
        )
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
    END LOOP;
END;
$$ LANGUAGE plpgsql;