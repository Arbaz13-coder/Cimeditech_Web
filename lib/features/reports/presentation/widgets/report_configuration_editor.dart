import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/report_configuration_models.dart';
import '../../models/report_models.dart';

enum ReportSetupSection {
  overview,
  parameters,
  columns,
  actions,
  assignments,
}

typedef ReportDraftMutation = void Function(VoidCallback mutation);

class ReportConfigurationEditor extends StatelessWidget {
  const ReportConfigurationEditor({
    super.key,
    required this.draft,
    required this.section,
    required this.dirty,
    required this.saving,
    required this.apiError,
    required this.validationErrors,
    required this.companies,
    required this.loadingCompanies,
    required this.companiesError,
    required this.onSectionChanged,
    required this.onMutate,
    required this.onSave,
  });

  final ReportConfigurationDraft draft;
  final ReportSetupSection section;
  final bool dirty;
  final bool saving;
  final String apiError;
  final List<String> validationErrors;
  final List<ReportCompany> companies;
  final bool loadingCompanies;
  final String companiesError;
  final ValueChanged<ReportSetupSection> onSectionChanged;
  final ReportDraftMutation onMutate;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EditorToolbar(
            draft: draft,
            dirty: dirty,
            saving: saving,
            onSave: onSave,
          ),
          const Divider(height: 1),
          _SectionNavigation(
            section: section,
            draft: draft,
            onChanged: onSectionChanged,
          ),
          if (apiError.isNotEmpty) ...[
            const Divider(height: 1),
            _ApiErrorNotice(message: apiError),
          ],
          if (validationErrors.isNotEmpty) ...[
            const Divider(height: 1),
            _ValidationNotice(errors: validationErrors),
          ],
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: switch (section) {
                ReportSetupSection.overview => _OverviewEditor(
                    draft: draft,
                    disabled: saving,
                    onMutate: onMutate,
                  ),
                ReportSetupSection.parameters => _ParameterEditor(
                    draft: draft,
                    disabled: saving,
                    onMutate: onMutate,
                  ),
                ReportSetupSection.columns => _ColumnEditor(
                    draft: draft,
                    disabled: saving,
                    onMutate: onMutate,
                  ),
                ReportSetupSection.actions => _ActionEditor(
                    draft: draft,
                    disabled: saving,
                    onMutate: onMutate,
                  ),
                ReportSetupSection.assignments => _AssignmentEditor(
                    draft: draft,
                    disabled: saving,
                    onMutate: onMutate,
                    companies: companies,
                    loadingCompanies: loadingCompanies,
                    companiesError: companiesError,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.draft,
    required this.dirty,
    required this.saving,
    required this.onSave,
  });

  final ReportConfigurationDraft draft;
  final bool dirty;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final title = draft.displayName.trim().isNotEmpty
        ? draft.displayName.trim()
        : draft.reportName.trim().isNotEmpty
            ? draft.reportName.trim()
            : 'New report configuration';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F3FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Color(0xFF6941C6),
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF101828),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(
                      text: draft.isNew
                          ? 'NEW'
                          : 'VERSION ${draft.definitionVersion}',
                      color: const Color(0xFF6941C6),
                      background: const Color(0xFFF4F3FF),
                    ),
                    if (dirty) ...[
                      const SizedBox(width: 6),
                      const _StatusBadge(
                        text: 'UNSAVED',
                        color: Color(0xFFB54708),
                        background: Color(0xFFFFFAEB),
                      ),
                    ],
                  ],
                ),
                Text(
                  draft.reportCode.trim().isEmpty
                      ? 'Complete the overview fields to register this report'
                      : draft.reportCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SectionNavigation extends StatelessWidget {
  const _SectionNavigation({
    required this.section,
    required this.draft,
    required this.onChanged,
  });

  final ReportSetupSection section;
  final ReportConfigurationDraft draft;
  final ValueChanged<ReportSetupSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        children: [
          _SectionButton(
            icon: Icons.info_outline_rounded,
            label: 'Overview',
            selected: section == ReportSetupSection.overview,
            onTap: () => onChanged(ReportSetupSection.overview),
          ),
          _SectionButton(
            icon: Icons.tune_rounded,
            label: 'Parameters',
            count: draft.parameters.length,
            selected: section == ReportSetupSection.parameters,
            onTap: () => onChanged(ReportSetupSection.parameters),
          ),
          _SectionButton(
            icon: Icons.view_column_outlined,
            label: 'Columns',
            count: draft.columns.length,
            selected: section == ReportSetupSection.columns,
            onTap: () => onChanged(ReportSetupSection.columns),
          ),
          _SectionButton(
            icon: Icons.bolt_outlined,
            label: 'Actions',
            count: draft.actions.length,
            selected: section == ReportSetupSection.actions,
            onTap: () => onChanged(ReportSetupSection.actions),
          ),
          _SectionButton(
            icon: Icons.group_outlined,
            label: 'Assignments',
            count: draft.assignments.length,
            selected: section == ReportSetupSection.assignments,
            onTap: () => onChanged(ReportSetupSection.assignments),
          ),
        ],
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? const Color(0xFFF4F3FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? const Color(0xFF6941C6)
                      : const Color(0xFF667085),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF6941C6)
                        : const Color(0xFF475467),
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFE9D7FE)
                          : const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF6941C6)
                            : const Color(0xFF667085),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewEditor extends StatelessWidget {
  const _OverviewEditor({
    required this.draft,
    required this.disabled,
    required this.onMutate,
  });

  final ReportConfigurationDraft draft;
  final bool disabled;
  final ReportDraftMutation onMutate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionIntro(
          icon: Icons.info_outline_rounded,
          title: 'Report identity and execution',
          description:
              'Register the function that returns this report and define safe paging limits.',
        ),
        const SizedBox(height: 12),
        _EditorCard(
          title: 'General information',
          child: _FieldGrid(
            children: [
              _ConfigTextField(
                fieldKey: 'report-name',
                label: 'Report name',
                value: draft.reportName,
                enabled: !disabled,
                requiredField: true,
                onChanged: (value) =>
                    onMutate(() => draft.reportName = value),
              ),
              _ConfigTextField(
                fieldKey: 'display-name',
                label: 'Display name',
                value: draft.displayName,
                enabled: !disabled,
                requiredField: true,
                onChanged: (value) =>
                    onMutate(() => draft.displayName = value),
              ),
              _ConfigTextField(
                fieldKey: 'report-code',
                label: 'Report code',
                value: draft.reportCode,
                enabled: !disabled,
                requiredField: true,
                hint: 'sales.register',
                onChanged: (value) =>
                    onMutate(() => draft.reportCode = value),
              ),
              _ConfigDropdown(
                label: 'Report type',
                value: draft.reportType,
                values: reportTypes,
                enabled: !disabled,
                onChanged: (value) =>
                    onMutate(() => draft.reportType = value),
              ),
              _ConfigTextField(
                fieldKey: 'report-subtype',
                label: 'Subtype / category',
                value: draft.reportSubtype,
                enabled: !disabled,
                hint: 'Sales',
                onChanged: (value) =>
                    onMutate(() => draft.reportSubtype = value),
              ),
              _ConfigTextField(
                fieldKey: 'data-function',
                label: 'PostgreSQL data function',
                value: draft.dataFunction,
                enabled: !disabled,
                requiredField: true,
                hint: 'rpt.fn_sales_register',
                onChanged: (value) =>
                    onMutate(() => draft.dataFunction = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _EditorCard(
          title: 'Execution limits',
          child: _FieldGrid(
            children: [
              _ConfigNumberField(
                fieldKey: 'default-page-size',
                label: 'Default page size',
                value: draft.defaultPageSize,
                enabled: !disabled,
                onChanged: (value) =>
                    onMutate(() => draft.defaultPageSize = value),
              ),
              _ConfigNumberField(
                fieldKey: 'maximum-page-size',
                label: 'Maximum page size',
                value: draft.maxPageSize,
                enabled: !disabled,
                onChanged: (value) =>
                    onMutate(() => draft.maxPageSize = value),
              ),
              _ConfigNumberField(
                fieldKey: 'timeout-seconds',
                label: 'Timeout (seconds)',
                value: draft.timeoutSeconds,
                enabled: !disabled,
                onChanged: (value) =>
                    onMutate(() => draft.timeoutSeconds = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _EditorCard(
          title: 'Availability',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ToggleTile(
                title: 'Active',
                subtitle: 'Available for runtime use',
                value: draft.isActive,
                enabled: !disabled,
                onChanged: (value) =>
                    onMutate(() => draft.isActive = value),
              ),
              _ToggleTile(
                title: 'Default report',
                subtitle: 'Visible without assignments',
                value: draft.isDefault,
                enabled: !disabled,
                onChanged: (value) =>
                    onMutate(() => draft.isDefault = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const _HelpNotice(
          text:
              'The backend accepts only set-returning functions in the rpt schema with the fixed runtime signature.',
        ),
      ],
    );
  }
}

class _ParameterEditor extends StatelessWidget {
  const _ParameterEditor({
    required this.draft,
    required this.disabled,
    required this.onMutate,
  });

  final ReportConfigurationDraft draft;
  final bool disabled;
  final ReportDraftMutation onMutate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionIntro(
          icon: Icons.tune_rounded,
          title: 'Report parameters',
          description:
              'These fields dynamically build the runtime filter form. RID, OID and UID remain server context and are not added here.',
          actionLabel: 'Add parameter',
          onAction: disabled
              ? null
              : () => onMutate(
                    () => draft.parameters.add(
                      ReportParameterDraft.empty(draft.parameters.length + 1),
                    ),
                  ),
        ),
        const SizedBox(height: 12),
        if (draft.parameters.isEmpty)
          const _EmptySection(
            icon: Icons.filter_alt_off_outlined,
            title: 'No report parameters',
            message:
                'This report will run without user-entered filters. Add a parameter when the function expects a value in p_filters.',
          )
        else
          ...draft.parameters.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ItemEditorCard(
                key: ValueKey('parameter-${item.localId}'),
                title: item.displayName.trim().isEmpty
                    ? 'Parameter ${index + 1}'
                    : item.displayName,
                subtitle: item.name.trim().isEmpty
                    ? 'Configure parameter name and control'
                    : '${item.name} · ${item.dataType}',
                active: item.isActive,
                onDelete: disabled
                    ? null
                    : () => onMutate(() => draft.parameters.removeAt(index)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FieldGrid(
                      children: [
                        _ConfigTextField(
                          fieldKey: 'p-name-${item.localId}',
                          label: 'Parameter name',
                          value: item.name,
                          enabled: !disabled,
                          requiredField: true,
                          hint: 'fromDate',
                          onChanged: (value) =>
                              onMutate(() => item.name = value),
                        ),
                        _ConfigTextField(
                          fieldKey: 'p-display-${item.localId}',
                          label: 'Display name',
                          value: item.displayName,
                          enabled: !disabled,
                          requiredField: true,
                          onChanged: (value) =>
                              onMutate(() => item.displayName = value),
                        ),
                        _ConfigDropdown(
                          label: 'Data type',
                          value: item.dataType,
                          values: reportParameterDataTypes,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.dataType = value),
                        ),
                        _ConfigDropdown(
                          label: 'UI element',
                          value: item.uiElementType,
                          values: reportParameterUiTypes,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.uiElementType = value),
                        ),
                        _ConfigNumberField(
                          fieldKey: 'p-order-${item.localId}',
                          label: 'Display order',
                          value: item.displayOrder,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.displayOrder = value),
                        ),
                        _ConfigTextField(
                          fieldKey: 'p-function-${item.localId}',
                          label: 'Lookup function (optional)',
                          value: item.dataFunction,
                          enabled: !disabled,
                          hint: 'rpt.fn_lookup_parties',
                          onChanged: (value) =>
                              onMutate(() => item.dataFunction = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ToggleTile(
                          title: 'Required',
                          subtitle: 'Must be supplied before execution',
                          value: item.isRequired,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.isRequired = value),
                        ),
                        _ToggleTile(
                          title: 'Multiple values',
                          subtitle: 'Sends a JSON array',
                          value: item.allowMultiple,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.allowMultiple = value),
                        ),
                        _ToggleTile(
                          title: 'Active',
                          subtitle: 'Show this filter',
                          value: item.isActive,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.isActive = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _JsonGrid(
                      children: [
                        _ConfigTextField(
                          fieldKey: 'p-default-${item.localId}',
                          label: 'Default value (JSON)',
                          value: item.defaultValueJson,
                          enabled: !disabled,
                          hint: 'null, false, "ALL" or [1, 2]',
                          maxLines: 4,
                          onChanged: (value) =>
                              onMutate(() => item.defaultValueJson = value),
                        ),
                        _ConfigTextField(
                          fieldKey: 'p-validation-${item.localId}',
                          label: 'Validation (JSON object)',
                          value: item.validationJson,
                          enabled: !disabled,
                          maxLines: 4,
                          onChanged: (value) =>
                              onMutate(() => item.validationJson = value),
                        ),
                        _ConfigTextField(
                          fieldKey: 'p-dependencies-${item.localId}',
                          label: 'Dependencies (JSON array)',
                          value: item.dependenciesJson,
                          enabled: !disabled,
                          hint: '["parentParameter"]',
                          maxLines: 4,
                          onChanged: (value) =>
                              onMutate(() => item.dependenciesJson = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _ColumnEditor extends StatelessWidget {
  const _ColumnEditor({
    required this.draft,
    required this.disabled,
    required this.onMutate,
  });

  final ReportConfigurationDraft draft;
  final bool disabled;
  final ReportDraftMutation onMutate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionIntro(
          icon: Icons.view_column_outlined,
          title: 'Result columns',
          description:
              'Column names must exactly match aliases returned by the PostgreSQL report function.',
          actionLabel: 'Add column',
          onAction: disabled
              ? null
              : () => onMutate(
                    () => draft.columns.add(
                      ReportColumnDraft.empty(draft.columns.length + 1),
                    ),
                  ),
        ),
        const SizedBox(height: 12),
        if (draft.columns.isEmpty)
          const _EmptySection(
            icon: Icons.view_column_outlined,
            title: 'No report columns',
            message: 'At least one active result column is required before saving.',
          )
        else
          ...draft.columns.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ItemEditorCard(
                key: ValueKey('column-${item.localId}'),
                title: item.displayName.trim().isEmpty
                    ? 'Column ${index + 1}'
                    : item.displayName,
                subtitle: item.name.trim().isEmpty
                    ? 'Configure the result alias'
                    : '${item.name} · ${item.dataType}',
                active: item.isActive,
                onDelete: disabled
                    ? null
                    : () => onMutate(() => draft.columns.removeAt(index)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FieldGrid(
                      children: [
                        _ConfigTextField(
                          fieldKey: 'c-name-${item.localId}',
                          label: 'Column name',
                          value: item.name,
                          enabled: !disabled,
                          requiredField: true,
                          hint: 'voucher_date',
                          onChanged: (value) =>
                              onMutate(() => item.name = value),
                        ),
                        _ConfigTextField(
                          fieldKey: 'c-display-${item.localId}',
                          label: 'Display name',
                          value: item.displayName,
                          enabled: !disabled,
                          requiredField: true,
                          onChanged: (value) =>
                              onMutate(() => item.displayName = value),
                        ),
                        _ConfigDropdown(
                          label: 'Data type',
                          value: item.dataType,
                          values: reportColumnDataTypes,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.dataType = value),
                        ),
                        _ConfigTextField(
                          fieldKey: 'c-format-${item.localId}',
                          label: 'Format code',
                          value: item.format,
                          enabled: !disabled,
                          hint: 'DATE, CURRENCY_2, DECIMAL_2',
                          onChanged: (value) =>
                              onMutate(() => item.format = value),
                        ),
                        _ConfigDropdown(
                          label: 'Alignment',
                          value: item.alignment,
                          values: reportColumnAlignments,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.alignment = value),
                        ),
                        _ConfigNumberField(
                          fieldKey: 'c-order-${item.localId}',
                          label: 'Display order',
                          value: item.displayOrder,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.displayOrder = value),
                        ),
                        _ConfigNullableNumberField(
                          fieldKey: 'c-width-${item.localId}',
                          label: 'Width (optional)',
                          value: item.width,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.width = value),
                        ),
                        _ConfigTextField(
                          fieldKey: 'c-aggregate-${item.localId}',
                          label: 'Aggregate type',
                          value: item.aggregateType,
                          enabled: !disabled,
                          hint: 'SUM, AVG or blank',
                          onChanged: (value) =>
                              onMutate(() => item.aggregateType = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ToggleTile(
                          title: 'Visible',
                          subtitle: 'Show in the grid',
                          value: item.isVisible,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.isVisible = value),
                        ),
                        _ToggleTile(
                          title: 'Sortable',
                          subtitle: 'Allow server sorting',
                          value: item.isSortable,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.isSortable = value),
                        ),
                        _ToggleTile(
                          title: 'Filterable',
                          subtitle: 'Reserved for column filters',
                          value: item.isFilterable,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.isFilterable = value),
                        ),
                        _ToggleTile(
                          title: 'Exportable',
                          subtitle: 'Include in exports',
                          value: item.isExportable,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.isExportable = value),
                        ),
                        _ToggleTile(
                          title: 'Total column',
                          subtitle: 'Marks an aggregate value',
                          value: item.isTotal,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.isTotal = value),
                        ),
                        _ToggleTile(
                          title: 'Active',
                          subtitle: 'Validate function output',
                          value: item.isActive,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.isActive = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _ActionEditor extends StatelessWidget {
  const _ActionEditor({
    required this.draft,
    required this.disabled,
    required this.onMutate,
  });

  final ReportConfigurationDraft draft;
  final bool disabled;
  final ReportDraftMutation onMutate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionIntro(
          icon: Icons.bolt_outlined,
          title: 'Report actions',
          description:
              'Actions are stored for allowlisted toolbar, row or selection handlers. Runtime support can be enabled action by action.',
          actionLabel: 'Add action',
          onAction: disabled
              ? null
              : () => onMutate(
                    () => draft.actions.add(
                      ReportActionDraft.empty(draft.actions.length + 1),
                    ),
                  ),
        ),
        const SizedBox(height: 12),
        if (draft.actions.isEmpty)
          const _EmptySection(
            icon: Icons.bolt_outlined,
            title: 'No actions configured',
            message: 'This section is optional and can remain empty.',
          )
        else
          ...draft.actions.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ItemEditorCard(
                key: ValueKey('action-${item.localId}'),
                title: item.displayName.trim().isEmpty
                    ? 'Action ${index + 1}'
                    : item.displayName,
                subtitle: item.code.trim().isEmpty
                    ? 'Configure an allowlisted handler'
                    : '${item.code} · ${item.scope}',
                active: item.isActive,
                onDelete: disabled
                    ? null
                    : () => onMutate(() => draft.actions.removeAt(index)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FieldGrid(
                      children: [
                        _ConfigTextField(
                          fieldKey: 'a-code-${item.localId}',
                          label: 'Action code',
                          value: item.code,
                          enabled: !disabled,
                          requiredField: true,
                          hint: 'OPEN_VOUCHER',
                          onChanged: (value) =>
                              onMutate(() => item.code = value),
                        ),
                        _ConfigTextField(
                          fieldKey: 'a-display-${item.localId}',
                          label: 'Display name',
                          value: item.displayName,
                          enabled: !disabled,
                          requiredField: true,
                          onChanged: (value) =>
                              onMutate(() => item.displayName = value),
                        ),
                        _ConfigDropdown(
                          label: 'Scope',
                          value: item.scope,
                          values: reportActionScopes,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.scope = value),
                        ),
                        _ConfigTextField(
                          fieldKey: 'a-handler-${item.localId}',
                          label: 'Handler key',
                          value: item.handlerKey,
                          enabled: !disabled,
                          requiredField: true,
                          hint: 'OpenVoucherHandler',
                          onChanged: (value) =>
                              onMutate(() => item.handlerKey = value),
                        ),
                        _ConfigNumberField(
                          fieldKey: 'a-order-${item.localId}',
                          label: 'Display order',
                          value: item.displayOrder,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.displayOrder = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ConfigTextField(
                      fieldKey: 'a-config-${item.localId}',
                      label: 'Configuration (JSON object)',
                      value: item.configJson,
                      enabled: !disabled,
                      maxLines: 5,
                      onChanged: (value) =>
                          onMutate(() => item.configJson = value),
                    ),
                    const SizedBox(height: 10),
                    _ToggleTile(
                      title: 'Active',
                      subtitle: 'Expose this action in metadata',
                      value: item.isActive,
                      enabled: !disabled,
                      onChanged: (value) =>
                          onMutate(() => item.isActive = value),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _AssignmentEditor extends StatelessWidget {
  const _AssignmentEditor({
    required this.draft,
    required this.disabled,
    required this.onMutate,
    required this.companies,
    required this.loadingCompanies,
    required this.companiesError,
  });

  final ReportConfigurationDraft draft;
  final bool disabled;
  final ReportDraftMutation onMutate;
  final List<ReportCompany> companies;
  final bool loadingCompanies;
  final String companiesError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionIntro(
          icon: Icons.group_outlined,
          title: 'Company and user assignments',
          description:
              'Leave User ID blank to assign the report to the complete company. An exact user row takes precedence.',
          actionLabel: 'Add assignment',
          onAction: disabled
              ? null
              : () => onMutate(
                    () => draft.assignments.add(
                      ReportAssignmentDraft.empty(),
                    ),
                  ),
        ),
        const SizedBox(height: 10),
        if (draft.isDefault)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _HelpNotice(
              text:
                  'This is a default report, so assignments are optional. Add an exact user row only when you need an override.',
            ),
          ),
        if (loadingCompanies)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (companiesError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _HelpNotice(
              text:
                  'Company names could not be loaded. You can still enter an OID manually. $companiesError',
            ),
          ),
        if (draft.assignments.isEmpty)
          _EmptySection(
            icon: Icons.group_off_outlined,
            title: 'No assignments configured',
            message: draft.isDefault
                ? 'All eligible companies can see this default report unless overridden.'
                : 'An active non-default report needs at least one view-enabled assignment.',
          )
        else
          ...draft.assignments.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ItemEditorCard(
                key: ValueKey('assignment-${item.localId}'),
                title: item.uId == null
                    ? 'Company assignment ${index + 1}'
                    : 'User assignment ${index + 1}',
                subtitle: item.oId <= 0
                    ? 'Select a company'
                    : '${item.rId <= 0 ? 'Current RID' : 'RID ${item.rId}'} · OID ${item.oId}${item.uId == null ? ' · All users' : ' · UID ${item.uId}'}',
                active: item.isActive,
                onDelete: disabled
                    ? null
                    : () => onMutate(() => draft.assignments.removeAt(index)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FieldGrid(
                      children: [
                        _ConfigNullableNumberField(
                          fieldKey: 'm-rid-${item.localId}',
                          label: 'Registration ID (optional)',
                          value: item.rId <= 0 ? null : item.rId,
                          enabled: !disabled,
                          hint: 'Blank = current registration',
                          onChanged: (value) => onMutate(
                            () => item.rId = value ?? 0,
                          ),
                        ),
                        if (companies.isEmpty)
                          _ConfigNumberField(
                            fieldKey: 'm-oid-${item.localId}',
                            label: 'Company ID (OID)',
                            value: item.oId,
                            enabled: !disabled,
                            onChanged: (value) =>
                                onMutate(() => item.oId = value),
                          )
                        else
                          _ConfigCompanyField(
                            value: item.oId,
                            companies: companies,
                            enabled: !disabled,
                            onChanged: (value) =>
                                onMutate(() => item.oId = value),
                          ),
                        _ConfigNullableNumberField(
                          fieldKey: 'm-uid-${item.localId}',
                          label: 'User ID (optional)',
                          value: item.uId,
                          enabled: !disabled,
                          hint: 'Blank = complete company',
                          onChanged: (value) =>
                              onMutate(() => item.uId = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ToggleTile(
                          title: 'Can view',
                          subtitle: 'Show report in catalog',
                          value: item.canView,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.canView = value),
                        ),
                        _ToggleTile(
                          title: 'Can export',
                          subtitle: 'Allow report export',
                          value: item.canExport,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.canExport = value),
                        ),
                        _ToggleTile(
                          title: 'Active',
                          subtitle: 'Apply this assignment',
                          value: item.isActive,
                          enabled: !disabled,
                          onChanged: (value) =>
                              onMutate(() => item.isActive = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F3FF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: const Color(0xFF6941C6), size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _ItemEditorCard extends StatelessWidget {
  const _ItemEditorCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.child,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool active;
  final Widget child;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFECFDF3)
                : const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            active ? Icons.check_rounded : Icons.pause_rounded,
            color: active
                ? const Color(0xFF039855)
                : const Color(0xFF98A2B3),
            size: 17,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF101828),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF667085), fontSize: 10),
        ),
        trailing: IconButton(
          tooltip: 'Remove',
          onPressed: onDelete,
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Color(0xFFD92D20),
            size: 19,
          ),
        ),
        children: [child],
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 920
            ? 3
            : constraints.maxWidth >= 580
                ? 2
                : 1;
        final width = count == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (count - 1) * 10) / count;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _JsonGrid extends StatelessWidget {
  const _JsonGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 820 ? 2 : 1;
        final width = count == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _ConfigTextField extends StatelessWidget {
  const _ConfigTextField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.hint,
    this.requiredField = false,
    this.maxLines = 1,
  });

  final String fieldKey;
  final String label;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool requiredField;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey(fieldKey),
      initialValue: value,
      enabled: enabled,
      minLines: maxLines == 1 ? 1 : 2,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(
        fontFamily: maxLines > 1 ? 'monospace' : null,
        fontSize: maxLines > 1 ? 12 : null,
      ),
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

class _ConfigNumberField extends StatelessWidget {
  const _ConfigNumberField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String fieldKey;
  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey(fieldKey),
      initialValue: value <= 0 ? '' : '$value',
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (text) => onChanged(int.tryParse(text) ?? 0),
      decoration: InputDecoration(labelText: '$label *'),
    );
  }
}

class _ConfigNullableNumberField extends StatelessWidget {
  const _ConfigNullableNumberField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.hint,
  });

  final String fieldKey;
  final String label;
  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey(fieldKey),
      initialValue: value == null ? '' : '$value',
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (text) => onChanged(int.tryParse(text)),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _ConfigDropdown extends StatelessWidget {
  const _ConfigDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = values.contains(value.toUpperCase())
        ? value.toUpperCase()
        : values.first;
    return DropdownButtonFormField<String>(
      value: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: '$label *'),
      items: values
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: enabled
          ? (next) {
              if (next != null) onChanged(next);
            }
          : null,
    );
  }
}

class _ConfigCompanyField extends StatelessWidget {
  const _ConfigCompanyField({
    required this.value,
    required this.companies,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final List<ReportCompany> companies;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final seen = <int>{};
    final options = companies
        .where((company) => company.id > 0 && seen.add(company.id))
        .toList(growable: false);
    final knownValue = options.any((company) => company.id == value);

    return DropdownButtonFormField<int>(
      value: value > 0 ? value : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Company *',
        hintText: 'Select company',
        prefixIcon: Icon(Icons.business_outlined, size: 19),
      ),
      items: <DropdownMenuItem<int>>[
        if (value > 0 && !knownValue)
          DropdownMenuItem<int>(
            value: value,
            child: Text(
              'Company $value (OID $value)',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ...options.map(
          (company) => DropdownMenuItem<int>(
            value: company.id,
            child: Text(
              '${company.effectiveName} (OID ${company.id})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: enabled
          ? (next) {
              if (next != null) onChanged(next);
            }
          : null,
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 58,
      padding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF9F5FF) : const Color(0xFFFCFCFD),
        border: Border.all(
          color: value ? const Color(0xFFD6BBFB) : const Color(0xFFE4E7EC),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF344054),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: const Color(0xFF98A2B3)),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ValidationNotice extends StatelessWidget {
  const _ValidationNotice({required this.errors});
  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    final visible = errors.take(6).toList(growable: false);
    return Container(
      color: const Color(0xFFFEF3F2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB42318),
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please correct the configuration before saving:',
                  style: TextStyle(
                    color: Color(0xFFB42318),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                ...visible.map(
                  (error) => Text(
                    '• $error',
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 10,
                    ),
                  ),
                ),
                if (errors.length > visible.length)
                  Text(
                    '…and ${errors.length - visible.length} more issue(s).',
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiErrorNotice extends StatelessWidget {
  const _ApiErrorNotice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFEF3F2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFB42318),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpNotice extends StatelessWidget {
  const _HelpNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF175CD3),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF175CD3),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: .3,
        ),
      ),
    );
  }
}
