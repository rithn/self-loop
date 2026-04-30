# Critical Paths — CSV Report Generator

---

## F-01 / F-02: Standard Report Generation (with and without cover page)

```
Function: generate_report
Source:   api/routes/generate.py:31
Label:    integration
Notes:    Entry point for all report generation. Handles file validation, DB inserts, routing, cleanup.

  Function: _save_upload
  Source:   api/routes/generate.py:25
  Called by: api/routes/generate.py:85
  Label:    unit

  Function: get_db
  Source:   api/database.py:18
  Called by: api/routes/generate.py:66, 130, 145
  Label:    integration

  Function: generate_standard_report
  Source:   api/services/report_service.py:28
  Called by: api/routes/generate.py:92
  Label:    integration

    Function: parse_csv
    Source:   api/services/csv_parser.py:14
    Called by: api/services/report_service.py:55
    Label:    unit

    Function: apply_grouping
    Source:   api/services/report_service.py:72
    Called by: api/services/report_service.py:60
    Label:    unit
    Notes:    Groups rows by the column name in config["group_by"]; returns dict of group → rows

    Function: populate_docx
    Source:   api/services/docx_builder.py:22
    Called by: api/services/report_service.py:65
    Label:    integration (writes DOCX to disk)

    Function: embed_cover_page   [F-02 only]
    Source:   api/services/cover_service.py:18
    Called by: api/services/report_service.py:71
    Label:    integration (reads image, prepends to DOCX)

    Function: generate_pdf
    Source:   api/services/pdf_service.py:9
    Called by: api/services/report_service.py:76
    Label:    integration (shells out to LibreOffice)

    Function: prepend_cover_pdf   [F-02 only]
    Source:   api/services/cover_service.py:88
    Called by: api/services/report_service.py:82
    Label:    integration (reads + writes PDF)
```

---

## F-03: Summary Report Generation

```
Function: generate_report
Source:   api/routes/generate.py:31
Label:    integration

  Function: generate_summary_report
  Source:   api/services/summary_service.py:21
  Called by: api/routes/generate.py:108
  Label:    integration

    Function: parse_csv
    Source:   api/services/csv_parser.py:14
    Called by: api/services/summary_service.py:48
    Label:    unit

    Function: aggregate_rows
    Source:   api/services/summary_service.py:62
    Called by: api/services/summary_service.py:53
    Label:    unit
    Notes:    Sums numeric columns per group; non-numeric columns are omitted from aggregation

    Function: populate_docx
    Source:   api/services/docx_builder.py:22
    Called by: api/services/summary_service.py:58
    Label:    integration (writes DOCX to disk)

    Function: generate_pdf
    Source:   api/services/pdf_service.py:9
    Called by: api/services/summary_service.py:63
    Label:    integration
```

---

## F-04: View Run History

```
Function: list_runs
Source:   api/routes/runs.py:19
Label:    integration

  Function: get_db
  Source:   api/database.py:18
  Called by: api/routes/runs.py:20
  Label:    integration
  Notes:    Queries all rows ORDER BY id DESC; maps to RunRecord Pydantic models
```

---

## F-05: Re-download Past Report

```
Function: download_file
Source:   api/routes/runs.py:44
Label:    integration

  Function: get_db
  Source:   api/database.py:18
  Called by: api/routes/runs.py:48
  Label:    integration
  Notes:    Returns FileResponse with correct MIME type and Content-Disposition.
            404 if run not found, status != success, or file missing from disk.
```

---

## F-06 / F-07: Failed Generation and Client-Side Validation

```
# Server-side error path
Function: generate_report (exception branch)
Source:   api/routes/generate.py:144
Label:    integration
Notes:    Any exception caught → UPDATE runs SET status='failed', error_message=str(e)
          → raise HTTPException(500). Temp dir cleaned in finally block.

# Client-side validation
Function: (JS form submit handler)
Source:   app/frontend/index.html [inline JS]
Label:    browser (testable via Playwright /code-ui-testing — not curl/pytest)
Notes:    Collects missing field names into array, renders inline error message.
          Does not fire an API call. Test by clicking Generate with empty fields
          and asserting the error message appears and no network request is made.
```

---

## F-08: Health Check

```
Function: health
Source:   api/main.py:42
Label:    cli
Notes:    curl http://localhost:8000/health → {"status": "ok"}
```

---

## F-09 / F-10: Input Validation (missing file, malformed JSON)

```
Function: generate_report (validation guards)
Source:   api/routes/generate.py:41-59
Label:    integration
Notes:    HTTP 422 for missing required file (lines 41-50).
          HTTP 400 for invalid config JSON (lines 53-59).
          Both fire before any DB record is created.
```

---

## F-11: Re-download Missing File

```
Function: download_file (missing file branch)
Source:   api/routes/runs.py:61
Label:    integration
Notes:    os.path.exists() check on stored path. Returns 404 "File no longer available".
```

---

## Integration Boundary Summary

| Boundary | Flows affected | Required for tests |
|---|---|---|
| LibreOffice headless | F-01 through F-03 | `libreoffice` on PATH; install via `brew install --cask libreoffice` or `apt install libreoffice` |
| PyMuPDF (fitz) | F-02 | `pip install pymupdf` — pure Python, no system deps |
| SQLite (app.db) | F-01 through F-05, F-09, F-10 | Created automatically on startup by `init_db()` |
| Client-side JS (index.html) | F-07 | Testable via Playwright (`/code-ui-testing`) |
