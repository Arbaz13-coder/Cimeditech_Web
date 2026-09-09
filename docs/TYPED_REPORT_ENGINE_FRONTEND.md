# Typed Report Engine Frontend

The Reports page supports ASP.NET report engine version 2 without creating a
Flutter screen for each report.

The existing runtime endpoint remains unchanged:

```text
POST /api/app/v1/report/runtime
```

For a typed PostgreSQL report, the backend returns an inferred definition with
`engine_version: 2`. Flutter then:

- Creates date, date-time, number, boolean, text, dropdown, and multi-select
  controls from the inferred parameter types.
- Uses the central remote ledger lookup for `ledgerId`, `ledgerIds`, `partyId`,
  and `partyIds` parameters.
- Converts comma-separated values to typed arrays when a list parameter does
  not use a lookup.
- Sends the same `filters`, `sort`, `page_no`, and `page_size` request shape used
  by existing reports.
- Displays columns inferred from `RETURNS TABLE` aliases.
- Uses server-side sorting and next/previous pagination.
- Downloads PDF and Excel from the current report filters, subject to the safe
  browser export row limit.

The Flutter Report Setup page and its configuration repository code have been
removed. Report configuration stays in the separate internal administration
tool/API.

Run the frontend tests with:

```bash
flutter test
```

The typed-engine cases are in `test/dynamic_reports_test.dart`.
