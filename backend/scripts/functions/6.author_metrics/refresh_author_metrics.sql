CREATE OR REPLACE FUNCTION refresh_author_metrics(p_author_id INTEGER DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
    author_record RECORD;
    impact_data JSON;
    efficiency_score FLOAT;
BEGIN
    -- Process all authors or just one specific author
    FOR author_record IN
        SELECT DISTINCT author_id
        FROM jira_issues
        WHERE (p_author_id IS NULL OR author_id = p_author_id)
    LOOP
        -- Calculate metrics using existing function
        SELECT calculate_ai_impact(NULL, NULL, author_record.author_id, NULL) INTO impact_data;

        -- Calculate efficiency score
        efficiency_score := LEAST(100, GREATEST(0,
            ((impact_data->'summary'->>'cycleTimeImpactPercentage')::FLOAT * 0.7) +
            CASE WHEN (impact_data->'summary'->>'avgCommitsWithoutAi')::FLOAT > 0 THEN
                (impact_data->'summary'->>'avgCommitsWithAi')::FLOAT /
                (impact_data->'summary'->>'avgCommitsWithoutAi')::FLOAT * 30
            ELSE 30 END
        ));

        -- Insert or update materialized metrics
        INSERT INTO author_metrics_materialized (
            author_id,
            total_issues,
            issues_with_ai,
            issues_without_ai,
            avg_cycle_time_with_ai,
            avg_cycle_time_without_ai,
            cycle_time_impact_percentage,
            efficiency_score,
            last_calculated,
            metrics_json
        ) VALUES (
            author_record.author_id,
            (impact_data->'summary'->>'totalIssuesAnalyzed')::INTEGER,
            (impact_data->'summary'->>'issuesWithAi')::INTEGER,
            (impact_data->'summary'->>'issuesWithoutAi')::INTEGER,
            (impact_data->'summary'->>'avgCycleTimeWithAi')::FLOAT,
            (impact_data->'summary'->>'avgCycleTimeWithoutAi')::FLOAT,
            (impact_data->'summary'->>'cycleTimeImpactPercentage')::FLOAT,
            efficiency_score,
            CURRENT_TIMESTAMP,
            impact_data
        )
        ON CONFLICT (author_id) DO UPDATE SET
            total_issues = EXCLUDED.total_issues,
            issues_with_ai = EXCLUDED.issues_with_ai,
            issues_without_ai = EXCLUDED.issues_without_ai,
            avg_cycle_time_with_ai = EXCLUDED.avg_cycle_time_with_ai,
            avg_cycle_time_without_ai = EXCLUDED.avg_cycle_time_without_ai,
            cycle_time_impact_percentage = EXCLUDED.cycle_time_impact_percentage,
            efficiency_score = EXCLUDED.efficiency_score,
            last_calculated = EXCLUDED.last_calculated,
            metrics_json = EXCLUDED.metrics_json;
    END LOOP;
END;
$$ LANGUAGE plpgsql;