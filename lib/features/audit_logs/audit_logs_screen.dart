import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  List<Map<String, dynamic>> _auditLogs = [];
  List<String> _actions = [];
  List<String> _entityTypes = [];

  bool _isLoading = true;
  String? _error;
  String _actionFilter = 'all';
  String _entityTypeFilter = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;

  int _currentPage = 1;
  int _pageSize = 25;
  int _total = 0;
  int _totalPages = 0;
  int _loadRequestId = 0;
  final Set<int> _expandedIds = <int>{};

  static const Color _red = Color(0xFFE50914);
  static const Color _card = Color(0xFF202020);
  static const Color _border = Color(0xFF383838);
  static const Color _muted = Color(0xFFB0B0B0);
  static const Color _dark = Color(0xFF101010);
  static const Color _background = Color(0xFF101010);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _dateParam(DateTime? value) {
    if (value == null) return '';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _loadData({bool showLoading = true}) async {
    final requestId = ++_loadRequestId;

    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await _authService.getPlatformAuditLogs(
        search: _searchController.text.trim(),
        action: _actionFilter,
        entityType: _entityTypeFilter,
        fromDate: _dateParam(_fromDate),
        toDate: _dateParam(_toDate),
        page: _currentPage,
        limit: _pageSize,
      );

      if (!mounted || requestId != _loadRequestId) return;

      final pagination = Map<String, dynamic>.from(
        response['pagination'] as Map,
      );
      final rows = response['auditLogs'] as List;
      final actionValues = response['actions'] as List? ?? const [];
      final entityValues = response['entityTypes'] as List? ?? const [];

      setState(() {
        _auditLogs = rows.whereType<Map>().map((row) {
          return Map<String, dynamic>.from(row);
        }).toList();
        _actions = actionValues.map((value) => value.toString()).toList();
        _entityTypes = entityValues.map((value) => value.toString()).toList();
        _currentPage = (pagination['page'] as num?)?.toInt() ?? _currentPage;
        _pageSize = (pagination['limit'] as num?)?.toInt() ?? _pageSize;
        _total = (pagination['total'] as num?)?.toInt() ?? 0;
        _totalPages = (pagination['totalPages'] as num?)?.toInt() ?? 0;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _error = _cleanError(error);
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _loadRequestId++;
    setState(() => _currentPage = 1);
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _loadData(showLoading: false);
    });
  }

  Future<void> _onFilterChanged({
    String? action,
    String? entityType,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearFromDate = false,
    bool clearToDate = false,
  }) async {
    _searchDebounce?.cancel();
    setState(() {
      if (action != null) _actionFilter = action;
      if (entityType != null) _entityTypeFilter = entityType;
      if (clearFromDate) _fromDate = null;
      if (clearToDate) _toDate = null;
      if (fromDate != null) _fromDate = fromDate;
      if (toDate != null) _toDate = toDate;
      _currentPage = 1;
    });
    await _loadData();
  }

  Future<void> _selectDate({required bool isFromDate}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final current = isFromDate ? _fromDate : _toDate;
    final initial =
        current ?? (isFromDate ? (_toDate ?? today) : (_fromDate ?? today));

    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isFromDate ? 'SELECT START DATE' : 'SELECT END DATE',
    );

    if (selected == null || !mounted) return;

    if (isFromDate) {
      await _onFilterChanged(
        fromDate: selected,
        clearToDate: _toDate != null && selected.isAfter(_toDate!),
      );
    } else {
      await _onFilterChanged(
        toDate: selected,
        clearFromDate: _fromDate != null && selected.isBefore(_fromDate!),
      );
    }
  }

  Future<void> _goToPage(int page) async {
    if (_isLoading || page < 1 || page > _totalPages || page == _currentPage) {
      return;
    }
    setState(() => _currentPage = page);
    await _loadData();
  }

  Future<void> _changePageSize(int? value) async {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _currentPage = 1;
    });
    await _loadData();
  }

  String _displayAction(dynamic value) {
    final raw = value?.toString() ?? 'Unknown action';
    return raw
        .split('_')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return 'Not recorded';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final date = parsed.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}  '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime? value) {
    if (value == null) return 'Any date';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _jsonText(dynamic value) {
    if (value == null) return 'No values recorded';
    dynamic decoded = value;
    if (value is String) {
      try {
        decoded = jsonDecode(value);
      } catch (_) {
        return value;
      }
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return decoded.toString();
    }
  }

  Color _actionColor(String action) {
    final value = action.toLowerCase();
    if (value.contains('delete') ||
        value.contains('suspend') ||
        value.contains('revoke') ||
        value.contains('deactivat') ||
        value.contains('expire')) {
      return _red;
    }
    if (value.contains('create') ||
        value.contains('renew') ||
        value.contains('activat') ||
        value.contains('register')) {
      return const Color(0xFF16834A);
    }
    return const Color(0xFF356AA0);
  }

  Widget _filterDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted),
        filled: true,
        fillColor: _card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: const TextStyle(color: Colors.white),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dateFilterButton({required bool isFromDate}) {
    final value = isFromDate ? _fromDate : _toDate;
    final label = isFromDate ? 'From date' : 'To date';
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: _card,
        foregroundColor: Colors.white,
        side: const BorderSide(color: _border),
        minimumSize: const Size(0, 52),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _isLoading ? null : () => _selectDate(isFromDate: isFromDate),
      icon: const Icon(Icons.calendar_month_outlined, size: 18),
      label: Text(
        '$label: ${_formatDateOnly(value)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final displayValue = value.isEmpty ? 'Not recorded' : value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    SelectableText(
                      displayValue,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 118,
                      child: Text(
                        label,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        displayValue,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _jsonPanel(String title, dynamic value, IconData icon) {
    final text = _jsonText(value);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _muted),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditCard(Map<String, dynamic> log) {
    final id = int.tryParse(log['id']?.toString() ?? '') ?? 0;
    final expanded = _expandedIds.contains(id);
    final action = log['action']?.toString() ?? 'unknown';
    final color = _actionColor(action);
    final adminName =
        log['platform_admin_name']?.toString() ?? 'Unknown administrator';
    final organizationName = log['organization_name']?.toString();
    final entityType = log['entity_type']?.toString();
    final entityId = log['entity_id']?.toString();

    return Card(
      color: _card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedIds.remove(id);
                } else {
                  _expandedIds.add(id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.10),
                    child: Icon(Icons.history, color: color, size: 20),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayAction(action),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          adminName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDate(log['created_at']),
                          style: const TextStyle(fontSize: 10, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _muted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailLine('Audit ID', id.toString()),
                  _detailLine('Administrator', adminName),
                  _detailLine(
                    'Admin email',
                    log['platform_admin_email']?.toString() ?? '',
                  ),
                  _detailLine(
                    'Organization',
                    organizationName == null
                        ? 'Platform-wide action'
                        : '$organizationName (${log['organization_code'] ?? '-'})',
                  ),
                  _detailLine('Entity type', entityType ?? 'Not specified'),
                  _detailLine('Entity ID', entityId ?? 'Not specified'),
                  _detailLine(
                    'IP address',
                    log['ip_address']?.toString() ?? '',
                  ),
                  _detailLine(
                    'User agent',
                    log['user_agent']?.toString() ?? '',
                  ),
                  _detailLine('Timestamp', _formatDate(log['created_at'])),
                  if ((log['description']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SelectableText(
                      log['description'].toString(),
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                  _jsonPanel(
                    'Previous values',
                    log['old_values'],
                    Icons.history,
                  ),
                  _jsonPanel(
                    'New values',
                    log['new_values'],
                    Icons.data_object,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paginationControls() {
    final start = _total == 0 ? 0 : ((_currentPage - 1) * _pageSize) + 1;
    final end = (_currentPage * _pageSize) > _total
        ? _total
        : (_currentPage * _pageSize);
    final pages = _totalPages == 0 ? 1 : _totalPages;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final rangeLabel = Text(
                'Showing $start-$end of $_total records',
                style: const TextStyle(fontSize: 12, color: _muted),
              );

              final rowsSelector = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Rows:',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _pageSize,
                      items: const [
                        DropdownMenuItem(value: 25, child: Text('25')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 100, child: Text('100')),
                      ],
                      onChanged: _isLoading ? null : _changePageSize,
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 460) {
                return Row(
                  children: [
                    Expanded(child: rangeLabel),
                    const SizedBox(width: 6),
                    rowsSelector,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: rangeLabel),
                  const SizedBox(width: 8),
                  rowsSelector,
                ],
              );
            },
          ),
          const Divider(height: 16, color: _border),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'First page',
                onPressed: !_isLoading && _currentPage > 1
                    ? () => _goToPage(1)
                    : null,
                icon: const Icon(Icons.first_page),
              ),
              IconButton(
                tooltip: 'Previous page',
                onPressed: !_isLoading && _currentPage > 1
                    ? () => _goToPage(_currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Page $_currentPage of $pages',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed: !_isLoading && _currentPage < _totalPages
                    ? () => _goToPage(_currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: 'Last page',
                onPressed: !_isLoading && _currentPage < _totalPages
                    ? () => _goToPage(_totalPages)
                    : null,
                icon: const Icon(Icons.last_page),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _auditLogs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _auditLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 46, color: _muted),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _loadData(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              _searchDebounce?.cancel();
              _loadData();
            },
            decoration: InputDecoration(
              hintText: 'Search action, administrator, organization, description or IP',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: () {
                  _searchDebounce?.cancel();
                  _loadData();
                },
                icon: const Icon(Icons.arrow_forward),
              ),
              filled: true,
              fillColor: _card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 4
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              final gap = 10.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: width,
                    child: _filterDropdown<String>(
                      label: 'Action',
                      value: _actionFilter,
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Actions'),
                        ),
                        ..._actions.map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              _displayAction(value),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value != null) {
                                _onFilterChanged(action: value);
                              }
                            },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _filterDropdown<String>(
                      label: 'Entity Type',
                      value: _entityTypeFilter,
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Entities'),
                        ),
                        ..._entityTypes.map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              _displayAction(value),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value != null) {
                                _onFilterChanged(entityType: value);
                              }
                            },
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: Row(
                      children: [
                        Expanded(child: _dateFilterButton(isFromDate: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _dateFilterButton(isFromDate: false)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (_fromDate != null || _toDate != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _onFilterChanged(
                        clearFromDate: true,
                        clearToDate: true,
                      ),
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear date filters'),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: _red, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Platform Activity',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '$_total records',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_auditLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.history, size: 42, color: _muted),
                  SizedBox(height: 10),
                  Text(
                    'No audit records found',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Try changing your search or filters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ..._auditLogs.map(_auditCard),
          if (_total > 0) ...[
            const SizedBox(height: 14),
            _paginationControls(),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
          primary: _red,
          secondary: _red,
          surface: _card,
          onSurface: Colors.white,
        ),
        textTheme: Theme.of(context).textTheme
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: _card,
          labelStyle: TextStyle(color: _muted),
          hintStyle: TextStyle(color: _muted),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _red),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: _card,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'Audit Logs',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: _dark,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : () => _loadData(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }
}
