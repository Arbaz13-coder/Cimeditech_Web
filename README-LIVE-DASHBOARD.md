# CMX live dashboard

The Flutter dashboard now calls the existing ASP.NET Core API and displays permitted company data from PostgreSQL. There are no demo balances or client-supplied trusted user IDs.

## Install

1. Run `Database/Scripts/20260922_Dashboard.sql` against your existing CMX database. It is transactional and can be applied again. It preserves an existing `rpt.fn_accessible_ledgers(bigint,bigint,bigint)` and restores the shared helper if it is missing.
2. Run `Database/Scripts/20260922_Dashboard_Indexes.sql` separately, outside a transaction, with autocommit enabled. The indexes use `CONCURRENTLY`.
3. Merge the backend changes into your latest API. No additional dependency-injection registration is needed. Keep your current `Program.cs`, appsettings, connection strings and deployment configuration. The complete source is based on the saved September 4 project; use the included changed-files package if you have newer local work.
4. Build and deploy your API using your existing process.
5. Run **LedgerBalancesFY sync again** for each company. The included `TQAP.cs` fix stores RID/OID and scopes replacement by tenant, company and financial year. Old balance rows with missing tenant/company IDs are intentionally ignored. If your local `TQAP.cs` has newer changes, merge only the small changes shown in `Changes.patch` rather than replacing the whole file.
6. Merge the Flutter changes, run `flutter pub get`, then build with your API address and existing AUS client setting:

```sh
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-API-HOST --dart-define=AUS_CLIENT_KEY=YOUR-EXISTING-KEY
```

Include any existing deployment path prefix in `API_BASE_URL`. `API_VAR` remains configurable and defaults to `v1`. Use your existing login and company/user mapping; dashboard access never bypasses company mapping, even for an administrator.

## API

`POST /api/app/v1/dashboard/runtime` with `Content-Type: application/json` and the existing `xRUT` token header. The normal `Status`, `Message`, `RefNo`, `RData` response envelope is retained.

```json
{"RData":{"operation":"Companies"}}
```

```json
{"RData":{"operation":"Overview","o_id":2,"from_date":"2026-04-01","to_date":"2026-09-22"}}
```

Use today's UTC date or an earlier date for `to_date`. The maximum range is 366 days inclusive. RID and UID come from the authenticated session; only the selected OID is sent by Flutter. Companies returns all active mapped companies without a two-company limit.

Overview returns `schema_version`, `o_id`, `company_name`, `from_date`, `to_date`, `as_of_date`, `generated_at`, `last_sync_on`, `activity`, `outstanding`, `inventory` and `cash`. Each dataset carries a `basis` description.

Errors have HTTP 400 (request), 401 (session), 403 (company access), 503 (setup/unavailable) or 504 (timeout), with a safe message and support reference. SQL and connection details are logged server-side, not displayed to users. Postman requests are in `Database/Examples/Dashboard.postman_collection.json`.

## What the figures mean

| Area | Calculation and scope |
| --- | --- |
| Sales / purchases | Gross voucher totals in the selected period; permitted party ledger and actual voucher subtype. Cancelled, deleted and optional vouchers are excluded. Returns are not netted. |
| Receipts / payments | Gross receipt/payment vouchers under the same party/type permissions. These replace the old hardcoded profit cards; no profit is estimated from incomplete cost data. |
| Comparison | Immediately preceding period of the same length. No percentage is invented when the previous amount is zero. |
| Outstanding / ageing | Latest pending-bill closing balances for permitted debtor/creditor ledgers. Tally signs are normalized. Positive dues, customer credits and supplier advances remain separate. Due date is reference date (or creation date) plus credit days; unknown due dates have their own bucket. |
| Inventory | Latest stock snapshot for permitted items and warehouses. Quantities with different units remain separate. Stock counts are item/unit combinations. |
| Movement | Last outward movement in the last 90 days. This describes movement recency, not FIFO stock age or dead stock. |
| Cash / bank | Latest permitted account balances for the current April–March financial year. Overdrafts remain negative. Missing account snapshots show unavailable instead of a misleading zero. |

Changing the period changes voucher totals, comparisons, charts, top-selling items and recent vouchers. Outstanding, inventory and cash remain **latest snapshots**, not historical closing balances for the selected period. The displayed company data date comes from `o_sync_xdt`; it is not treated as proof that an entire multi-batch sync has completed.

The API reads one repeatable-read database snapshot. Your sync still commits multiple batches, so reconcile financial totals after the company sync has finished. This change does not introduce completed-sync versioning.

## Permissions and stock thresholds

The dashboard uses the existing company mapping, shared ledger helper, master UID arrays and Select All policy. Empty permissions do not mean unrestricted access. No response cache delays permission revocations. Company changes and failed requests clear previous results; late responses cannot replace the newly selected company.

Low-stock thresholds are optional and keyed by company, item and exact unit. Without configured thresholds, the UI shows **Not configured**. Example (replace IDs and unit with your actual values):

```sql
INSERT INTO rpt.dashboard_item_settings(r_id,o_id,item_id,unit,minimum_qty)
VALUES (2,2,123,'Kgs.',50)
ON CONFLICT (r_id,o_id,item_id,unit)
DO UPDATE SET minimum_qty=EXCLUDED.minimum_qty;
```

The UI includes loading, no-company, empty-data, session-expired, forbidden, network-error and retry states. Download Summary exports the displayed snapshot as CSV. Existing Reports PDF/Excel exports are unchanged.

## Validation

See `TEST-RESULTS.md` in the delivery package for executed checks and limitations. To repeat:

```sh
# Backend root
dotnet build SGxBrokerAPI/SGxBrokerAPI.csproj -c Release
dotnet run --project tests/DashboardChecks/DashboardChecks.csproj -c Release

# Backend tests/DashboardDatabase folder; uses an isolated PostgreSQL WASM database
npm ci
npm test

# Flutter project root
flutter analyze
flutter test
flutter build web --release
```

The database fixture creates a disposable synthetic database. It does not connect to your production database or contain customer transactions. Performance and final accounting reconciliation should be checked against your real data after installation.

## Custom date filters

The dashboard includes Period, From Date, To Date and Apply. See `README-DASHBOARD-DATE-FILTERS.md` for date entry, validation and installation of this Flutter-only update.
