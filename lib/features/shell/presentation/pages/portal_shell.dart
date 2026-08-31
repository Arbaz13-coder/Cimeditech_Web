import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../report_designer/presentation/pages/report_designer_page.dart';
import '../../../reports/data/report_repository.dart';
import '../../../reports/presentation/pages/report_configuration_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../user_mapping/data/user_mapping_repository.dart';
import '../../../user_mapping/presentation/pages/user_mapping_page.dart';

enum PortalSection {
  dashboard,
  dataManagement,
  reports,
  reportSetup,
  reportDesigner,
}

class PortalShell extends StatefulWidget {
  const PortalShell({
    super.key,
    required this.authRepository,
    required this.userMappingRepository,
    required this.reportRepository,
    required this.loginBuilder,
  });

  final AuthRepository authRepository;
  final UserMappingRepository userMappingRepository;
  final ReportRepository reportRepository;
  final WidgetBuilder loginBuilder;

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  PortalSection _section = PortalSection.dashboard;
  final Set<PortalSection> _visited = <PortalSection>{PortalSection.dashboard};
  bool _loggingOut = false;
  bool _sidebarCollapsed = false;

  void _select(PortalSection section) {
    if (_section == section) return;
    setState(() {
      _section = section;
      _visited.add(section);
    });
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text('You will return to the login page.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldLogout || !mounted) return;

    setState(() => _loggingOut = true);
    await widget.authRepository.clearSession();
    if (!mounted) return;

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: widget.loginBuilder),
      (_) => false,
    );
  }

  Future<void> _expireSession() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    await widget.authRepository.clearSession();
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Your session has expired. Please login again.'),
        ),
      );
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: widget.loginBuilder),
      (_) => false,
    );
  }

  Widget _buildSection(PortalSection section) {
    switch (section) {
      case PortalSection.dashboard:
        return const DashboardPage(key: PageStorageKey('dashboard'));
      case PortalSection.dataManagement:
        return UserMappingPage(
          key: const PageStorageKey('user-mapping'),
          repository: widget.userMappingRepository,
        );
      case PortalSection.reports:
        return ReportsPage(
          key: const PageStorageKey('dynamic-reports'),
          repository: widget.reportRepository,
          onSessionExpired: () => _expireSession(),
        );
      case PortalSection.reportSetup:
        return ReportConfigurationPage(
          key: const PageStorageKey('report-setup'),
          repository: widget.reportRepository,
          onSessionExpired: () => _expireSession(),
        );
      case PortalSection.reportDesigner:
        return const ReportDesignerPage(
          key: PageStorageKey('report-designer'),
          embedded: true,
        );
    }
  }

  String get _pageTitle {
    switch (_section) {
      case PortalSection.dashboard:
        return 'Dashboard';
      case PortalSection.dataManagement:
        return 'User Mapping';
      case PortalSection.reports:
        return 'Dynamic Reports';
      case PortalSection.reportSetup:
        return 'Report Setup';
      case PortalSection.reportDesigner:
        return 'Report Designer';
    }
  }

  String get _pageEyebrow {
    switch (_section) {
      case PortalSection.dashboard:
        return 'Overview';
      case PortalSection.dataManagement:
        return 'Data Management';
      case PortalSection.reports:
        return 'Reports';
      case PortalSection.reportSetup:
        return 'Reports Administration';
      case PortalSection.reportDesigner:
        return 'Reports';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 860;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      drawer: desktop
          ? null
          : _MobileSidebar(
              selected: _section,
              onSelected: (section) {
                Navigator.of(context).pop();
                _select(section);
              },
              onLogout: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (desktop)
              _DesktopSidebar(
                selected: _section,
                collapsed: _sidebarCollapsed,
                loggingOut: _loggingOut,
                onToggle: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                onSelected: _select,
                onLogout: _logout,
              ),
            Expanded(
              child: Column(
                children: [
                  _CompactHeader(
                    title: _pageTitle,
                    eyebrow: _pageEyebrow,
                    showMenu: !desktop,
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: PortalSection.values
                          .where((section) => _visited.contains(section))
                          .map(
                            (section) => Offstage(
                              offstage: section != _section,
                              child: TickerMode(
                                enabled: section == _section,
                                child: _buildSection(section),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selected,
    required this.collapsed,
    required this.loggingOut,
    required this.onToggle,
    required this.onSelected,
    required this.onLogout,
  });

  final PortalSection selected;
  final bool collapsed;
  final bool loggingOut;
  final VoidCallback onToggle;
  final ValueChanged<PortalSection> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = collapsed ? 76.0 : 228.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: sidebarWidth,
      decoration: const BoxDecoration(
        color: Color(0xFF101828),
        border: Border(right: BorderSide(color: Color(0xFF1D2939))),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 16),
              child: Row(
                children: [
                  const _BrandMark(),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'CMX Portal',
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1D2939)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!collapsed)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
                      child: Text(
                        'WORKSPACE',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  _SidebarItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Dashboard',
                    collapsed: collapsed,
                    selected: selected == PortalSection.dashboard,
                    onTap: () => onSelected(PortalSection.dashboard),
                  ),
                  const SizedBox(height: 5),
                  _SidebarItem(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Data Management',
                    subtitle: 'User Mapping',
                    collapsed: collapsed,
                    selected: selected == PortalSection.dataManagement,
                    onTap: () => onSelected(PortalSection.dataManagement),
                  ),
                  const SizedBox(height: 5),
                  _SidebarItem(
                    icon: Icons.analytics_outlined,
                    label: 'Reports',
                    subtitle: 'Dynamic Reports',
                    collapsed: collapsed,
                    selected: selected == PortalSection.reports,
                    onTap: () => onSelected(PortalSection.reports),
                  ),
                  const SizedBox(height: 5),
                  _SidebarItem(
                    icon: Icons.settings_suggest_outlined,
                    label: 'Report Setup',
                    subtitle: 'Admin Configuration',
                    collapsed: collapsed,
                    selected: selected == PortalSection.reportSetup,
                    onTap: () => onSelected(PortalSection.reportSetup),
                  ),
                  const SizedBox(height: 5),
                  _SidebarItem(
                    icon: Icons.design_services_outlined,
                    label: 'Report Designer',
                    collapsed: collapsed,
                    selected: selected == PortalSection.reportDesigner,
                    onTap: () => onSelected(PortalSection.reportDesigner),
                  ),
                  const Spacer(),
                  _SidebarItem(
                    icon: Icons.logout_rounded,
                    label: loggingOut ? 'Signing out…' : 'Sign out',
                    collapsed: collapsed,
                    selected: false,
                    onTap: loggingOut ? null : onLogout,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1D2939)),
          SizedBox(
            height: 52,
            child: Align(
              alignment: collapsed ? Alignment.center : Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: collapsed ? 0 : 10),
                child: IconButton(
                  tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                  onPressed: onToggle,
                  color: const Color(0xFF98A2B3),
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_double_arrow_right_rounded
                        : Icons.keyboard_double_arrow_left_rounded,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool collapsed;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : const Color(0xFF98A2B3);
    final item = Material(
      color: selected ? const Color(0xFF175CD3) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: subtitle == null || collapsed ? 44 : 52,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 11),
            child: Row(
              mainAxisAlignment:
                  collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(icon, color: foreground, size: 20),
                if (!collapsed) ...[
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFFD1E0FF)
                                  : const Color(0xFF667085),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (!collapsed) return item;
    return Tooltip(message: subtitle == null ? label : '$label · $subtitle', child: item);
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.title,
    required this.eyebrow,
    required this.showMenu,
  });

  final String title;
  final String eyebrow;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E7EC))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (showMenu) ...[
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF98A2B3),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .9,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 16,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_outline_rounded,
              color: Color(0xFF175CD3),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2970FF), Color(0xFF155EEF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: const Text(
        'CMX',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

class _MobileSidebar extends StatelessWidget {
  const _MobileSidebar({
    required this.selected,
    required this.onSelected,
    required this.onLogout,
  });

  final PortalSection selected;
  final ValueChanged<PortalSection> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF101828),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Row(
                children: [
                  _BrandMark(),
                  SizedBox(width: 10),
                  Text(
                    'CMX Portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1D2939)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                    _SidebarItem(
                      icon: Icons.grid_view_rounded,
                      label: 'Dashboard',
                      collapsed: false,
                      selected: selected == PortalSection.dashboard,
                      onTap: () => onSelected(PortalSection.dashboard),
                    ),
                    const SizedBox(height: 5),
                    _SidebarItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Data Management',
                      subtitle: 'User Mapping',
                      collapsed: false,
                      selected: selected == PortalSection.dataManagement,
                      onTap: () => onSelected(PortalSection.dataManagement),
                    ),
                    const SizedBox(height: 5),
                    _SidebarItem(
                      icon: Icons.analytics_outlined,
                      label: 'Reports',
                      subtitle: 'Dynamic Reports',
                      collapsed: false,
                      selected: selected == PortalSection.reports,
                      onTap: () => onSelected(PortalSection.reports),
                    ),
                    const SizedBox(height: 5),
                    _SidebarItem(
                      icon: Icons.settings_suggest_outlined,
                      label: 'Report Setup',
                      subtitle: 'Admin Configuration',
                      collapsed: false,
                      selected: selected == PortalSection.reportSetup,
                      onTap: () => onSelected(PortalSection.reportSetup),
                    ),
                    const SizedBox(height: 5),
                    _SidebarItem(
                      icon: Icons.design_services_outlined,
                      label: 'Report Designer',
                      collapsed: false,
                      selected: selected == PortalSection.reportDesigner,
                      onTap: () => onSelected(PortalSection.reportDesigner),
                    ),
                    const SizedBox(height: 24),
                    _SidebarItem(
                      icon: Icons.logout_rounded,
                      label: 'Sign out',
                      collapsed: false,
                      selected: false,
                      onTap: onLogout,
                    ),
                  ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
