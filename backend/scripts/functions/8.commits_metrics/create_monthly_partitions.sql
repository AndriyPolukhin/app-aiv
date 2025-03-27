CREATE OR REPLACE FUNCTION create_monthly_partitions(
    start_date date,
    end_date date,
    dry_run boolean DEFAULT false
)
RETURNS text AS $$
DECLARE
    current_month date;
    partition_name text;
    from_date date;
    to_date date;
    result_text text := '';
BEGIN
    current_month := date_trunc('month', start_date);

    WHILE current_month < end_date LOOP
        partition_name := 'commits_' || to_char(current_month, 'YYYYMM');
        from_date := current_month;
        to_date := current_month + interval '1 month';

        IF dry_run THEN
            result_text := result_text || 'Would create partition ' || partition_name ||
                        ' for dates from ' || from_date || ' to ' || to_date || E'\n';
        ELSE
            BEGIN
                EXECUTE format('
                    CREATE TABLE IF NOT EXISTS %I PARTITION OF commits
                    FOR VALUES FROM (%L) TO (%L)',
                    partition_name, from_date, to_date);

                result_text := result_text || 'Created partition ' || partition_name ||
                            ' for dates from ' || from_date || ' to ' || to_date || E'\n';
            EXCEPTION WHEN others THEN
                result_text := result_text || 'Error creating partition ' || partition_name ||
                            ': ' || SQLERRM || E'\n';
            END;
        END IF;

        current_month := current_month + interval '1 month';
    END LOOP;

    RETURN result_text;
END;
$$ LANGUAGE plpgsql;