# CMX Portal UI rework

This revision keeps the existing API and page functionality but changes the portal layout to prioritize usable workspace.

## Portal shell
- Desktop top navigation replaced with a left sidebar.
- Sidebar is collapsible from 228px to 76px.
- Collapsed items keep tooltips for fast navigation.
- Mobile/tablet uses a dark drawer.
- A 54px compact page header replaces the old 72px navbar.

## User Mapping density
- Removed the large page-title/company card because the portal header already identifies the module.
- Company selection and user search now live in the compact left user panel.
- User rows reduced to 52px.
- User identity, master selector, Select All, Save and Revoke are combined into one compact control bar.
- Master search and access counts are combined into a second 46px toolbar.
- Mapping rows use a fixed 42px height.
- Mapping footer uses only 46px and keeps page-size + previous/next paging.
- The result is substantially more visible records per viewport while preserving selection across pages and all backend behavior.
