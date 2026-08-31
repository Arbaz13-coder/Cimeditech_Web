# Report Designer - Frontend implementation

## Goal

The current Report Designer is completely frontend-side. It proves the report-building experience before backend report metadata, design persistence and report execution APIs are implemented.

## Current flow

1. User logs in.
2. Report Designer opens.
3. User chooses a default design or starts from the loaded default.
4. User drags hardcoded backend fields into one of three zones:
   - Header / Report Information
   - Detail Columns
   - Footer / Summary
5. User selects a mapped field and changes its properties.
6. Live preview renders against hardcoded sample rows.
7. `View` opens the report preview.
8. `View PDF` renders the actual generated PDF.
9. `Download PDF` creates the same PDF bytes and invokes the platform save/share flow.

## Field mapping model

Each placed field is represented by `ReportElement`:

```text
id          local design element id
fieldKey    backend field key used to bind data
label       report-facing column/field label
zone        header | detail | footer
width       detail width / relative PDF width
alignment   left | center | right
type        text | number | currency | date | percentage
bold        display emphasis
```

This separates the report design from the actual report data.

## Hardcoded backend fields

The field metadata is currently in:

```text
lib/features/report_designer/data/mock_report_data.dart
```

Examples:

```text
company_name
company_address
company_gstin
voucher_no
voucher_date
party_name
party_gstin
item_name
part_no
uom
quantity
rate
amount
taxable_value
tax_percent
cgst_amount
sgst_amount
igst_amount
tax_amount
grand_total
sales_executive
broker_name
bill_no
bill_date
due_date
pending_amount
```

## Suggested backend APIs later

### 1. Get available report fields

```http
GET /api/report-designer/fields?reportType=SalesRegister
```

Suggested response:

```json
[
  {
    "key": "voucher_no",
    "label": "Voucher No",
    "group": "Transaction",
    "type": "text"
  },
  {
    "key": "amount",
    "label": "Amount",
    "group": "Transaction",
    "type": "currency"
  }
]
```

### 2. Save report design

```http
POST /api/report-designer/designs
```

Store the report name, orientation, selected report/data source and `ReportElement[]` mapping JSON.

### 3. List saved/default designs

```http
GET /api/report-designer/designs
```

### 4. Load report data

```http
POST /api/reports/run
```

Suggested request:

```json
{
  "reportDesignId": "...",
  "fromDate": "2026-08-01",
  "toDate": "2026-08-31",
  "filters": {}
}
```

The returned rows should be JSON objects keyed by the same `fieldKey` values used by the designer.

## No PDF backend is required

PDF generation can remain in Flutter. The backend only needs to provide metadata, saved design JSON and report row data. The current PDF service already consumes the design plus rows and works independently of the API layer.
