# Dashboard date filters — 24 September 2026

The dashboard now shows Company, Period, From Date, To Date and Apply together.

- Period keeps Current FY, This Month, Last Month and Last 90 Days. Selecting a preset fills both dates and loads the dashboard.
- Type dates as DD/MM/YYYY or use either calendar button. Editing a date selects Custom; click Apply or press Enter to fetch that range.
- Invalid dates, reversed ranges, future dates and ranges over 366 inclusive days are blocked before the API request.
- Refresh and company switching retain the applied range. Unapplied edits display a reminder; summary download is disabled until those edits are applied.
- Dates are sent as yyyy-MM-dd using the existing dashboard endpoint. The API already accepts from_date and to_date; no backend or database changes are required for this update.

The selected range filters voucher totals, comparisons, sales/purchase charts, top-selling items and recent transactions. Outstanding, inventory and cash/bank are still the latest snapshots, as indicated on the dashboard.

## Update your project

Use the full Flutter ZIP, or copy the lib/ and test/ folders from the changed-files ZIP into your existing cmx_web_portal project. Keep your current API_BASE_URL and other deployment settings.

Run flutter pub get, flutter test, then your normal flutter build web --release command with the existing dart-define settings. Detailed verification results are in TEST-RESULTS.md.
