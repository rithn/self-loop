# User Flows — document-app Report Generator

## Spec-Derived Flows

### F-01: Generate TNMM B2B Report
User fills company details form (company name, fiscal year, comparable type, connected persons), uploads Annexure 2 and Annexure 3 Excel files, selects TNMM method and B2B mode, clicks Generate — receives a DOCX and PDF download with no cover page.

### F-02: Generate TNMM B2C Report
Same as F-01 but with B2C mode selected — Annexure 4 cover page is prepended to both the DOCX (as a PNG placeholder image) and the PDF (as real pages).

### F-03: Generate Other Method Single CP B2B Report
User fills company details form (company name, fiscal year, business activity, one KMP row), uploads Annexure 6 Excel, selects Other Method + Single CP + B2B — receives DOCX and PDF for a single connected person benchmarking report.

### F-04: Generate Other Method Single CP B2C Report
Same as F-03 but with B2C mode — cover page prepended to DOCX and PDF.

### F-05: Generate Other Method Multi-CP B2B Report
User fills company details form with multiple KMP rows, uploads Annexure 6 Excel, selects Other Method + Multiple CPs + B2B — receives a single DOCX and PDF covering all connected persons with per-CP functional analysis and screening sections.

### F-06: Generate Other Method Multi-CP B2C Report
Same as F-05 but with B2C mode — cover page prepended.

### F-07: View Run History
On page load, the frontend fetches GET /api/runs and renders a table of all past generation runs showing date/time, company, method, mode, status badge (green/red/grey), and action links.

### F-08: Re-download Past Report
User clicks "Download DOCX" or "Download PDF" in the run history table — the file streams from GET /api/runs/{id}/file/{type} and the browser downloads it.

### F-09: Failed Generation — Error Displayed
Generation fails (malformed Excel, LibreOffice error, etc.) — the run is recorded with status="failed" and the error message appears in the result area and in the history table as a truncated red badge with full message on hover.

### F-10: Client-Side Validation
User attempts to submit the form with missing required fields (empty company name, no Excel file uploaded, no person rows filled) — inline error message lists all missing fields; form is not submitted; no API call is made.

## Auto-Discovered Flows

### F-11: Health Check [auto-discovered]
GET /health returns `{"status": "ok"}` — used by monitoring and the build-verify loop's verification commands to confirm the server is up.

### F-12: Invalid File Upload Handling [auto-discovered]
POST /api/generate called with a missing required file (e.g., annexure2 absent for TNMM) — server returns HTTP 422 with a descriptive detail message before any DB record is created.

### F-13: Malformed Config JSON [auto-discovered]
POST /api/generate called with a config_file that is not valid JSON — server returns HTTP 400 with detail "Invalid config.json: ..." before any DB record is created.

### F-14: Re-download Missing File [auto-discovered]
GET /api/runs/{id}/file/{type} called for a run whose output file was deleted from disk — server returns HTTP 404 "File no longer available" rather than crashing.
