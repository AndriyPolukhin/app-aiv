-- 3. **Optimized Metrics Retrieval Function**
CREATE OR REPLACE FUNCTION get_author_metrics_optimized(
    p_max_age_hours INTEGER DEFAULT 24,
    p_force_refresh BOOLEAN DEFAULT FALSE,
    p_author_id INTEGER DEFAULT NULL,
    p_limit INTEGER DEFAULT NULL,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    author_id INTEGER,
    metrics JSON
) AS $$
BEGIN
    -- Intelligent Metrics Refresh Mechanism
    IF p_force_refresh OR EXISTS (
        SELECT 1 FROM jira_issues ji
        LEFT JOIN author_metrics_materialized am ON ji.author_id = am.author_id
        WHERE (p_author_id IS NULL OR ji.author_id = p_author_id)
        AND (am.author_id IS NULL OR am.last_calculated < (NOW() - (p_max_age_hours || ' hours')::INTERVAL))
        LIMIT 1
    ) THEN
        PERFORM refresh_author_metrics(p_author_id);
    END IF;

    -- Paginated Metrics Retrieval
    RETURN QUERY
    SELECT
        am.author_id,
        json_build_object(
            'metrics', json_build_object(
                'totalIssuesAnalyzed', am.total_issues,
                'issuesWithAi', am.issues_with_ai,
                'issuesWithoutAi', am.issues_without_ai,
                'avgCycleTimeWithAi', am.avg_cycle_time_with_ai,
                'avgCycleTimeWithoutAi', am.avg_cycle_time_without_ai,
                'cycleTimeImpactPercentage', am.cycle_time_impact_percentage,
                'efficiencyScore', am.efficiency_score,
                'lastUpdated', am.last_calculated
            ),
            'detailedStats', am.metrics_json->'detailedStats'
        ) AS metrics
    FROM
        author_metrics_materialized am
    WHERE
        (p_author_id IS NULL OR am.author_id = p_author_id)
    ORDER BY
        am.author_id
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;