# CMX Business Dashboard

The dashboard placeholder has been replaced with a responsive business dashboard designed for desktop, tablet and mobile.

## Implemented sections

- Business filters: company, period and refresh
- 8 KPI cards: receivable, payable, inventory, cash/bank, sales, purchase, gross profit and net profit
- Sales vs purchase monthly trend
- Receivable outstanding ageing
- Inventory health summary
- Top outstanding customers
- Inventory movement classification
- Top selling items
- Cash flow summary
- Action-required alerts
- Quick actions
- Recent transactions

## Navigation

The dashboard quick actions are connected to the existing PortalShell navigation for:

- Dynamic Reports
- User Mapping

## Current data source

The dashboard intentionally uses sample values for the first UI implementation. The widget structure is ready to be replaced with an API-backed dashboard model without changing the visual layout.

Recommended next phase:

1. Create one optimized dashboard summary API for the KPI and summary widgets.
2. Keep detail/drill-down data behind report endpoints so the first dashboard request remains fast.
3. Pass `OID`, `RID`, `UID`, `FromDate` and `ToDate` so existing user/master permissions remain enforceable.
4. Load independent heavy sections (inventory movement, ageing and recent transactions) concurrently or lazily if needed.

## Tests

`test/dashboard_page_test.dart` validates the main dashboard sections and a narrow viewport.
