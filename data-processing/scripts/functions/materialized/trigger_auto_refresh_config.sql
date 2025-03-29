------------------------------------------------------------------
-- TRIGGER-BASED AUTO-REFRESH CONFIGURATION
------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trigger_metrics_refresh()
RETURNS TRIGGER AS $$
DECLARE
    affected_engineer_id INTEGER;
    affected_team_id INTEGER;
    affected_project_id INTEGER;
    affected_category TEXT;
BEGIN
    -- Identify affected entities
    IF TG_TABLE_NAME = 'commits' THEN
        -- Engineer metrics
        affected_engineer_id := NEW.engineer_id;

        -- Team metrics (lookup team for this engineer)
        SELECT t.team_id INTO affected_team_id
        FROM teams t
        WHERE NEW.engineer_id::TEXT = ANY(string_to_array(t.engineer_ids, ','));

        -- Project metrics (lookup project for this issue)
        SELECT ji.project_id INTO affected_project_id
        FROM jira_issues ji
        WHERE ji.issue_id = NEW.jira_issue_id;

        -- Category metrics (lookup category for this issue)
        SELECT ji.category INTO affected_category
        FROM jira_issues ji
        WHERE ji.issue_id = NEW.jira_issue_id;

    ELSIF TG_TABLE_NAME = 'jira_issues' THEN
        -- Project metrics
        affected_project_id := NEW.project_id;

        -- Category metrics
        affected_category := NEW.category;

        -- Team and engineer metrics may need refresh if this issue has commits
        -- This is more complex and might require a full refresh or additional logic

    ELSIF TG_TABLE_NAME = 'teams' THEN
        -- Team metrics
        affected_team_id := NEW.team_id;
    END IF;

    -- Perform targeted refreshes based on affected entities
    IF affected_engineer_id IS NOT NULL THEN
        PERFORM refresh_engineer_metrics(affected_engineer_id);
    END IF;

    IF affected_team_id IS NOT NULL THEN
        PERFORM refresh_team_metrics(affected_team_id);
    END IF;

    IF affected_project_id IS NOT NULL THEN
        PERFORM refresh_project_metrics(affected_project_id);
    END IF;

    IF affected_category IS NOT NULL THEN
        PERFORM refresh_category_metrics(affected_category);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers on key tables
CREATE TRIGGER refresh_metrics_on_commit_change
AFTER INSERT OR UPDATE ON commits
FOR EACH ROW EXECUTE FUNCTION trigger_metrics_refresh();

CREATE TRIGGER refresh_metrics_on_issue_change
AFTER INSERT OR UPDATE ON jira_issues
FOR EACH ROW EXECUTE FUNCTION trigger_metrics_refresh();

CREATE TRIGGER refresh_metrics_on_team_change
AFTER INSERT OR UPDATE ON teams
FOR EACH ROW EXECUTE FUNCTION trigger_metrics_refresh();