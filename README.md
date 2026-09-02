# cmx_web_portal

Flutter CMX Web Portal for **Web, Android and iOS**.

The project now includes a responsive authenticated application shell, User Mapping connected to SGxBrokerAPI, metadata-driven Dynamic Reports, and the existing frontend Report Designer.

## Navigation

After login the portal opens on:

1. **Dashboard** - intentionally empty/placeholder for future widgets.
2. **Data Management** - currently contains **User Mapping**.
3. **Reports** - one generic runtime page for all configured company/user reports.
4. **Report Designer** - existing drag-and-drop report designer with PDF preview/export.

Desktop uses a collapsible left sidebar. Smaller screens automatically use a drawer menu.

## User Mapping

User Mapping is connected to the authenticated company endpoint and protected SGxBrokerAPI mapping endpoints:

```text
POST /api/app/v1/admin/getregcompanywithuser
POST /api/app/v1/usermapping/mastertypes
POST /api/app/v1/usermapping/users
POST /api/app/v1/usermapping/get
POST /api/app/v1/usermapping/save
```

Every request uses the login `SvToken` through the `xRUT` header.

Implemented UI:

- Company dropdown loaded from `GetRegCompanyWithUser`
- Company context passed as `company_id` to User Mapping APIs
- Active user list with search
- Backend-provided master types
- Item / Ledger / Transaction Type / Cost Category / Cost Center / Stock Category / Warehouse / Item Group / Ledger Group
- Master record search
- Server-side paging: 50 / 100 / 250 / 500 rows
- Explicit access by numeric master IDs
- Select All policy
- Selected IDs preserved while paging/searching before save
- Save Mapping
- Revoke All
- Unsaved-change protection when changing user/master/company
- Responsive desktop/mobile layout
- Loading, empty and API-error states

`DEFAULT_COMPANY_ID` is only a preferred initial company. If that company is available to the logged-in user it is selected; otherwise the first company returned by the API is used.

## Authentication

- Login using mobile/email + password
- Create Account
- Registration OTP Verification
- Reset Password OTP + new password
- Stores `SvToken` using secure storage
- Successful login opens the portal Dashboard
- Sign out clears the stored session token

## Report Designer

- Hardcoded backend field palette
- Drag/drop mapping into Header, Detail and Footer
- Reorder and field properties
- Sales Invoice, Sales Register and Outstanding Statement templates
- Portrait/Landscape
- Live preview
- PDF view/download/share

## Dynamic Reports

- Company dropdown loaded from the authenticated Reports API
- Searchable report catalog designed for 200-300+ reports per client
- Metadata-driven text, number, checkbox, date, dropdown and multiselect filters
- Remote lookup search with dependent-parameter support
- Server-side paging and sortable configured columns
- Results-first workspace that collapses filters after a successful run
- Compact grid density so substantially more rows remain visible
- Loading, empty, timeout, network, session and API-error states with retry
- Definition-version cache and stale-response protection
- Summary cards and current-page CSV copy when export access is granted
- Full-result PDF and Excel downloads with safe browser row limits and progress

Runtime endpoint:

```text
POST /api/app/v1/report/runtime
```

See `docs/dynamic_reports_frontend.md` for the complete frontend/API flow.

## Main project structure

```text
lib/
├── core/
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── shell/
│   ├── reports/
│   ├── user_mapping/
│   │   ├── data/
│   │   │   └── user_mapping_repository.dart
│   │   ├── models/
│   │   │   └── user_mapping_models.dart
│   │   └── presentation/pages/
│   │       └── user_mapping_page.dart
│   └── report_designer/
```

## First-time platform setup

The project source was prepared in an environment without the Flutter SDK. Generate version-matched native platform runner files once on your development machine.

### Windows

```bat
platform_setup.bat
```

### macOS / Linux

```bash
./platform_setup.sh
```

Equivalent:

```bash
flutter create --platforms=android,ios,web --org com.cmx .
flutter pub get
```

## Run Web

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=https://your-api-host \
  --dart-define=API_VAR=v1 \
  --dart-define=AUS_CLIENT_KEY=YOUR_KEY \
  --dart-define=DEFAULT_COMPANY_ID=1
```

Windows command prompt:

```bat
flutter run -d chrome ^
  --dart-define=API_BASE_URL=https://your-api-host ^
  --dart-define=API_VAR=v1 ^
  --dart-define=AUS_CLIENT_KEY=YOUR_KEY ^
  --dart-define=DEFAULT_COMPANY_ID=1
```

## Flutter Web CORS

SGxBrokerAPI must allow the Flutter Web origin and custom headers. The middleware order should keep CORS before `MxAC`:

```csharp
app.UseRouting();
app.UseCors("CMxPortalCors");
app.UseMiddleware<MxAC>();
app.MapControllers();
```

The User Mapping APIs use `xRUT`, while AUS OTP endpoints use `xRCT` and `xRCK`.

See `docs/user_mapping_frontend.md` for the frontend/API mapping details.

## Workspace UI revision

The authenticated portal now uses a responsive left sidebar instead of the previous desktop top navigation. The sidebar can collapse to icon-only mode to maximize horizontal workspace. User Mapping was also converted to a dense administration layout so significantly more master rows remain visible in the browser viewport.

See `UI_REWORK_NOTES.md` for the UI-specific changes.
