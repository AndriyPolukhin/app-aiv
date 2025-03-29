CREATE OR REPLACE FUNCTION public.trigger_metrics_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_engineer_id INTEGER;
    affected_team_id INTEGER;
    affected_project_id INTEGER;
    affected_category TEXT;
    refresh_needed BOOLEAN := FALSE;
BEGIN
    -- Set conservative memory limits for trigger execution
    SET LOCAL work_mem = '8MB';
    SET LOCAL maintenance_work_mem = '16MB';

    -- Identify affected entities with optimized queries
    IF TG_TABLE_NAME = 'commits' THEN
        -- Engineer metrics (always available for commits)
        affected_engineer_id := NEW.engineer_id;
        refresh_needed := TRUE;

        -- Team metrics (cached lookup)
        SELECT t.team_id INTO affected_team_id
        FROM teams t
        WHERE NEW.engineer_id::TEXT = ANY(string_to_array(t.engineer_ids, ','))
        LIMIT 1;  -- Just need one team if engineer is in multiple

        -- Project and category metrics (single query)
        SELECT ji.project_id, ji.category
        INTO affected_project_id, affected_category
        FROM jira_issues ji
        WHERE ji.issue_id = NEW.jira_issue_id;

    ELSIF TG_TABLE_NAME = 'jira_issues' THEN
        -- Only refresh if this is an update that affects metrics
        IF TG_OP = 'INSERT' OR
           (TG_OP = 'UPDATE' AND (
               OLD.resolution_date IS DISTINCT FROM NEW.resolution_date OR
               OLD.project_id IS DISTINCT FROM NEW.project_id OR
               OLD.category IS DISTINCT FROM NEW.category
           )) THEN
            refresh_needed := TRUE;

            -- Project metrics
            affected_project_id := NEW.project_id;

            -- Category metrics
            affected_category := NEW.category;

            -- For engineer/team metrics, we'll let periodic refreshes handle it
            -- to avoid complex lookups in the trigger
        END IF;

    ELSIF TG_TABLE_NAME = 'teams' THEN
        -- Only refresh on significant changes
        IF TG_OP = 'INSERT' OR
           (TG_OP = 'UPDATE' AND (
               OLD.engineer_ids IS DISTINCT FROM NEW.engineer_ids
           )) THEN
            refresh_needed := TRUE;
            affected_team_id := NEW.team_id;
        END IF;
    END IF;

    -- Perform targeted refreshes with memory controls
    IF refresh_needed THEN
        -- Engineer metrics (with batch size 1)
        IF affected_engineer_id IS NOT NULL THEN
            BEGIN
                PERFORM refresh_engineer_metrics(affected_engineer_id);
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'Engineer metrics refresh failed for ID %: %',
                    affected_engineer_id, SQLERRM;
            END;
        END IF;

        -- Team metrics (with memory limit)
        IF affected_team_id IS NOT NULL THEN
            BEGIN
                SET LOCAL work_mem = '12MB';
                PERFORM refresh_team_metrics(affected_team_id);
                RESET work_mem;
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'Team metrics refresh failed for team ID %: %',
                    affected_team_id, SQLERRM;
            END;
        END IF;

        -- Project metrics (with memory limit)
        IF affected_project_id IS NOT NULL THEN
            BEGIN
                SET LOCAL work_mem = '12MB';
                PERFORM refresh_project_metrics(affected_project_id);
                RESET work_mem;
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'Project metrics refresh failed for project ID %: %',
                    affected_project_id, SQLERRM;
            END;
        END IF;

        -- Category metrics (with memory limit)
        IF affected_category IS NOT NULL THEN
            BEGIN
                SET LOCAL work_mem = '12MB';
                PERFORM refresh_category_metrics(affected_category);
                RESET work_mem;
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'Category metrics refresh failed for category %: %',
                    affected_category, SQLERRM;
            END;
        END IF;
    END IF;

    -- Ensure memory settings are reset
    RESET work_mem;
    RESET maintenance_work_mem;

    RETURN NEW;
END;
$function$;