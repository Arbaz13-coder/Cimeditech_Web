# Date-filter update — 24 September 2026

- Full Flutter test suite: 41 passed, including four new date-filter scenarios.
- Targeted analysis of the dashboard and its widget tests: no issues found.
- Release web build: passed with Flutter 3.47.5 / Dart 3.13.4.
- New checks cover typed and calendar-selected dates, Apply behaviour, preset/date synchronization, invalid/future/reversed/overlong ranges, the 366-day inclusive boundary, and retaining dates across refresh/company changes.
- Existing responsive-layout, permissions, error handling and stale-response tests passed again.
- The existing Cupertino font-family build warning remains. No deployed API or production data was used for this frontend update.

The backend and database scripts have no changes in this update. Their earlier validation is recorded below; it was not repeated for a frontend-only change.

---

# Dashboard verification — 23 September 2026

| Check | Result |
| --- | --- |
| ASP.NET Core release build | Passed: .NET SDK 10.0.401, 0 errors, 51 existing project warnings. |
| API validation and failure handling | 17 checks passed. |
| PostgreSQL migration and calculations | 36 checks passed in isolated PostgreSQL 18.3 / PGlite 0.5.8. Main migration applied twice successfully. |
| Flutter test suite | 37 tests passed, including dashboard and existing project tests. |
| Flutter release web build | Passed with Flutter 3.47.4 / Dart 3.13.3; Wasm compatibility dry run also succeeded. |
| Flutter static analysis | 0 errors. No diagnostics in new dashboard files. Existing modules have 5 unused-element warnings and 17 informational lint/deprecation findings, so the full analyzer command exits nonzero. |
| Postman collection | Both request envelopes parse correctly after variable substitution. |
| Delivery archives | ZIP CRC/integrity checks passed; toolchains, dependency caches and generated build files excluded. |

The release web build reported an existing Cupertino font-family warning. Material icons bundled successfully. This is recorded rather than calling the whole project warning-free.

## What was exercised

- Company/tenant isolation and company-access denial, including inactive companies.
- Ledger permissions, Select All, and immediate mapping/policy revocation.
- Voucher subtype and party permissions; date boundaries; cancelled, deleted and optional exclusions; equal previous-period totals.
- Item totals kept separate by unit, stock and warehouse permissions, configured thresholds, negative and zero stock.
- Receivable/payable signs, separate credits and advances, ageing boundaries, unknown due dates and upcoming payables.
- Latest current-financial-year cash/bank balances, overdrafts, missing snapshots and exclusion of legacy unscoped rows.
- API request/date/session validation, rejection of client-provided trusted identity, safe database-error messages and support references.
- Flutter response contract and token header, rejection of incomplete totals and wrong-company responses, HTTP/business errors and missing tokens.
- Desktop and 390-pixel layouts, all dashboard sections, third company in the dropdown, stale response after switching company, retry, empty companies, expired session and clearing old values when permission fails.

The HTTP test fixtures use UTF-8, matching the ASP.NET JSON response, so Unicode labels are covered. Repository rejection tests check the specific error message, not just any exception.

## Limits

Checks use synthetic transactions and isolated test databases. No live xRUT session, production PostgreSQL database, Tally instance, production-sized performance run or deployed browser-to-API session was available. Concurrent index creation under production load and the LedgerBalancesFY round trip still require checking in your environment. A repeatable-read query is consistent within one request but does not make a multi-batch sync atomic.

After installation, complete one company sync, confirm ledger/item/warehouse/voucher-type mappings, and compare the dashboard totals with Tally for a known period. Run LedgerBalancesFY again to populate the corrected RID/OID fields before checking cash/bank balances.
