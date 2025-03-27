CREATE TABLE ai_impact_summary (
    issue_id INTEGER PRIMARY KEY,
    project_id INTEGER,
    author_id INTEGER,
    category VARCHAR(100),
    total_commits INTEGER,
    ai_commits INTEGER,
    non_ai_commits INTEGER,
    cycle_time FLOAT,
    has_ai_commits BOOLEAN,
    team_ids INTEGER[],
    last_updated TIMESTAMP
);

CREATE INDEX idx_ai_impact_project ON ai_impact_summary(project_id);
CREATE INDEX idx_ai_impact_author ON ai_impact_summary(author_id);
CREATE INDEX idx_ai_impact_teams ON ai_impact_summary USING gin(team_ids);

