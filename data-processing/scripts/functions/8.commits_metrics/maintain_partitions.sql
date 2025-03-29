CREATE OR REPLACE FUNCTION maintain_partitions(
    months_to_keep integer DEFAULT 12,
    archive_old boolean DEFAULT false,
    archive_schema text DEFAULT 'archive'
)
RETURNS text AS $$
DECLARE
    partition_record record;
    cutoff_date date;
    result_text text := '';
BEGIN
    -- Create archive schema if needed
    IF archive_old THEN
        EXECUTE format('CREATE SCHEMA IF NOT EXISTS %I', archive_schema);
    END IF;

    cutoff_date := date_trunc('month', CURRENT_DATE - (months_to_keep * interval '1 month'));

    -- Process partitions older than cutoff
    FOR partition_record IN
        SELECT
            nmsp_child.nspname AS child_schema,
            child.relname AS child_name,
            pg_get_expr(c.conbin, c.conrelid) AS constraint_def
        FROM pg_inherits
        JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
        JOIN pg_class child ON pg_inherits.inhrelid = child.oid
        JOIN pg_namespace nmsp_parent ON nmsp_parent.oid = parent.relnamespace
        JOIN pg_namespace nmsp_child ON nmsp_child.oid = child.relnamespace
        JOIN pg_constraint c ON c.conrelid = child.oid AND c.contype = 'c'
        WHERE parent.relname = 'commits'
    LOOP
        -- Extract the FROM date from the partition constraint
        DECLARE
            from_date date;
            partition_date date;
        BEGIN
            -- Parse the constraint to get the FROM date
            EXECUTE 'SELECT ' ||
                regexp_replace(partition_record.constraint_def,
                                '.*FROM \(\''([0-9-]+)\''\).*',
                                '''\1''::date')
            INTO from_date;

            partition_date := date_trunc('month', from_date);

            IF partition_date < cutoff_date THEN
                IF archive_old THEN
                    -- Detach and move to archive schema
                    EXECUTE format('ALTER TABLE commits DETACH PARTITION %I.%I',
                                partition_record.child_schema, partition_record.child_name);

                    EXECUTE format('ALTER TABLE %I.%I SET SCHEMA %I',
                                partition_record.child_schema, partition_record.child_name,
                                archive_schema);

                    result_text := result_text || 'Archived partition ' ||
                                partition_record.child_name || E'\n';
                ELSE
                    -- Just detach (caller can decide what to do with it)
                    EXECUTE format('ALTER TABLE commits DETACH PARTITION %I.%I',
                                partition_record.child_schema, partition_record.child_name);

                    result_text := result_text || 'Detached partition ' ||
                                partition_record.child_name || E'\n';
                END IF;
            END IF;
        EXCEPTION WHEN others THEN
            result_text := result_text || 'Error processing partition ' ||
                        partition_record.child_name || ': ' || SQLERRM || E'\n';
        END;
    END LOOP;

    -- Create new partitions for future months if needed
    result_text := result_text ||
                create_monthly_partitions(
                    date_trunc('month', CURRENT_DATE),
                    date_trunc('month', CURRENT_DATE + interval '3 months'),
                    false);

    RETURN result_text;
END;
$$ LANGUAGE plpgsql;