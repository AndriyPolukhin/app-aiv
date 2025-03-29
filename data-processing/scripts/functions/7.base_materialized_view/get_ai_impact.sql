CREATE OR REPLACE FUNCTION get_ai_impact(
    p_project_id INTEGER DEFAULT NULL,
    p_author_id INTEGER DEFAULT NULL,
    p_engineer_id INTEGER DEFAULT NULL,
    p_team_id INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    result_json JSON;
BEGIN
    WITH filtered_data AS (
        SELECT *
        FROM vw_ai_impact
        WHERE
            (p_project_id IS NULL OR project_id = p_project_id)
            AND (p_author_id IS NULL OR author_id = p_author_id)
            AND (p_team_id IS NULL OR p_team_id = ANY(team_ids))
            AND (p_engineer_id IS NULL OR engineer_id = p_engineer_id)
    )
    SELECT
        json_build_object(
            'summary', json_build_object(
                'totalIssuesAnalyzed', COUNT(*),
                'issuesWithAi', COUNT(*) FILTER (WHERE has_ai_commits),
                'issuesWithoutAi', COUNT(*) FILTER (WHERE NOT has_ai_commits),
                'avgCycleTimeWithAi', COALESCE(AVG(cycle_time) FILTER (WHERE has_ai_commits), 0),
                'avgCycleTimeWithoutAi', COALESCE(AVG(cycle_time) FILTER (WHERE NOT has_ai_commits), 0),
                'cycleTimeImpactPercentage', CASE
                    WHEN AVG(cycle_time) FILTER (WHERE NOT has_ai_commits) > 0
                    THEN ((AVG(cycle_time) FILTER (WHERE NOT has_ai_commits) -
                        AVG(cycle_time) FILTER (WHERE has_ai_commits)) /
                        AVG(cycle_time) FILTER (WHERE NOT has_ai_commits)) * 100
                    ELSE 0 END,
                'avgCommitsWithAi', COALESCE(AVG(total_commits) FILTER (WHERE has_ai_commits), 0),
                'avgCommitsWithoutAi', COALESCE(AVG(total_commits) FILTER (WHERE NOT has_ai_commits), 0)
            ),
            'detailedStats', json_build_object(
                'issuesWithAi', COALESCE(
                    (SELECT json_agg(json_build_object(
                        'issueId', issue_id,
                        'cycleTime', cycle_time,
                        'totalCommits', total_commits,
                        'aiCommits', ai_commits,
                        'nonAiCommits', non_ai_commits,
                        'category', category
                    )) FROM filtered_data WHERE has_ai_commits = true),
                    '[]'::json
                ),
                'issuesWithoutAi', COALESCE(
                    (SELECT json_agg(json_build_object(
                        'issueId', issue_id,
                        'cycleTime', cycle_time,
                        'totalCommits', total_commits,
                        'aiCommits', ai_commits,
                        'nonAiCommits', non_ai_commits,
                        'category', category
                    )) FROM filtered_data WHERE has_ai_commits = false),
                    '[]'::json
                ),
                'categories', json_build_object(
                    'withAi', COALESCE(
                        (SELECT json_object_agg(
                            category,
                            json_build_object(
                                'count', COUNT(*),
                                'avgCycleTime', AVG(cycle_time),
                                'issues', json_agg(json_build_object(
                                    'issueId', issue_id,
                                    'cycleTime', cycle_time
                                ))
                            )
                        ) FROM filtered_data WHERE has_ai_commits = true GROUP BY category),
                        '{}'::json
                    ),
                    'withoutAi', COALESCE(
                        (SELECT json_object_agg(
                            category,
                            json_build_object(
                                'count', COUNT(*),
                                'avgCycleTime', AVG(cycle_time),
                                'issues', json_agg(json_build_object(
                                    'issueId', issue_id,
                                    'cycleTime', cycle_time
                                ))
                            )
                        ) FROM filtered_data WHERE has_ai_commits = false GROUP BY category),
                        '{}'::json
                    )
                )
            )
        )
    INTO result_json
    FROM filtered_data;

    RETURN result_json;
END;
$$ LANGUAGE plpgsql;