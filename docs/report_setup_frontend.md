# Report Setup Frontend

The **Reports Administration > Report Setup** workspace manages the complete
metadata payload used by the dynamic report engine.

All operations use:

```text
POST /api/app/v1/report/configure
xRUT: <login SvToken>
```

The endpoint remains Admin-only. A non-Admin receives a clear permission state
without breaking the rest of the portal.

## Supported operations

1. `List` loads the searchable configuration catalog.
2. `Get` loads one complete report with parameters, columns, actions and assignments.
3. `Save` sends the full configuration as one replacement payload. The backend
   validates function signatures and commits every child table atomically.

## Structured editor

- **Overview**: identity, report code, type, PostgreSQL function, page limits,
  timeout, active status and default availability.
- **Parameters**: data type, Flutter control, lookup function, required/multiple
  behavior, JSON default value, validation metadata and dependencies.
- **Columns**: result alias, display label/order, type, format, alignment, width,
  visibility, sorting, filtering, export and aggregate flags.
- **Actions**: future toolbar/row/selection actions with an allowlisted handler key.
- **Assignments**: company picker, optional RID override and optional exact UID override.

Leaving `r_id` blank uses the authenticated registration supplied by the API.
Leaving `u_id` blank creates a company-level assignment. Default reports do not
need an assignment; active non-default reports require at least one active row
with `can_view = true`.

## Error and data-loss protection

- Client validation mirrors backend naming, schema, paging and timeout rules.
- JSON fields are parsed before any save request.
- Duplicate names, display orders and assignments are detected locally.
- Save validation automatically opens the section containing the first problem.
- Zero-based display orders and positive column widths match backend validation.
- Switching reports, creating another report or refreshing asks before discarding
  unsaved changes.
- Failed saves keep the complete draft available for correction and retry.
- Authentication failures return to Login, while Admin permission failures remain
  visible as a permission state.
- Request-version guards prevent a slower response from replacing a newer selection.
