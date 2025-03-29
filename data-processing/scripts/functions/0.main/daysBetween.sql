CREATE OR REPLACE FUNCTION days_between(start_date DATE, end_date DATE)
RETURNS INTEGER AS $$
BEGIN
    RETURN (end_date - start_date);
END;
$$ LANGUAGE plpgsql;