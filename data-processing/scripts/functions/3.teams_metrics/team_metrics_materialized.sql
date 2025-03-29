CREATE TABLE team_metrics_materialized (
    team_id INTEGER PRIMARY KEY,
    total_issues INTEGER NOT NULL,
    issues_with_ai INTEGER NOT NULL,
    issues_without_ai INTEGER NOT NULL,
    avg_cycle_time_with_ai FLOAT NOT NULL,
    avg_cycle_time_without_ai FLOAT NOT NULL,
    cycle_time_impact_percentage FLOAT NOT NULL,
    ai_adoption_rate FLOAT NOT NULL,
    top_categories JSON NOT NULL,
    last_calculated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metrics_json JSON NOT NULL
);