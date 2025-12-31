-- Report Issue table for EV Users to report data discrepancies on published stations

-- Create enum types
CREATE TYPE issue_category AS ENUM (
    'LOCATION_WRONG',
    'PRICE_WRONG', 
    'HOURS_WRONG',
    'PORTS_WRONG',
    'OTHER'
);

CREATE TYPE issue_status AS ENUM (
    'OPEN',
    'ACKNOWLEDGED',
    'RESOLVED',
    'REJECTED'
);

-- Create report_issue table
CREATE TABLE report_issue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES station(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES user_account(id) ON DELETE CASCADE,
    category issue_category NOT NULL,
    description TEXT NOT NULL,
    status issue_status NOT NULL DEFAULT 'OPEN',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    decided_at TIMESTAMP,
    admin_note TEXT
);

-- Create indexes
CREATE INDEX idx_report_issue_station_id ON report_issue(station_id);
CREATE INDEX idx_report_issue_status ON report_issue(status);
CREATE INDEX idx_report_issue_reporter_id ON report_issue(reporter_id);
CREATE INDEX idx_report_issue_created_at ON report_issue(created_at DESC);

-- Comments
COMMENT ON TABLE report_issue IS 'Reports from EV users about data discrepancies on published stations';
COMMENT ON COLUMN report_issue.category IS 'Type of issue: LOCATION_WRONG, PRICE_WRONG, HOURS_WRONG, PORTS_WRONG, OTHER';
COMMENT ON COLUMN report_issue.status IS 'Issue status: OPEN (new), ACKNOWLEDGED (seen by admin), RESOLVED (fixed), REJECTED (invalid)';

