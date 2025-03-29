CREATE OR REPLACE FUNCTION move_commit_to_partition(
    p_commit_id varchar,
    p_new_date date
)
RETURNS void AS $$
DECLARE
    v_current_record commits%ROWTYPE;
BEGIN
    -- Get the current commit data
    SELECT * INTO v_current_record
    FROM commits
    WHERE commit_id = p_commit_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Commit % not found', p_commit_id;
    END IF;

    -- Delete from current partition
    DELETE FROM commits WHERE commit_id = p_commit_id;

    -- Insert into new partition (will be routed automatically)
    INSERT INTO commits VALUES (
        v_current_record.commit_id,
        v_current_record.engineer_id,
        v_current_record.jira_issue_id,
        v_current_record.repo_id,
        p_new_date,
        v_current_record.ai_used,
        v_current_record.lines_of_code
    );

    RAISE NOTICE 'Moved commit % from % to %',
        p_commit_id, v_current_record.commit_date, p_new_date;
EXCEPTION
    WHEN others THEN
        -- Restore original data if error occurs
        IF v_current_record.commit_id IS NOT NULL THEN
            INSERT INTO commits VALUES (
                v_current_record.commit_id,
                v_current_record.engineer_id,
                v_current_record.jira_issue_id,
                v_current_record.repo_id,
                v_current_record.commit_date,
                v_current_record.ai_used,
                v_current_record.lines_of_code
            );
        END IF;
        RAISE EXCEPTION 'Error moving commit: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;