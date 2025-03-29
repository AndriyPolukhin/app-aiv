BEGIN;

-- 1. Create optimized table structure with storage parameters
CREATE TABLE IF NOT EXISTS category_metrics_materialized (
    category TEXT PRIMARY KEY,
    total_issues INTEGER NOT NULL,
    issues_with_ai INTEGER NOT NULL,
    issues_without_ai INTEGER NOT NULL,
    avg_cycle_time_with_ai FLOAT NOT NULL,
    avg_cycle_time_without_ai FLOAT NOT NULL,
    cycle_time_impact_percentage FLOAT NOT NULL,
    avg_commits_with_ai FLOAT NOT NULL,
    avg_commits_without_ai FLOAT NOT NULL,
    last_calculated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metrics_json JSON NOT NULL
) WITH (autovacuum_enabled = true, toast.autovacuum_enabled = true);

-- 2. Create optimized refresh function with batch processing
CREATE OR REPLACE FUNCTION refresh_category_metrics(
    p_category TEXT DEFAULT NULL,
    p_batch_size INTEGER DEFAULT 100
)
RETURNS VOID AS $$
DECLARE
    category_batch RECORD;
    processed_count INTEGER := 0;
    impact_percentage FLOAT;
    metrics_json JSON;
BEGIN
    -- Process categories in batches
    FOR category_batch IN
        SELECT DISTINCT category
        FROM jira_issues
        WHERE (p_category IS NULL OR category = p_category)
        ORDER BY category
    LOOP
        -- Create optimized temporary tables (UNLOGGED for better performance)
        CREATE TEMPORARY TABLE IF NOT EXISTS temp_category_commits (
            commit_id TEXT,
            jira_issue_id TEXT,
            commit_date TIMESTAMP,
            ai_used BOOLEAN,
            lines_of_code INTEGER
        ) ON COMMIT DROP;

        CREATE TEMPORARY TABLE IF NOT EXISTS temp_category_issues (
            issue_id TEXT,
            has_ai BOOLEAN,
            total_commits INTEGER,
            ai_commits INTEGER,
            non_ai_commits INTEGER,
            cycle_time FLOAT
        ) ON COMMIT DROP;

        -- Batch insert with direct join (faster than EXISTS subquery)
        INSERT INTO temp_category_commits
        SELECT
            c.commit_id,
            c.jira_issue_id,
            c.commit_date,
            c.ai_used,
            c.lines_of_code
        FROM
            commits c
        JOIN
            jira_issues ji ON ji.issue_id = c.jira_issue_id
        WHERE
            ji.category = category_batch.category;

        -- Optimized issue data collection with window functions
        INSERT INTO temp_category_issues
        WITH issue_stats AS (
            SELECT
                ji.issue_id,
                BOOL_OR(c.ai_used) AS has_ai,
                COUNT(*) AS total_commits,
                COUNT(*) FILTER (WHERE c.ai_used) AS ai_commits,
                COUNT(*) FILTER (WHERE NOT c.ai_used) AS non_ai_commits,
                MIN(c.commit_date) AS first_commit_date,
                ji.resolution_date
            FROM
                jira_issues ji
            JOIN
                temp_category_commits c ON ji.issue_id = c.jira_issue_id
            WHERE
                ji.category = category_batch.category
                AND ji.resolution_date IS NOT NULL
            GROUP BY ji.issue_id, ji.resolution_date
        )
        SELECT
            issue_id,
            has_ai,
            total_commits,
            ai_commits,
            non_ai_commits,
            EXTRACT(EPOCH FROM (resolution_date - first_commit_date))/86400 AS cycle_time
        FROM
            issue_stats;

        -- Calculate metrics with optimized aggregation
        WITH aggregated AS (
            SELECT
                COUNT(*) FILTER (WHERE has_ai) AS ai_issues,
                COUNT(*) FILTER (WHERE NOT has_ai) AS non_ai_issues,
                AVG(cycle_time) FILTER (WHERE has_ai) AS avg_ai_cycle,
                AVG(cycle_time) FILTER (WHERE NOT has_ai) AS avg_non_ai_cycle,
                AVG(total_commits) FILTER (WHERE has_ai) AS avg_ai_commits,
                AVG(total_commits) FILTER (WHERE NOT has_ai) AS avg_non_ai_commits
            FROM temp_category_issues
        ),
        impact_calc AS (
            SELECT
                *,
                CASE WHEN avg_non_ai_cycle > 0
                     THEN ((avg_non_ai_cycle - COALESCE(avg_ai_cycle, 0)) / avg_non_ai_cycle * 100
                     ELSE 0 END AS impact_percentage
            FROM aggregated
        )
        SELECT
            ai_issues + non_ai_issues,
            ai_issues,
            non_ai_issues,
            COALESCE(avg_ai_cycle, 0),
            COALESCE(avg_non_ai_cycle, 0),
            impact_percentage,
            COALESCE(avg_ai_commits, 0),
            COALESCE(avg_non_ai_commits, 0),
            json_build_object(
                'summary', json_build_object(
                    'totalIssues', ai_issues + non_ai_issues,
                    'issuesWithAi', ai_issues,
                    'issuesWithoutAi', non_ai_issues,
                    'avgCycleTimeWithAi', COALESCE(avg_ai_cycle, 0),
                    'avgCycleTimeWithoutAi', COALESCE(avg_non_ai_cycle, 0),
                    'cycleTimeImpactPercentage', impact_percentage,
                    'avgCommitsWithAi', COALESCE(avg_ai_commits, 0),
                    'avgCommitsWithoutAi', COALESCE(avg_non_ai_commits, 0)
                ),
                'detailedStats', (
                    SELECT json_build_object(
                        'withAiIssues', COALESCE(json_agg(
                            json_build_object(
                                'issueId', issue_id,
                                'cycleTime', cycle_time,
                                'totalCommits', total_commits,
                                'aiCommits', ai_commits,
                                'nonAiCommits', non_ai_commits
                            ) FILTER (WHERE has_ai), '[]'),
                        'withoutAiIssues', COALESCE(json_agg(
                            json_build_object(
                                'issueId', issue_id,
                                'cycleTime', cycle_time,
                                'totalCommits', total_commits,
                                'aiCommits', ai_commits,
                                'nonAiCommits', non_ai_commits
                            ) FILTER (WHERE NOT has_ai), '[]')
                    )
                    FROM temp_category_issues
                )
            )
        INTO
            total_issues,
            issues_with_ai,
            issues_without_ai,
            avg_cycle_time_with_ai,
            avg_cycle_time_without_ai,
            impact_percentage,
            avg_commits_with_ai,
            avg_commits_without_ai,
            metrics_json
        FROM impact_calc;

        -- Upsert metrics
        INSERT INTO category_metrics_materialized (
            category, total_issues, issues_with_ai, issues_without_ai,
            avg_cycle_time_with_ai, avg_cycle_time_without_ai,
            cycle_time_impact_percentage, avg_commits_with_ai, avg_commits_without_ai,
            last_calculated, metrics_json
        ) VALUES (
            category_batch.category,
            total_issues,
            issues_with_ai,
            issues_without_ai,
            avg_cycle_time_with_ai,
            avg_cycle_time_without_ai,
            impact_percentage,
            avg_commits_with_ai,
            avg_commits_without_ai,
            CURRENT_TIMESTAMP,
            metrics_json
        )
        ON CONFLICT (category) DO UPDATE SET
            total_issues = EXCLUDED.total_issues,
            issues_with_ai = EXCLUDED.issues_with_ai,
            issues_without_ai = EXCLUDED.issues_without_ai,
            avg_cycle_time_with_ai = EXCLUDED.avg_cycle_time_with_ai,
            avg_cycle_time_without_ai = EXCLUDED.avg_cycle_time_without_ai,
            cycle_time_impact_percentage = EXCLUDED.cycle_time_impact_percentage,
            avg_commits_with_ai = EXCLUDED.avg_commits_with_ai,
            avg_commits_without_ai = EXCLUDED.avg_commits_without_ai,
            last_calculated = EXCLUDED.last_calculated,
            metrics_json = EXCLUDED.metrics_json;

        -- Batch commit and progress tracking
        processed_count := processed_count + 1;
        IF processed_count % p_batch_size = 0 THEN
            COMMIT;
            BEGIN;
            RAISE NOTICE 'Processed % categories', processed_count;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 3. Create optimized retrieval function with pagination
CREATE OR REPLACE FUNCTION get_category_metrics_optimized(
    p_max_age_hours INTEGER DEFAULT 24,
    p_force_refresh BOOLEAN DEFAULT FALSE,
    p_category TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT NULL,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    category TEXT,
    metrics JSON
) AS $$
BEGIN
    -- Refresh stale metrics if needed
    IF p_force_refresh OR EXISTS (
        SELECT 1 FROM jira_issues ji
        LEFT JOIN category_metrics_materialized cm ON ji.category = cm.category
        WHERE (p_category IS NULL OR ji.category = p_category)
        AND (cm.category IS NULL OR cm.last_calculated < (NOW() - (p_max_age_hours || ' hours')::INTERVAL))
        LIMIT 1
    ) THEN
        PERFORM refresh_category_metrics(p_category);
    END IF;

    -- Return paginated results
    RETURN QUERY
    SELECT
        cm.category,
        json_build_object(
            'metrics', json_build_object(
                'totalIssues', cm.total_issues,
                'issuesWithAi', cm.issues_with_ai,
                'issuesWithoutAi', cm.issues_without_ai,
                'avgCycleTimeWithAi', cm.avg_cycle_time_with_ai,
                'avgCycleTimeWithoutAi', cm.avg_cycle_time_without_ai,
                'cycleTimeImpactPercentage', cm.cycle_time_impact_percentage,
                'avgCommitsWithAi', cm.avg_commits_with_ai,
                'avgCommitsWithoutAi', cm.avg_commits_without_ai,
                'lastUpdated', cm.last_calculated
            ),
            'detailedStats', cm.metrics_json->'detailedStats'
        ) AS metrics
    FROM
        category_metrics_materialized cm
    WHERE
        (p_category IS NULL OR cm.category = p_category)
    ORDER BY
        cm.category
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- 4. Initial data load in batches
DO $$
DECLARE
    total_categories INTEGER;
    batch_size INTEGER := 100;
    batches INTEGER;
BEGIN
    SELECT COUNT(DISTINCT category) INTO total_categories FROM jira_issues;
    batches := CEIL(total_categories::FLOAT / batch_size);

    FOR i IN 0..batches-1 LOOP
        RAISE NOTICE 'Processing batch % of %', i+1, batches;
        PERFORM refresh_category_metrics(NULL, batch_size);
        COMMIT;
        BEGIN;
    END LOOP;
END $$;

-- 5. Create indexes concurrently after data load
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_category_metrics_category ON category_metrics_materialized(category);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_category_metrics_last_calculated ON category_metrics_materialized(last_calculated);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_category_metrics_impact ON category_metrics_materialized(cycle_time_impact_percentage);

-- 6. Analyze table for optimal query planning
ANALYZE category_metrics_materialized;

COMMIT;