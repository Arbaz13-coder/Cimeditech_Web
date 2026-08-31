enum ReportFieldType { text, number, currency, date, percentage }

enum ReportZone { header, detail, footer }

enum ReportAlignment { left, center, right }

class BackendField {
  const BackendField({
    required this.key,
    required this.label,
    required this.group,
    required this.type,
    required this.sampleValue,
  });

  final String key;
  final String label;
  final String group;
  final ReportFieldType type;
  final Object sampleValue;
}

class ReportElement {
  const ReportElement({
    required this.id,
    required this.fieldKey,
    required this.label,
    required this.zone,
    this.width = 120,
    this.alignment = ReportAlignment.left,
    this.type = ReportFieldType.text,
    this.bold = false,
  });

  final String id;
  final String fieldKey;
  final String label;
  final ReportZone zone;
  final double width;
  final ReportAlignment alignment;
  final ReportFieldType type;
  final bool bold;


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'fieldKey': fieldKey,
      'label': label,
      'zone': zone.name,
      'width': width,
      'alignment': alignment.name,
      'type': type.name,
      'bold': bold,
    };
  }

  factory ReportElement.fromJson(Map<String, dynamic> json) {
    return ReportElement(
      id: json['id']?.toString() ?? '',
      fieldKey: json['fieldKey']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      zone: ReportZone.values.firstWhere(
        (value) => value.name == json['zone']?.toString(),
        orElse: () => ReportZone.detail,
      ),
      width: (json['width'] as num?)?.toDouble() ?? 120.0,
      alignment: ReportAlignment.values.firstWhere(
        (value) => value.name == json['alignment']?.toString(),
        orElse: () => ReportAlignment.left,
      ),
      type: ReportFieldType.values.firstWhere(
        (value) => value.name == json['type']?.toString(),
        orElse: () => ReportFieldType.text,
      ),
      bold: json['bold'] == true,
    );
  }
  ReportElement copyWith({
    String? id,
    String? fieldKey,
    String? label,
    ReportZone? zone,
    double? width,
    ReportAlignment? alignment,
    ReportFieldType? type,
    bool? bold,
  }) {
    return ReportElement(
      id: id ?? this.id,
      fieldKey: fieldKey ?? this.fieldKey,
      label: label ?? this.label,
      zone: zone ?? this.zone,
      width: width ?? this.width,
      alignment: alignment ?? this.alignment,
      type: type ?? this.type,
      bold: bold ?? this.bold,
    );
  }
}

class ReportTemplate {
  const ReportTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.reportTitle,
    required this.elements,
    this.landscape = false,
  });

  final String id;
  final String name;
  final String description;
  final String reportTitle;
  final List<ReportElement> elements;
  final bool landscape;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'reportTitle': reportTitle,
      'landscape': landscape,
      'elements': elements.map((element) => element.toJson()).toList(),
    };
  }
}
