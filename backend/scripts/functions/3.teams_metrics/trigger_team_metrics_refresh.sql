CREATE OR REPLACE FUNCTION trigger_team_metrics_refresh()
RETURNS TRIGGER AS $$
BEGIN
    -- Identify affected team_id
    DECLARE
        affected_team_id INTEGER;
    BEGIN
        IF TG_TABLE_NAME = 'commits' THEN
            -- For commit changes, find related team
            SELECT t.team_id INTO affected_team_id
            FROM teams t
            WHERE NEW.engineer_id::TEXT = ANY(string_to_array(t.engineer_ids, ','));
        ELSIF TG_TABLE_NAME = 'jira_issues' THEN
            -- For issue changes, refresh all (could be optimized further)
            PERFORM refresh_team_metrics();
            RETURN NEW;
        ELSIF TG_TABLE_NAME = 'teams' THEN
            -- For team changes
            affected_team_id := NEW.team_id;
        END IF;

        -- Refresh specific team metrics
        IF affected_team_id IS NOT NULL THEN
            PERFORM refresh_team_metrics(affected_team_id);
        END IF;
    END;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
