# Critical Paths — document-app Report Generator

---

## F-01 / F-02: TNMM Report Generation (B2B and B2C)

```
Function: generate_report
Source:   api/routes/generate.py:29
Label:    integration
Notes:    Entry point for all report generation. Handles file validation, DB inserts, routing, cleanup.

  Function: _save_upload
  Source:   api/routes/generate.py:23
  Called by: api/routes/generate.py:83-84
  Label:    unit

  Function: get_db
  Source:   api/database.py:32
  Called by: api/routes/generate.py:64, 128, 143
  Label:    integration

  Function: generate_tnmm_report
  Source:   api/services/tnmm_service.py:34
  Called by: api/routes/generate.py:89
  Label:    integration

    Function: extract_annexure3
    Source:   {PROJECT_DIR}/tp_report_generator.py [external — do not modify]
    Called by: api/services/tnmm_service.py:71
    Label:    unit

    Function: extract_annexure2
    Source:   {PROJECT_DIR}/tp_report_generator.py [external — do not modify]
    Called by: api/services/tnmm_service.py:77
    Label:    unit

    Function: populate_report
    Source:   {PROJECT_DIR}/tp_report_generator.py [external — do not modify]
    Called by: api/services/tnmm_service.py:82
    Label:    integration (writes DOCX to disk)

    Function: embed_cover_page_in_docx   [B2C only]
    Source:   api/services/cover_page_service.py:16
    Called by: api/services/tnmm_service.py:88
    Label:    integration (reads PDF, writes DOCX)

    Function: generate_pdf
    Source:   api/services/pdf_service.py:7
    Called by: api/services/tnmm_service.py:93
    Label:    integration (shells out to LibreOffice)

    Function: prepend_cover_page_pdf     [B2C only]
    Source:   api/services/cover_page_service.py:116
    Called by: api/services/tnmm_service.py:99
    Label:    integration (reads + writes PDF)
```

---

## F-03 / F-04: Other Method Single CP Report Generation (B2B and B2C)

```
Function: generate_report
Source:   api/routes/generate.py:29
Label:    integration

  Function: get_db
  Source:   api/database.py:32
  Called by: api/routes/generate.py:64, 128, 143
  Label:    integration

  Function: generate_other_method_report
  Source:   api/services/other_method_service.py:33
  Called by: api/routes/generate.py:116
  Label:    integration

    Function: extract_annexure6
    Source:   {PROJECT_DIR}/tp_report_generator_other_method.py [external — do not modify]
    Called by: api/services/other_method_service.py:68
    Label:    unit

    Function: populate_report
    Source:   {PROJECT_DIR}/tp_report_generator_other_method.py [external — do not modify]
    Called by: api/services/other_method_service.py:73
    Label:    integration (writes DOCX to disk)

    Function: embed_cover_page_in_docx   [B2C only]
    Source:   api/services/cover_page_service.py:16
    Called by: api/services/other_method_service.py:79
    Label:    integration

    Function: generate_pdf
    Source:   api/services/pdf_service.py:7
    Called by: api/services/other_method_service.py:84
    Label:    integration

    Function: prepend_cover_page_pdf     [B2C only]
    Source:   api/services/cover_page_service.py:116
    Called by: api/services/other_method_service.py:90
    Label:    integration
```

---

## F-05 / F-06: Other Method Multi-CP Report Generation (B2B and B2C)

```
Function: generate_report
Source:   api/routes/generate.py:29
Label:    integration

  Function: generate_other_method_multi_report
  Source:   api/services/other_method_multi_service.py:346
  Called by: api/routes/generate.py:105
  Label:    integration

    Function: _extract_all_cp_data
    Source:   api/services/other_method_multi_service.py:129
    Called by: api/services/other_method_multi_service.py:~360
    Label:    unit

      Function: _extract_cp_data_from_tab
      Source:   api/services/other_method_multi_service.py:60
      Called by: api/services/other_method_multi_service.py:~140
      Label:    unit
      Notes:    Returns empty dict with warning if CP tab not found in Annexure 6

    Function: _populate_multi_report
    Source:   api/services/other_method_multi_service.py:159
    Called by: api/services/other_method_multi_service.py:~370
    Label:    integration (writes DOCX to disk)
    Notes:    Uses apply_replacements, set_cell_value, build_conclusion from
              tp_report_generator_other_method.py [external]

    Function: embed_cover_page_in_docx   [B2C only]
    Source:   api/services/cover_page_service.py:16
    Label:    integration

    Function: generate_pdf
    Source:   api/services/pdf_service.py:7
    Label:    integration

    Function: prepend_cover_page_pdf     [B2C only]
    Source:   api/services/cover_page_service.py:116
    Label:    integration
```

---

## F-07: View Run History

```
Function: list_runs
Source:   api/routes/runs.py:17
Label:    integration

  Function: get_db
  Source:   api/database.py:32
  Called by: api/routes/runs.py:18
  Label:    integration
  Notes:    Queries all rows ORDER BY id DESC; maps to RunRecord Pydantic models
```

---

## F-08: Re-download Past Report

```
Function: download_file
Source:   api/routes/runs.py:42
Label:    integration

  Function: get_db
  Source:   api/database.py:32
  Called by: api/routes/runs.py:46
  Label:    integration
  Notes:    Returns FileResponse with correct MIME type and Content-Disposition.
            404 if run not found, status != success, or file missing from disk.
```

---

## F-09 / F-10: Failed Generation and Client-Side Validation

```
# Server-side error path
Function: generate_report (exception branch)
Source:   api/routes/generate.py:142
Label:    integration
Notes:    Any exception caught → UPDATE runs SET status='failed', error_message=str(e)
          → raise HTTPException(500). Temp dir cleaned in finally block (line 151).

# Client-side validation
Function: (JS form submit handler)
Source:   {PROJECT_DIR}/static/index.html [inline JS]
Label:    browser (testable via Playwright /code-ui-testing — not curl/pytest)
Notes:    Collects missing field names into array, renders inline error message.
          Does not fire an API call. Test by clicking Generate with empty fields
          and asserting the error message appears and no network request is made.
```

---

## F-11: Health Check

```
Function: health
Source:   api/main.py:51
Label:    cli
Notes:    curl http://localhost:8000/health → {"status": "ok"}
```

---

## F-12 / F-13: Input Validation (missing file, malformed JSON)

```
Function: generate_report (validation guards)
Source:   api/routes/generate.py:39-57
Label:    integration
Notes:    HTTP 422 for wrong method/mode or missing annexure files (lines 39-50).
          HTTP 400 for invalid config JSON (lines 53-57).
          Both fire before any DB record is created.
```

---

## F-14: Re-download Missing File

```
Function: download_file (missing file branch)
Source:   api/routes/runs.py:59
Label:    integration
Notes:    os.path.exists() check on the stored path. Returns 404 "File no longer available".
```

---

## Integration Boundary Summary

| Boundary | Flows affected | Required for tests |
|---|---|---|
| LibreOffice headless | F-01 through F-06 | `libreoffice` on PATH; install via `brew install --cask libreoffice` or `apt install libreoffice` |
| PyMuPDF (fitz) | F-02, F-04, F-06 | `pip install pymupdf` — pure Python, no system deps |
| pypdf | F-02, F-04, F-06 | `pip install pypdf` — pure Python |
| SQLite (app.db) | F-01 through F-09, F-12, F-13 | Created automatically on startup by `init_db()` |
| tp_report_generator.py (external) | F-01, F-02 | Read-only; do not modify |
| tp_report_generator_other_method.py (external) | F-03 through F-06 | Read-only; do not modify |
| Annexure template files (templates/) | F-01 through F-06 | Must be copied from source-docs/ before running |
| Client-side JS (index.html) | F-10 | Testable via Playwright (`/code-ui-testing`) |
