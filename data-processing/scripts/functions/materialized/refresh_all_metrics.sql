------------------------------------------------------------------
-- INTEGRATED REFRESH ORCHESTRATION
------------------------------------------------------------------

CREATE OR REPLACE FUNCTION refresh_all_metrics(
    p_force_full_refresh BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
DECLARE
    stale_threshold TIMESTAMP;
    team_id INT;  -- Declare team_id as a scalar variable
    engineer_id INT;  -- Declare engineer_id as a scalar variable
    project_id INT;  -- Declare project_id as a scalar variable
    category_name TEXT;  -- Declare category_name as a scalar variable
BEGIN
    stale_threshold := CURRENT_TIMESTAMP - INTERVAL '24 hours';

    -- Determine refresh strategy
    IF p_force_full_refresh THEN
        -- Full refresh of all metrics
        PERFORM refresh_team_metrics();
        PERFORM refresh_engineer_metrics();
        PERFORM refresh_project_metrics();
        PERFORM refresh_category_metrics();
    ELSE
        -- Selective refresh of stale metrics only
        -- Teams
        FOR team_id IN
            SELECT t.team_id
            FROM teams t
            LEFT JOIN team_metrics_materialized tm ON t.team_id = tm.team_id
            WHERE tm.team_id IS NULL OR tm.last_calculated < stale_threshold
        LOOP
            PERFORM refresh_team_metrics(team_id);
        END LOOP;

        -- Engineers
        FOR engineer_id IN
            SELECT DISTINCT c.engineer_id
            FROM commits c
            LEFT JOIN engineer_metrics_materialized em ON c.engineer_id = em.engineer_id
            WHERE em.engineer_id IS NULL OR em.last_calculated < stale_threshold
        LOOP
            PERFORM refresh_engineer_metrics(engineer_id);
        END LOOP;

        -- Projects
        FOR project_id IN
            SELECT DISTINCT j.project_id
            FROM jira_issues j
            LEFT JOIN project_metrics_materialized pm ON j.project_id = pm.project_id
            WHERE pm.project_id IS NULL OR pm.last_calculated < stale_threshold
        LOOP
            PERFORM refresh_project_metrics(project_id);
        END LOOP;

        -- Categories
        FOR category_name IN
            SELECT DISTINCT j.category
            FROM jira_issues j
            LEFT JOIN category_metrics_materialized cm ON j.category = cm.category
            WHERE cm.category IS NULL OR cm.last_calculated < stale_threshold
        LOOP
            PERFORM refresh_category_metrics(category_name);
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql;