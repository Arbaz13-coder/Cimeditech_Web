class PortalCompany {
  const PortalCompany({
    required this.id,
    required this.name,
    required this.accountBooksStartDate,
  });

  final int id;
  final String name;
  final String accountBooksStartDate;

  factory PortalCompany.fromJson(Map<String, dynamic> json) {
    return PortalCompany(
      id: int.tryParse(json['O_id']?.toString() ?? '') ?? 0,
      name: json['O_name']?.toString() ?? '',
      accountBooksStartDate: json['O_acc_books_start_xdt']?.toString() ?? '',
    );
  }
}

class UserMappingMasterType {
  const UserMappingMasterType({
    required this.type,
    required this.name,
  });

  final String type;
  final String name;

  factory UserMappingMasterType.fromJson(Map<String, dynamic> json) {
    return UserMappingMasterType(
      type: json['master_type']?.toString() ?? '',
      name: json['master_name']?.toString() ?? '',
    );
  }
}

class UserMappingUser {
  const UserMappingUser({
    required this.id,
    required this.name,
    required this.loginId,
    required this.type,
    required this.status,
  });

  final int id;
  final String name;
  final String loginId;
  final String type;
  final String status;

  factory UserMappingUser.fromJson(Map<String, dynamic> json) {
    return UserMappingUser(
      id: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      name: json['user_name']?.toString() ?? '',
      loginId: json['login_id']?.toString() ?? '',
      type: json['user_type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class UserMappingRow {
  const UserMappingRow({
    required this.id,
    required this.name,
    required this.group,
    required this.isSelected,
  });

  final int id;
  final String name;
  final String group;
  final bool isSelected;

  factory UserMappingRow.fromJson(Map<String, dynamic> json) {
    return UserMappingRow(
      id: int.tryParse(json['Id']?.toString() ?? json['id']?.toString() ?? '') ?? 0,
      name: json['Name']?.toString() ?? json['name']?.toString() ?? '',
      group: json['Group']?.toString() ?? json['group']?.toString() ?? '',
      isSelected: _asBool(json['IsSelected'] ?? json['isSelected']),
    );
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }
}

class UserMappingPageData {
  const UserMappingPageData({
    required this.userId,
    required this.companyId,
    required this.masterType,
    required this.selectAll,
    required this.selectedIds,
    required this.count,
    required this.pageNo,
    required this.pageSize,
    required this.totalPages,
    required this.rows,
  });

  final int userId;
  final int companyId;
  final String masterType;
  final bool selectAll;
  final Set<int> selectedIds;
  final int count;
  final int pageNo;
  final int pageSize;
  final int totalPages;
  final List<UserMappingRow> rows;

  factory UserMappingPageData.fromJson(Map<String, dynamic> json) {
    final rawSelected = json['select_value'];
    final selected = <int>{};
    if (rawSelected is List) {
      for (final item in rawSelected) {
        final id = int.tryParse(item.toString()) ?? 0;
        if (id > 0) selected.add(id);
      }
    }

    final rawRows = json['vRows'];
    final rows = <UserMappingRow>[];
    if (rawRows is List) {
      for (final row in rawRows) {
        if (row is Map) {
          rows.add(
            UserMappingRow.fromJson(
              row.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    return UserMappingPageData(
      userId: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      companyId: int.tryParse(json['company_id']?.toString() ?? '') ?? 0,
      masterType: json['master_type']?.toString() ?? '',
      selectAll: UserMappingRow._asBool(json['select_all']),
      selectedIds: selected,
      count: int.tryParse(json['RCount']?.toString() ?? '') ?? 0,
      pageNo: int.tryParse(json['RPageNo']?.toString() ?? '') ?? 1,
      pageSize: int.tryParse(json['RPageSize']?.toString() ?? '') ?? 100,
      totalPages: int.tryParse(json['RTotalPages']?.toString() ?? '') ?? 1,
      rows: rows,
    );
  }
}
