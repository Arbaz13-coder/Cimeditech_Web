# Flutter Web post-login lag fix

## Root cause

The global `FilledButtonTheme` used:

```dart
minimumSize: const Size.fromHeight(52)
```

`Size.fromHeight(52)` is equivalent to `Size(double.infinity, 52)`. This worked on the stretched Login form button, but after login the Report Designer renders filled buttons inside `AppBar` and `Wrap`, where the horizontal constraint is not bounded. Flutter Web can then repeatedly report layout errors such as `BoxConstraints forces an infinite width`, causing the page to lag or appear stuck.

## Fixes

- Changed the global FilledButton minimum size to `Size(88, 48)`.
- Changed successful Login navigation from `Navigator.push` to `Navigator.pushReplacement`, so the Login page is removed after authentication.
- No API/backend changes are required for this UI issue.

## Report Setup and report download fixes

- A `403 Forbidden` response now remains on the current page as a permission
  error; only an actual `401` expires the login session.
- Report Setup accepts the same display-order, function-casing and width rules
  as the backend, so valid existing metadata is no longer blocked locally.
- Assignment RID can be left blank for authenticated server context, while OID
  is selected from the accessible-company list when available.
- Save validation opens the section containing the first problem.
- Header, toolbar and mobile navigation layouts were tightened to avoid small
  screen overflow and unreachable sections.
- Dynamic Reports now downloads the full filtered/sorted result as PDF or
  Excel-compatible `.xls`, with progress, permission checks and safe row caps.

## Dynamic Report result workspace redesign

- Removed Report Setup from the Flutter portal navigation. Configuration is
  handled by the separate internal Python utility.
- Combined the report identity and filter controls into one compact toolbar.
- Filters automatically collapse after a successful run so the grid receives
  most of the available page height, and they reopen when validation fails.
- Reduced heading and data-row heights and added alternate-row and hover states.
- Added a responsive result toolbar with Copy, PDF, Excel and Refresh actions.
- Fixed the missing `_groupDigits` helper used by report export messages.
