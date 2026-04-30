# User Flows — CSV Report Generator

## Spec-Derived Flows

### F-01: Generate Report (Standard)
User fills the report configuration form (title, date range, grouping column), uploads a CSV data file, clicks Generate — receives a DOCX and PDF download.

### F-02: Generate Report (With Cover Page)
Same as F-01 but with the "Include cover page" option enabled — a cover page image is prepended to both the DOCX and the PDF output.

### F-03: Generate Summary Report
User selects "Summary" report type, fills configuration, uploads CSV — receives a condensed DOCX and PDF showing only aggregated totals per group, not individual rows.

### F-04: View Run History
On page load, the frontend fetches GET /api/runs and renders a table of all past generation runs showing date/time, report title, status badge (green/red/grey), and download links.

### F-05: Re-download Past Report
User clicks "Download DOCX" or "Download PDF" in the run history table — the file streams from GET /api/runs/{id}/file/{type} and the browser downloads it.

### F-06: Failed Generation — Error Displayed
Generation fails (malformed CSV, LibreOffice error, etc.) — the run is recorded with status="failed" and the error message appears in the result area and in the history table as a truncated red badge with full message on hover.

### F-07: Client-Side Validation
User attempts to submit the form with missing required fields (empty title, no CSV uploaded) — inline error message lists missing fields; form is not submitted; no API call is made.

## Auto-Discovered Flows

### F-08: Health Check [auto-discovered]
GET /health returns `{"status": "ok"}` — used by monitoring and the build-verify loop's verification commands to confirm the server is up.

### F-09: Invalid File Upload Handling [auto-discovered]
POST /api/generate called with a missing required file — server returns HTTP 422 with a descriptive detail message before any DB record is created.

### F-10: Malformed Config JSON [auto-discovered]
POST /api/generate called with a config_json field that is not valid JSON — server returns HTTP 400 with detail "Invalid config: ..." before any DB record is created.

### F-11: Re-download Missing File [auto-discovered]
GET /api/runs/{id}/file/{type} called for a run whose output file was deleted from disk — server returns HTTP 404 "File no longer available" rather than crashing.
