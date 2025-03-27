CREATE OR REPLACE FUNCTION refresh_engineer_metrics(p_engineer_id INTEGER DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
    engineer_record RECORD;
    impact_data JSON;
BEGIN
    -- Process all engineers or just one specific engineer
    FOR engineer_record IN
        SELECT DISTINCT engineer_id
        FROM commits
        WHERE (p_engineer_id IS NULL OR engineer_id = p_engineer_id)
    LOOP
        -- Calculate metrics using existing function
        SELECT calculate_ai_impact(NULL, NULL, engineer_record.engineer_id, NULL) INTO impact_data;

        -- Calculate an efficiency score (example formula)
        DECLARE
            efficiency_score FLOAT;
            cycle_time_impact FLOAT;
            commit_ratio FLOAT;
        BEGIN
            cycle_time_impact := (impact_data->'summary'->>'cycleTimeImpactPercentage')::FLOAT;
            commit_ratio :=
                CASE WHEN (impact_data->'summary'->>'avgCommitsWithoutAi')::FLOAT > 0
                THEN (impact_data->'summary'->>'avgCommitsWithAi')::FLOAT /
                     (impact_data->'summary'->>'avgCommitsWithoutAi')::FLOAT
                ELSE 1 END;

            -- Efficiency score formula (can be adjusted based on business requirements)
            efficiency_score := (cycle_time_impact * 0.7) + (commit_ratio * 30);
            IF efficiency_score < 0 THEN efficiency_score := 0; END IF;
            IF efficiency_score > 100 THEN efficiency_score := 100; END IF;

            -- Insert or update materialized metrics
            INSERT INTO engineer_metrics_materialized (
                engineer_id,
                total_issues_analyzed,
                issues_with_ai,
                issues_without_ai,
                avg_cycle_time_with_ai,
                avg_cycle_time_without_ai,
                cycle_time_impact_percentage,
                avg_commits_with_ai,
                avg_commits_without_ai,
                efficiency_score,
                last_calculated,
                metrics_json
            ) VALUES (
                engineer_record.engineer_id,
                (impact_data->'summary'->>'totalIssuesAnalyzed')::INTEGER,
                (impact_data->'summary'->>'issuesWithAi')::INTEGER,
                (impact_data->'summary'->>'issuesWithoutAi')::INTEGER,
                (impact_data->'summary'->>'avgCycleTimeWithAi')::FLOAT,
                (impact_data->'summary'->>'avgCycleTimeWithoutAi')::FLOAT,
                (impact_data->'summary'->>'cycleTimeImpactPercentage')::FLOAT,
                (impact_data->'summary'->>'avgCommitsWithAi')::FLOAT,
                (impact_data->'summary'->>'avgCommitsWithoutAi')::FLOAT,
                efficiency_score,
                CURRENT_TIMESTAMP,
                impact_data
            )
            ON CONFLICT (engineer_id) DO UPDATE SET
                total_issues_analyzed = EXCLUDED.total_issues_analyzed,
                issues_with_ai = EXCLUDED.issues_with_ai,
                issues_without_ai = EXCLUDED.issues_without_ai,
                avg_cycle_time_with_ai = EXCLUDED.avg_cycle_time_with_ai,
                avg_cycle_time_without_ai = EXCLUDED.avg_cycle_time_without_ai,
                cycle_time_impact_percentage = EXCLUDED.cycle_time_impact_percentage,
                avg_commits_with_ai = EXCLUDED.avg_commits_with_ai,
                avg_commits_without_ai = EXCLUDED.avg_commits_without_ai,
                efficiency_score = EXCLUDED.efficiency_score,
                last_calculated = EXCLUDED.last_calculated,
                metrics_json = EXCLUDED.metrics_json;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;