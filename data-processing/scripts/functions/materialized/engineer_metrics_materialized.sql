BEGIN;

-- 1. Create optimized table structure with storage parameters
CREATE TABLE IF NOT EXISTS engineer_metrics_materialized (
    engineer_id INTEGER PRIMARY KEY,
    total_issues_analyzed INTEGER NOT NULL,
    issues_with_ai INTEGER NOT NULL,
    issues_without_ai INTEGER NOT NULL,
    avg_cycle_time_with_ai FLOAT NOT NULL,
    avg_cycle_time_without_ai FLOAT NOT NULL,
    cycle_time_impact_percentage FLOAT NOT NULL,
    avg_commits_with_ai FLOAT NOT NULL,
    avg_commits_without_ai FLOAT NOT NULL,
    efficiency_score FLOAT NOT NULL,
    last_calculated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metrics_json JSON NOT NULL
) WITH (autovacuum_enabled = true, toast.autovacuum_enabled = true);

-- 2. Create optimized refresh function with batch processing
CREATE OR REPLACE FUNCTION refresh_engineer_metrics(
    p_engineer_id INTEGER DEFAULT NULL,
    p_batch_size INTEGER DEFAULT 1000
)
RETURNS VOID AS $$
DECLARE
    engineer_batch RECORD;
    processed_count INTEGER := 0;
    impact_data JSON;
    efficiency_score FLOAT;
BEGIN
    -- Process engineers in batches
    FOR engineer_batch IN
        SELECT DISTINCT engineer_id
        FROM commits
        WHERE (p_engineer_id IS NULL OR engineer_id = p_engineer_id)
        ORDER BY engineer_id
    LOOP
        -- Create optimized temporary tables
        CREATE TEMPORARY TABLE IF NOT EXISTS temp_engineer_commits (
            commit_id TEXT,
            jira_issue_id TEXT,
            commit_date TIMESTAMP,
            ai_used BOOLEAN,
            lines_of_code INTEGER
        ) ON COMMIT DROP;

        CREATE TEMPORARY TABLE IF NOT EXISTS temp_engineer_issues (
            issue_id TEXT,
            has_ai_commits BOOLEAN,
            total_commits INTEGER,
            ai_commits INTEGER,
            non_ai_commits INTEGER,
            cycle_time FLOAT
        ) ON COMMIT DROP;

        -- Batch insert commits for this engineer
        INSERT INTO temp_engineer_commits
        SELECT
            commit_id,
            jira_issue_id,
            commit_date,
            ai_used,
            lines_of_code
        FROM
            commits
        WHERE
            engineer_id = engineer_batch.engineer_id;

        -- Optimized issue data collection
        INSERT INTO temp_engineer_issues
        WITH issue_stats AS (
            SELECT
                ji.issue_id,
                BOOL_OR(ec.ai_used) AS has_ai_commits,
                COUNT(*) AS total_commits,
                COUNT(*) FILTER (WHERE ec.ai_used) AS ai_commits,
                COUNT(*) FILTER (WHERE NOT ec.ai_used) AS non_ai_commits,
                MIN(ec.commit_date) AS first_commit_date,
                ji.resolution_date
            FROM
                jira_issues ji
            JOIN
                temp_engineer_commits ec ON ji.issue_id = ec.jira_issue_id
            WHERE
                ji.resolution_date IS NOT NULL
            GROUP BY ji.issue_id, ji.resolution_date
        )
        SELECT
            issue_id,
            has_ai_commits,
            total_commits,
            ai_commits,
            non_ai_commits,
            EXTRACT(EPOCH FROM (resolution_date - first_commit_date))/86400 AS cycle_time
        FROM
            issue_stats;

        -- Calculate metrics
        WITH aggregated AS (
            SELECT
                COUNT(*) FILTER (WHERE has_ai_commits) AS ai_issues,
                COUNT(*) FILTER (WHERE NOT has_ai_commits) AS non_ai_issues,
                AVG(cycle_time) FILTER (WHERE has_ai_commits) AS avg_ai_cycle,
                AVG(cycle_time) FILTER (WHERE NOT has_ai_commits) AS avg_non_ai_cycle,
                AVG(total_commits) FILTER (WHERE has_ai_commits) AS avg_ai_commits,
                AVG(total_commits) FILTER (WHERE NOT has_ai_commits) AS avg_non_ai_commits
            FROM temp_engineer_issues
        ),
        impact_calc AS (
            SELECT
                *,
                CASE
                    WHEN avg_non_ai_cycle > 0 THEN
                        ((avg_non_ai_cycle - COALESCE(avg_ai_cycle, 0)) / avg_non_ai_cycle) * 100
                    ELSE 0
                END AS impact_percentage
            FROM aggregated
        ),
        detailed_stats AS (
            SELECT
                json_build_object(
                    'withAiIssues', COALESCE(
                        json_agg(
                            json_build_object(
                                'issueId', issue_id,
                                'cycleTime', cycle_time,
                                'totalCommits', total_commits,
                                'aiCommits', ai_commits,
                                'nonAiCommits', non_ai_commits
                            ) FILTER (WHERE has_ai_commits)
                        , '[]'::json
                    ),
                    'withoutAiIssues', COALESCE(
                        json_agg(
                            json_build_object(
                                'issueId', issue_id,
                                'cycleTime', cycle_time,
                                'totalCommits', total_commits,
                                'aiCommits', ai_commits,
                                'nonAiCommits', non_ai_commits
                            ) FILTER (WHERE NOT has_ai_commits)
                        , '[]'::json)
                    )
                ) AS stats
            FROM temp_engineer_issues
        )
        SELECT
            json_build_object(
                'summary', json_build_object(
                    'totalIssuesAnalyzed', (ai_issues + non_ai_issues),
                    'issuesWithAi', ai_issues,
                    'issuesWithoutAi', non_ai_issues,
                    'avgCycleTimeWithAi', COALESCE(avg_ai_cycle, 0),
                    'avgCycleTimeWithoutAi', COALESCE(avg_non_ai_cycle, 0),
                    'cycleTimeImpactPercentage', impact_percentage,
                    'avgCommitsWithAi', COALESCE(avg_ai_commits, 0),
                    'avgCommitsWithoutAi', COALESCE(avg_non_ai_commits, 0)
                ),
                'detailedStats', stats
            ),
            LEAST(100, GREATEST(0,
                (impact_percentage * 0.7) +
                CASE
                    WHEN avg_non_ai_commits > 0 THEN
                        (COALESCE(avg_ai_commits, 0) / avg_non_ai_commits) * 30
                    ELSE 30
                END
            ))
        INTO
            impact_data,
            efficiency_score
        FROM impact_calc, detailed_stats;

        -- Upsert metrics
        INSERT INTO engineer_metrics_materialized (
            engineer_id, total_issues_analyzed, issues_with_ai, issues_without_ai,
            avg_cycle_time_with_ai, avg_cycle_time_without_ai,
            cycle_time_impact_percentage, avg_commits_with_ai, avg_commits_without_ai,
            efficiency_score, last_calculated, metrics_json
        ) VALUES (
            engineer_batch.engineer_id,
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

        -- Batch commit and progress tracking
        processed_count := processed_count + 1;
        IF processed_count % p_batch_size = 0 THEN
            COMMIT;
            BEGIN;
            RAISE NOTICE 'Processed % engineers', processed_count;
        END IF;
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;

-- 3. Create optimized retrieval function with pagination
CREATE OR REPLACE FUNCTION get_engineer_metrics_optimized(
    p_max_age_hours INTEGER DEFAULT 24,
    p_force_refresh BOOLEAN DEFAULT FALSE,
    p_engineer_id INTEGER DEFAULT NULL,
    p_limit INTEGER DEFAULT NULL,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    engineer_id INTEGER,
    metrics JSON
) AS $$
BEGIN
    -- Refresh stale metrics if needed
    IF p_force_refresh OR EXISTS (
        SELECT 1 FROM commits c
        LEFT JOIN engineer_metrics_materialized em ON c.engineer_id = em.engineer_id
        WHERE (p_engineer_id IS NULL OR c.engineer_id = p_engineer_id)
        AND (em.engineer_id IS NULL OR em.last_calculated < (NOW() - (p_max_age_hours || ' hours')::INTERVAL))
        LIMIT 1
    ) THEN
        PERFORM refresh_engineer_metrics(p_engineer_id);
    END IF;

    -- Return paginated results
    RETURN QUERY
    SELECT
        em.engineer_id,
        json_build_object(
            'metrics', json_build_object(
                'totalIssuesAnalyzed', em.total_issues_analyzed,
                'issuesWithAi', em.issues_with_ai,
                'issuesWithoutAi', em.issues_without_ai,
                'avgCycleTimeWithAi', em.avg_cycle_time_with_ai,
                'avgCycleTimeWithoutAi', em.avg_cycle_time_without_ai,
                'cycleTimeImpactPercentage', em.cycle_time_impact_percentage,
                'avgCommitsWithAi', em.avg_commits_with_ai,
                'avgCommitsWithoutAi', em.avg_commits_without_ai,
                'efficiencyScore', em.efficiency_score,
                'lastUpdated', em.last_calculated
            ),
            'detailedStats', em.metrics_json->'detailedStats'
        ) AS metrics
    FROM
        engineer_metrics_materialized em
    WHERE
        (p_engineer_id IS NULL OR em.engineer_id = p_engineer_id)
    ORDER BY
        em.engineer_id
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- 5. Create indexes concurrently after data load
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_engineer_metrics_engineer_id ON engineer_metrics_materialized(engineer_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_engineer_metrics_last_calculated ON engineer_metrics_materialized(last_calculated);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_engineer_metrics_efficiency ON engineer_metrics_materialized(efficiency_score);

-- 6. Analyze table for optimal query planning
ANALYZE engineer_metrics_materialized;

COMMIT;