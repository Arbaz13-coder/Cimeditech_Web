import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/models/api_response.dart';
import '../../data/user_mapping_repository.dart';
import '../../models/user_mapping_models.dart';

class UserMappingPage extends StatefulWidget {
  const UserMappingPage({
    super.key,
    required this.repository,
  });

  final UserMappingRepository repository;

  @override
  State<UserMappingPage> createState() => _UserMappingPageState();
}

class _UserMappingPageState extends State<UserMappingPage> {
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _masterSearchController = TextEditingController();

  List<PortalCompany> _companies = const [];
  List<UserMappingMasterType> _masterTypes = const [];
  List<UserMappingUser> _users = const [];
  PortalCompany? _selectedCompany;
  UserMappingMasterType? _selectedMaster;
  UserMappingUser? _selectedUser;
  UserMappingPageData? _mapping;

  Set<int> _selectedIds = <int>{};
  bool _selectAll = false;
  bool _dirty = false;
  bool _loadingInitial = true;
  bool _loadingUsers = false;
  bool _loadingMapping = false;
  bool _saving = false;
  String _error = '';
  int _companyId = AppConfig.defaultCompanyId;
  int _pageNo = 1;
  int _pageSize = 100;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _userSearchController.dispose();
    _masterSearchController.dispose();
    super.dispose();
  }

  List<UserMappingUser> get _filteredUsers {
    final search = _userSearchController.text.trim().toLowerCase();
    if (search.isEmpty) return _users;
    return _users.where((user) {
      return user.name.toLowerCase().contains(search) ||
          user.loginId.toLowerCase().contains(search) ||
          user.type.toLowerCase().contains(search);
    }).toList(growable: false);
  }

  int get _selectedCount => _selectAll ? (_mapping?.count ?? 0) : _selectedIds.length;

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _error = '';
    });

    try {
      final companies = await widget.repository.getCompanies();
      final masterTypes = await widget.repository.getMasterTypes();
      if (!mounted) return;

      PortalCompany? selectedCompany;
      for (final company in companies) {
        if (company.id == AppConfig.defaultCompanyId) {
          selectedCompany = company;
          break;
        }
      }
      selectedCompany ??= companies.isEmpty ? null : companies.first;

      setState(() {
        _companies = companies;
        _selectedCompany = selectedCompany;
        _companyId = selectedCompany?.id ?? 0;
        _masterTypes = masterTypes;
        _selectedMaster = masterTypes.isEmpty ? null : masterTypes.first;
      });

      if (selectedCompany == null) {
        setState(() => _error = 'No company is available for this login.');
      } else {
        await _loadUsers(resetSelection: true);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadUsers({required bool resetSelection}) async {
    if (_companyId <= 0) return;

    setState(() {
      _loadingUsers = true;
      _error = '';
    });

    try {
      final users = await widget.repository.getUsers(companyId: _companyId);
      if (!mounted) return;

      UserMappingUser? selected;
      if (!resetSelection && _selectedUser != null) {
        for (final user in users) {
          if (user.id == _selectedUser!.id) {
            selected = user;
            break;
          }
        }
      }
      selected ??= users.isEmpty ? null : users.first;

      setState(() {
        _users = users;
        _selectedUser = selected;
        _pageNo = 1;
      });

      if (selected != null && _selectedMaster != null) {
        await _loadMapping(resetSelection: true);
      } else if (mounted) {
        setState(() {
          _mapping = null;
          _selectedIds = <int>{};
          _selectAll = false;
          _dirty = false;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadMapping({required bool resetSelection}) async {
    final user = _selectedUser;
    final master = _selectedMaster;
    if (user == null || master == null || _companyId <= 0) return;

    setState(() {
      _loadingMapping = true;
      _error = '';
    });

    try {
      final result = await widget.repository.getMapping(
        userId: user.id,
        companyId: _companyId,
        masterType: master.type,
        search: _masterSearchController.text,
        pageNo: _pageNo,
        pageSize: _pageSize,
      );
      if (!mounted) return;

      setState(() {
        _mapping = result;
        _pageNo = result.pageNo;
        if (resetSelection) {
          _selectAll = result.selectAll;
          _selectedIds = <int>{...result.selectedIds};
          _dirty = false;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loadingMapping = false);
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_dirty) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard unsaved changes?'),
            content: const Text(
              'You changed this user mapping but have not saved it yet.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _changeCompany(PortalCompany company) async {
    if (company.id == _companyId) return;
    if (!await _confirmDiscardChanges() || !mounted) return;

    setState(() {
      _selectedCompany = company;
      _companyId = company.id;
      _selectedUser = null;
      _users = const <UserMappingUser>[];
      _mapping = null;
      _selectedIds = <int>{};
      _selectAll = false;
      _dirty = false;
      _userSearchController.clear();
      _masterSearchController.clear();
    });
    await _loadUsers(resetSelection: true);
  }

  Future<void> _changeUser(UserMappingUser user) async {
    if (_selectedUser?.id == user.id) return;
    if (!await _confirmDiscardChanges() || !mounted) return;

    setState(() {
      _selectedUser = user;
      _pageNo = 1;
      _masterSearchController.clear();
    });
    await _loadMapping(resetSelection: true);
  }

  Future<void> _changeMaster(UserMappingMasterType master) async {
    if (_selectedMaster?.type == master.type) return;
    if (!await _confirmDiscardChanges() || !mounted) return;

    setState(() {
      _selectedMaster = master;
      _pageNo = 1;
      _masterSearchController.clear();
    });
    await _loadMapping(resetSelection: true);
  }

  void _onMasterSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _pageNo = 1);
      _loadMapping(resetSelection: false);
    });
  }

  void _setSelectAll(bool value) {
    setState(() {
      _selectAll = value;
      if (!value) _selectedIds = <int>{};
      _dirty = true;
    });
  }

  void _toggleRow(UserMappingRow row, bool selected) {
    if (_selectAll) return;
    setState(() {
      if (selected) {
        _selectedIds.add(row.id);
      } else {
        _selectedIds.remove(row.id);
      }
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final user = _selectedUser;
    final master = _selectedMaster;
    if (_saving || user == null || master == null) return;

    setState(() => _saving = true);
    try {
      final response = await widget.repository.saveMapping(
        userId: user.id,
        companyId: _companyId,
        masterType: master.type,
        selectAll: _selectAll,
        selectedIds: _selectedIds,
      );
      if (!mounted) return;

      setState(() => _dirty = false);
      _showMessage(response.displayMessage, success: true);
      await _loadMapping(resetSelection: true);
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revokeAll() async {
    final user = _selectedUser;
    final master = _selectedMaster;
    if (_saving || user == null || master == null) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Revoke all access?'),
            content: Text(
              'This will remove all ${master.name} access for ${user.name}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB42318),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Revoke all'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      final response = await widget.repository.saveMapping(
        userId: user.id,
        companyId: _companyId,
        masterType: master.type,
        selectAll: false,
        selectedIds: <int>{},
      );
      if (!mounted) return;
      _showMessage(response.displayMessage, success: true);
      await _loadMapping(resetSelection: true);
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _goToPage(int page) async {
    final totalPages = _mapping?.totalPages ?? 1;
    if (page < 1 || page > totalPages || page == _pageNo) return;
    setState(() => _pageNo = page);
    await _loadMapping(resetSelection: false);
  }

  Future<void> _changePageSize(int? size) async {
    if (size == null || size == _pageSize) return;
    setState(() {
      _pageSize = size;
      _pageNo = 1;
    });
    await _loadMapping(resetSelection: false);
  }

  Future<void> _retryLoad() async {
    if (_companies.isEmpty || _masterTypes.isEmpty) {
      await _loadInitial();
      return;
    }
    await _loadUsers(resetSelection: true);
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    return ColoredBox(
      color: const Color(0xFFF5F7FA),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error.isNotEmpty) ...[
              _ErrorBanner(message: _error, onRetry: _retryLoad),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 250, child: _buildUserPanel()),
                        const SizedBox(width: 10),
                        Expanded(child: _buildMappingPanel()),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      SizedBox(height: 190, child: _buildUserPanel()),
                      const SizedBox(height: 8),
                      Expanded(child: _buildMappingPanel()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserPanel() {
    final users = _filteredUsers;

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.people_alt_outlined,
                  size: 18,
                  color: Color(0xFF175CD3),
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Users',
                    style: TextStyle(
                      color: Color(0xFF101828),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${users.length}',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
            child: DropdownButtonFormField<int>(
              value: _selectedCompany?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'Select company',
                prefixIcon: Icon(Icons.apartment_outlined, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 9),
              ),
              items: _companies
                  .map(
                    (company) => DropdownMenuItem<int>(
                      value: company.id,
                      child: Text(
                        company.name.isEmpty ? 'Company #${company.id}' : company.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _loadingUsers
                  ? null
                  : (value) {
                      if (value == null) return;
                      for (final company in _companies) {
                        if (company.id == value) {
                          _changeCompany(company);
                          break;
                        }
                      }
                    },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
            child: TextField(
              controller: _userSearchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search user',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _userSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _userSearchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded, size: 16),
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loadingUsers
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? const _EmptyState(
                        icon: Icons.person_search_outlined,
                        title: 'No users found',
                        message: 'No active users are mapped to this company.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: users.length,
                        itemExtent: 52,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final selected = user.id == _selectedUser?.id;
                          return _CompactUserTile(
                            user: user,
                            selected: selected,
                            onTap: () => _changeUser(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMappingPanel() {
    final user = _selectedUser;
    if (user == null) {
      return const _SurfaceCard(
        child: _EmptyState(
          icon: Icons.manage_accounts_outlined,
          title: 'Select a user',
          message: 'Choose a user from the list to manage master access.',
        ),
      );
    }

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMappingTopBar(user),
          const Divider(height: 1),
          _buildMappingSearchBar(),
          const Divider(height: 1),
          Expanded(
            child: _loadingMapping && _mapping == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      Positioned.fill(child: _buildRows()),
                      if (_loadingMapping)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildMappingTopBar(UserMappingUser user) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final userInfo = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(user.name.isEmpty ? user.loginId : user.name),
                style: const TextStyle(
                  color: Color(0xFF175CD3),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name.isEmpty ? user.loginId : user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF101828),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    [user.loginId, user.type]
                        .where((value) => value.trim().isNotEmpty)
                        .join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF667085), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        );

        final masterSelector = SizedBox(
          width: compact ? 200 : 190,
          child: DropdownButtonFormField<String>(
            value: _selectedMaster?.type,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Master',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            ),
            items: _masterTypes
                .map(
                  (master) => DropdownMenuItem<String>(
                    value: master.type,
                    child: Text(
                      master.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: _loadingMapping
                ? null
                : (value) {
                    if (value == null) return;
                    for (final master in _masterTypes) {
                      if (master.type == value) {
                        _changeMaster(master);
                        break;
                      }
                    }
                  },
          ),
        );

        final selectAllControl = Container(
          height: 38,
          padding: const EdgeInsets.only(left: 10, right: 2),
          decoration: BoxDecoration(
            color: _selectAll ? const Color(0xFFECFDF3) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _selectAll ? const Color(0xFFA6F4C5) : const Color(0xFFE4E7EC),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectAll ? 'All records' : 'Select all',
                style: TextStyle(
                  color: _selectAll ? const Color(0xFF067647) : const Color(0xFF475467),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Transform.scale(
                scale: .78,
                child: Switch(
                  value: _selectAll,
                  onChanged: _setSelectAll,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        );

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_dirty)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: _StatusPill(
                  label: 'Unsaved',
                  foreground: Color(0xFFB54708),
                  background: Color(0xFFFFFAEB),
                ),
              ),
            IconButton(
              tooltip: 'Revoke all access',
              visualDensity: VisualDensity.compact,
              onPressed: _saving ? null : _revokeAll,
              icon: const Icon(Icons.block_outlined, size: 19),
            ),
            const SizedBox(width: 2),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(90, 38),
                padding: const EdgeInsets.symmetric(horizontal: 11),
              ),
              onPressed: _saving || !_dirty ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 17),
              label: const Text('Save'),
            ),
          ],
        );

        if (compact) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              children: [
                Row(children: [Expanded(child: userInfo), actions]),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(child: masterSelector),
                    const SizedBox(width: 8),
                    selectAllControl,
                  ],
                ),
              ],
            ),
          );
        }

        return SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                userInfo,
                const SizedBox(width: 12),
                masterSelector,
                const SizedBox(width: 8),
                selectAllControl,
                const Spacer(),
                actions,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMappingSearchBar() {
    final totalCount = _mapping?.count ?? 0;
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _masterSearchController,
                onChanged: _onMasterSearchChanged,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search ${_selectedMaster?.name ?? 'master'} or group',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _masterSearchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            _masterSearchController.clear();
                            setState(() => _pageNo = 1);
                            _loadMapping(resetSelection: false);
                          },
                          icon: const Icon(Icons.close_rounded, size: 16),
                        ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E7EC)),
              ),
              child: Text(
                '$totalCount records • $_selectedCount allowed',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Refresh',
              visualDensity: VisualDensity.compact,
              onPressed: _loadingMapping ? null : () => _loadMapping(resetSelection: false),
              icon: const Icon(Icons.refresh_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRows() {
    final rows = _mapping?.rows ?? const <UserMappingRow>[];
    if (rows.isEmpty) {
      return const _EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No master records found',
        message: 'Try another search or master type.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final showGroup = constraints.maxWidth >= 620;
        return Column(
          children: [
            Container(
              height: 32,
              color: const Color(0xFFF9FAFB),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const SizedBox(width: 34),
                  const Expanded(flex: 5, child: Text('NAME', style: _tableHeaderStyle)),
                  if (showGroup)
                    const Expanded(flex: 3, child: Text('GROUP', style: _tableHeaderStyle)),
                  const SizedBox(
                    width: 80,
                    child: Text(
                      'ACCESS',
                      textAlign: TextAlign.right,
                      style: _tableHeaderStyle,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemExtent: 42,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final checked = _selectAll || _selectedIds.contains(row.id);
                  return DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF2F4F7))),
                    ),
                    child: InkWell(
                      onTap: _selectAll ? null : () => _toggleRow(row, !checked),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Transform.scale(
                                scale: .82,
                                child: Checkbox(
                                  value: checked,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  onChanged: _selectAll
                                      ? null
                                      : (value) => _toggleRow(row, value ?? false),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text(
                                row.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF101828),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (showGroup)
                              Expanded(
                                flex: 3,
                                child: Text(
                                  row.group.isEmpty ? '—' : row.group,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF667085),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: 80,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: checked
                                          ? const Color(0xFF12B76A)
                                          : const Color(0xFF98A2B3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    checked ? 'Allowed' : 'Blocked',
                                    style: TextStyle(
                                      color: checked
                                          ? const Color(0xFF067647)
                                          : const Color(0xFF667085),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFooter() {
    final totalPages = _mapping?.totalPages ?? 1;
    final totalCount = _mapping?.count ?? 0;
    final first = totalCount == 0 ? 0 : ((_pageNo - 1) * _pageSize) + 1;
    final last = totalCount == 0 ? 0 : ((_pageNo * _pageSize).clamp(0, totalCount));

    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Text(
              '$first–$last of $totalCount',
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            DropdownButton<int>(
              value: _pageSize,
              isDense: true,
              underline: const SizedBox.shrink(),
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              items: const [50, 100, 250, 500]
                  .map(
                    (size) => DropdownMenuItem(
                      value: size,
                      child: Text('$size / page'),
                    ),
                  )
                  .toList(),
              onChanged: _loadingMapping ? null : _changePageSize,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Previous page',
              visualDensity: VisualDensity.compact,
              onPressed: _pageNo > 1 && !_loadingMapping
                  ? () => _goToPage(_pageNo - 1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
            ),
            Text(
              '$_pageNo / $totalPages',
              style: const TextStyle(
                color: Color(0xFF344054),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            IconButton(
              tooltip: 'Next page',
              visualDensity: VisualDensity.compact,
              onPressed: _pageNo < totalPages && !_loadingMapping
                  ? () => _goToPage(_pageNo + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

const TextStyle _tableHeaderStyle = TextStyle(
  color: Color(0xFF667085),
  fontSize: 11,
  fontWeight: FontWeight.w800,
  letterSpacing: .6,
);

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.companies,
    required this.selectedCompany,
    required this.loading,
    required this.onCompanyChanged,
    required this.onRefresh,
  });

  final List<PortalCompany> companies;
  final PortalCompany? selectedCompany;
  final bool loading;
  final ValueChanged<PortalCompany> onCompanyChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final title = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Mapping',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF101828),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Control which master records each user can access.',
                style: TextStyle(color: Color(0xFF667085)),
              ),
            ],
          );

          final company = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 310),
                child: DropdownButtonFormField<int>(
                  value: selectedCompany?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Company',
                    prefixIcon: Icon(Icons.apartment_outlined, size: 20),
                    isDense: true,
                  ),
                  items: companies
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item.id,
                          child: Text(
                            item.name.isEmpty ? 'Company #${item.id}' : item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          for (final item in companies) {
                            if (item.id == value) {
                              onCompanyChanged(item);
                              return;
                            }
                          }
                        },
                ),
              ),
              IconButton.outlined(
                tooltip: 'Refresh company users',
                onPressed: loading || selectedCompany == null ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 14),
                company,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              company,
            ],
          );
        },
      ),
    );
  }
}

class _MasterTypeSelector extends StatelessWidget {
  const _MasterTypeSelector({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<UserMappingMasterType> items;
  final UserMappingMasterType? selected;
  final ValueChanged<UserMappingMasterType> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final isSelected = selected?.type == item.type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item.name),
              selected: isSelected,
              onSelected: (_) => onSelected(item),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF175CD3) : const Color(0xFF475467),
                fontWeight: FontWeight.w700,
              ),
              selectedColor: const Color(0xFFEFF4FF),
              side: BorderSide(
                color: isSelected ? const Color(0xFF84ADFF) : const Color(0xFFD0D5DD),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _AccessModeCard extends StatelessWidget {
  const _AccessModeCard({
    required this.selectAll,
    required this.selectedCount,
    required this.totalCount,
    required this.onChanged,
  });

  final bool selectAll;
  final int selectedCount;
  final int totalCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selectAll ? const Color(0xFFECFDF3) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectAll ? const Color(0xFFA6F4C5) : const Color(0xFFE4E7EC),
        ),
      ),
      child: Row(
        children: [
          Icon(
            selectAll ? Icons.all_inclusive_rounded : Icons.checklist_rounded,
            color: selectAll ? const Color(0xFF067647) : const Color(0xFF475467),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectAll ? 'All records allowed' : 'Explicit selection',
                  style: const TextStyle(
                    color: Color(0xFF101828),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selectAll
                      ? 'Includes current and future records for this master.'
                      : '$selectedCount of $totalCount records selected. Selections are preserved across pages.',
                  style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text('Select all', style: TextStyle(fontWeight: FontWeight.w700)),
          Switch(value: selectAll, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CompactUserTile extends StatelessWidget {
  const _CompactUserTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final UserMappingUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Material(
        color: selected ? const Color(0xFFEFF4FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFD1E0FF) : const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: selected ? const Color(0xFF175CD3) : const Color(0xFF667085),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? user.loginId : user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? const Color(0xFF175CD3) : const Color(0xFF101828),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        user.loginId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF667085), fontSize: 9),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_rounded, color: Color(0xFF175CD3), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final UserMappingUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEFF4FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFD1E0FF) : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: selected ? const Color(0xFF175CD3) : const Color(0xFF667085),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isEmpty ? user.loginId : user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? const Color(0xFF175CD3) : const Color(0xFF101828),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.loginId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF175CD3), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF175CD3), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF101828),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: const Color(0xFF98A2B3)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF344054),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDCA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB42318), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
