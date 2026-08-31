# Dynamic Reports Frontend

The **Reports > Dynamic Reports** workspace is a single metadata-driven page.
It can render hundreds of backend reports without creating a separate Flutter
screen for each report.

## Runtime flow

1. `Companies` loads only companies accessible through the current `xRUT`.
2. Selecting a company calls `Catalog` and displays default plus assigned reports.
3. Selecting a report calls `Definition` and builds filters and columns from metadata.
4. Reports with complete/default parameters run automatically. Otherwise the user
   completes required filters and selects **Run report**.
5. `Lookup` powers remote dropdown and multiselect parameters.
6. `Execute` returns server-paged rows, summary values and execution metadata.

All operations use:

```text
POST /api/app/v1/report/runtime
xRUT: <login SvToken>
```

`RID` and `UID` are never sent by Flutter; the API reads them from `xRUT`.

## Supported parameter controls

- `TEXTBOX`, `TEXTAREA`
- `DATE_PICKER`, `DATE_RANGE`
- `NUMBER`
- `CHECKBOX`
- `DROPDOWN`, `MULTISELECT`
- `REMOTE_DROPDOWN`, `REMOTE_MULTISELECT`

Remote lookup dependencies are taken from the current parameter values. When a
parent parameter changes, dependent selections are cleared to prevent invalid
combinations. Multi-select values are sent as JSON arrays.

Local dropdown options can be supplied in parameter validation metadata:

```json
{
  "options": [
    {"value": "ALL", "label": "All"},
    {"value": "YES", "label": "Yes"},
    {"value": "NO", "label": "No"}
  ]
}
```

The frontend understands common validation metadata such as `min`, `max`,
`min_length`, `max_length`, `min_items`, `max_items` and `pattern`.

## Result behavior

- Server-side page number and page size
- Server-side sortable configured columns
- Horizontal and vertical scrolling for wide reports
- Metadata-based dates, numbers, currency, percentage and boolean formatting
- Optional `__summary` values shown above the grid
- Current page can be copied as CSV when `can_export` is true
- Full filtered result can be downloaded as PDF or Excel when `can_export` is true
- Definition cache keyed by company, report and definition version

**Download PDF** and **Download Excel** safely collect server pages using the
current filters and sorting. Browser exports are limited to 5,000 PDF rows and
25,000 Excel rows so a large report cannot freeze the tab. Reports above those
limits show a clear message asking the user to narrow the filters. A future
background export API remains the recommended path for larger datasets.

## Error handling

- Missing/expired session errors are displayed without crashing the page.
- Application-level authentication failures returned inside an HTTP 200 RRM
  response also return the user safely to Login.
- HTTP, invalid JSON, timeout and interrupted-network failures have friendly messages.
- Companies, catalog, definition and execution each have independent retry states.
- Lookup dialogs support retry and ignore stale search responses.
- Company/report changes invalidate in-flight definition and execution responses.
- Export progress, row-limit failures and file-generation errors remain inside the report page.
- Field validation runs before `Execute` and marks the exact invalid parameter.
- Existing result rows remain visible if a refresh or page request fails.
- Copied CSV text protects non-numeric cells from spreadsheet formula injection.

## Main files

```text
lib/features/reports/
├── data/report_repository.dart
├── models/report_models.dart
├── services/
│   ├── dynamic_report_formatter.dart
│   ├── report_export_service.dart
│   ├── report_file_downloader.dart
│   └── report_filter_codec.dart
└── presentation/
    ├── pages/reports_page.dart
    └── widgets/
        ├── report_catalog_panel.dart
        ├── report_data_grid.dart
        ├── report_filter_panel.dart
        └── report_lookup_field.dart
```

The Admin-only `report/configure` API is exposed through the separate
**Reports Administration > Report Setup** workspace. The existing visual Report
Designer also remains separate from both metadata configuration and runtime.
