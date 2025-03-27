CREATE OR REPLACE FUNCTION refresh_all_engineer_metrics_optimized()
RETURNS VOID AS $$
DECLARE
    engineer_cursor REFCURSOR;
    engineer_id INTEGER;
    batch_count INTEGER := 0;
    total_engineers INTEGER;
    ctx TEXT;
BEGIN
    SELECT COUNT(DISTINCT engineer_id) INTO total_engineers FROM commits;
    OPEN engineer_cursor FOR SELECT DISTINCT engineer_id FROM commits ORDER BY engineer_id;

    -- Minimal memory baseline
    SET LOCAL work_mem = '4MB';
    SET LOCAL maintenance_work_mem = '8MB';

    LOOP
        FETCH engineer_cursor INTO engineer_id;
        EXIT WHEN NOT FOUND;

        -- Adjust memory based on expected workload
        EXECUTE format('SET LOCAL work_mem = %L',
            CASE
                WHEN (SELECT COUNT(*) FROM commits WHERE engineer_id = engineer_id) > 500 THEN '12MB'
                ELSE '8MB'
            END);

        BEGIN
            -- Process with optimized subfunctions
            PERFORM refresh_engineer_metrics_single(engineer_id);

            batch_count := batch_count + 1;

            -- Aggressive cleanup every 20 engineers
            IF batch_count % 20 = 0 THEN
                PERFORM pg_sleep(0.1);
                FOR ctx IN SELECT name FROM pg_backend_memory_contexts()
                    WHERE name NOT LIKE 'pg_%' AND name != 'TopMemoryContext'
                LOOP
                    EXECUTE format('SELECT pg_backend_memory_context_reset(%L)', ctx);
                END LOOP;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Skipping engineer %: %', engineer_id, SQLERRM;
        END;
    END LOOP;

    CLOSE engineer_cursor;
    RESET work_mem;
    RESET maintenance_work_mem;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION refresh_engineer_metrics_single(p_engineer_id INTEGER)
RETURNS VOID AS $$
DECLARE
    impact_data JSON;
    efficiency_score FLOAT;
    cycle_time_impact FLOAT;
    commit_ratio FLOAT;
    start_time TIMESTAMP := clock_timestamp();
BEGIN
    -- Set conservative memory limits for this operation
    SET LOCAL work_mem = '8MB';
    SET LOCAL maintenance_work_mem = '16MB';
    SET LOCAL temp_buffers = '16MB';

    -- Calculate metrics using materialized CTEs to control memory usage
    WITH MATERIALIZED engineer_commits AS (
        SELECT
            c.commit_id,
            c.jira_issue_id,
            c.commit_date,
            c.ai_used,
            c.lines_of_code,
            ji.resolution_date,
            ji.category
        FROM commits c
        JOIN jira_issues ji ON c.jira_issue_id = ji.issue_id
        WHERE c.engineer_id = p_engineer_id
        AND ji.resolution_date IS NOT NULL
    ,
    issue_stats AS MATERIALIZED (
        SELECT
            jira_issue_id,
            MIN(commit_date) AS first_commit_date,
            MAX(resolution_date) AS resolution_date,
            COUNT(*) FILTER (WHERE ai_used) AS ai_commits,
            COUNT(*) FILTER (WHERE NOT ai_used) AS non_ai_commits,
            COUNT(*) AS total_commits
        FROM engineer_commits
        GROUP BY jira_issue_id
    ),
    aggregated_stats AS MATERIALIZED (
        SELECT
            COUNT(*) AS total_issues,
            COUNT(*) FILTER (WHERE ai_commits > 0) AS ai_issues,
            COUNT(*) FILTER (WHERE ai_commits = 0) AS non_ai_issues,
            AVG(EXTRACT(EPOCH FROM (resolution_date - first_commit_date))/86400)
                FILTER (WHERE ai_commits > 0) AS avg_ai_cycle,
            AVG(EXTRACT(EPOCH FROM (resolution_date - first_commit_date))/86400)
                FILTER (WHERE ai_commits = 0) AS avg_non_ai_cycle,
            AVG(total_commits) FILTER (WHERE ai_commits > 0) AS avg_ai_commits,
            AVG(total_commits) FILTER (WHERE ai_commits = 0) AS avg_non_ai_commits
        FROM issue_stats
    )
    SELECT
        json_build_object(
            'summary', json_build_object(
                'totalIssuesAnalyzed', total_issues,
                'issuesWithAi', ai_issues,
                'issuesWithoutAi', non_ai_issues,
                'avgCycleTimeWithAi', COALESCE(avg_ai_cycle, 0),
                'avgCycleTimeWithoutAi', COALESCE(avg_non_ai_cycle, 0),
                'cycleTimeImpactPercentage', CASE
                    WHEN avg_non_ai_cycle > 0 THEN
                        ((avg_non_ai_cycle - COALESCE(avg_ai_cycle, 0)) / avg_non_ai_cycle * 100)
                    ELSE 0 END,
                'avgCommitsWithAi', COALESCE(avg_ai_commits, 0),
                'avgCommitsWithoutAi', COALESCE(avg_non_ai_commits, 0)
            ),
            'detailedStats', (
                SELECT json_build_object(
                    'withAiIssues', COALESCE(
                        json_agg(
                            json_build_object(
                                'issueId', s.jira_issue_id,
                                'cycleTime', EXTRACT(EPOCH FROM (s.resolution_date - s.first_commit_date))/86400,
                                'totalCommits', s.total_commits,
                                'aiCommits', s.ai_commits,
                                'nonAiCommits', s.non_ai_commits
                            ) FILTER (WHERE s.ai_commits > 0)
                        , '[]'::json)),
                    'withoutAiIssues', COALESCE(
                        json_agg(
                            json_build_object(
                                'issueId', s.jira_issue_id,
                                'cycleTime', EXTRACT(EPOCH FROM (s.resolution_date - s.first_commit_date))/86400,
                                'totalCommits', s.total_commits,
                                'aiCommits', s.ai_commits,
                                'nonAiCommits', s.non_ai_commits
                            ) FILTER (WHERE s.ai_commits = 0)
                        , '[]'::json))
                FROM issue_stats s
                )
            )
        )
    INTO impact_data
    FROM aggregated_stats;

    -- Calculate efficiency score with bounds checking
    cycle_time_impact := (impact_data->'summary'->>'cycleTimeImpactPercentage')::FLOAT;
    commit_ratio := CASE
        WHEN (impact_data->'summary'->>'avgCommitsWithoutAi')::FLOAT > 0 THEN
            (impact_data->'summary'->>'avgCommitsWithAi')::FLOAT /
            (impact_data->'summary'->>'avgCommitsWithoutAi')::FLOAT
        ELSE 1
    END;

    efficiency_score := LEAST(100, GREATEST(0, (cycle_time_impact * 0.7) + (commit_ratio * 30));

    -- Upsert metrics with conflict handling
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
        p_engineer_id,
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

    -- Log performance
    RAISE DEBUG 'Processed engineer % in % ms',
        p_engineer_id,
        EXTRACT(MILLISECONDS FROM (clock_timestamp() - start_time));
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to process engineer %: %', p_engineer_id, SQLERRM;
END;
$$ LANGUAGE plpgsql;