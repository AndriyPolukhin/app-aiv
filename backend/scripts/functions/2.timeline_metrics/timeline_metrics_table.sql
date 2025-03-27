CREATE TABLE timeline_metrics_materialized (
    time_period DATE PRIMARY KEY,
    total_issues INTEGER NOT NULL,
    ai_assisted_issues INTEGER NOT NULL,
    non_ai_assisted_issues INTEGER NOT NULL,
    avg_cycle_time_with_ai FLOAT NOT NULL,
    avg_cycle_time_without_ai FLOAT NOT NULL,
    cycle_time_impact_percentage FLOAT NOT NULL,
    ai_adoption_percentage FLOAT NOT NULL,
    last_calculated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metrics_json JSON NOT NULL
);