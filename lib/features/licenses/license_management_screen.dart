import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';

class LicenseManagementScreen extends StatefulWidget {
  const LicenseManagementScreen({super.key});

  @override
  State<LicenseManagementScreen> createState() =>
      _LicenseManagementScreenState();
}

class _LicenseManagementScreenState extends State<LicenseManagementScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  List<Map<String, dynamic>> _licenses = [];
  List<Map<String, dynamic>> _organizations = [];

  bool _isLoading = true;
  bool _organizationsLoaded = false;
  String? _error;
  String _statusFilter = 'active';
  String _typeFilter = 'all';
  int? _organizationFilter;

  int _currentPage = 1;
  int _pageSize = 25;
  int _total = 0;
  int _totalPages = 0;
  int _loadRequestId = 0;

  Map<String, int> _statusCounts = {
    'all': 0,
    'active': 0,
    'suspended': 0,
    'expired': 0,
  };

  static const Color _red = Color(0xFFE50914);
  static const Color _dark = Color(0xFF101010);
  static const Color _background = Color(0xFF101010);
  static const Color _card = Color(0xFF202020);
  static const Color _border = Color(0xFF383838);
  static const Color _muted = Color(0xFFB0B0B0);
  static const Color _green = Color(0xFF16834A);

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

  int _readInt(dynamic value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString() == '1' || value?.toString() == 'true';
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _loadRequestId++;
    setState(() => _currentPage = 1);
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _loadData(showLoading: false);
    });
  }

  Future<void> _submitSearch() async {
    _searchDebounce?.cancel();
    if (_currentPage != 1) setState(() => _currentPage = 1);
    await _loadData();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    final requestId = ++_loadRequestId;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      if (!_organizationsLoaded) {
        final organizations = await _authService.getOrganizations();
        if (!mounted || requestId != _loadRequestId) return;
        setState(() {
          _organizations = organizations;
          _organizationsLoaded = true;
        });
      }

      final response = await _authService.getLicenses(
        search: _searchController.text.trim(),
        status: _statusFilter,
        licenseType: _typeFilter,
        organizationId: _organizationFilter,
        page: _currentPage,
        limit: _pageSize,
      );
      if (!mounted || requestId != _loadRequestId) return;

      final pagination = Map<String, dynamic>.from(
        response['pagination'] as Map,
      );
      final rawCounts = Map<String, dynamic>.from(
        response['statusCounts'] as Map,
      );
      final rows = response['licenses'] as List;

      setState(() {
        _licenses = rows.whereType<Map<String, dynamic>>().toList();
        _currentPage = _readInt(pagination['page'], _currentPage);
        _totalPages = _readInt(pagination['totalPages']);
        _total = _readInt(pagination['total']);
        _statusCounts = {
          'all': _readInt(rawCounts['all']),
          'active': _readInt(rawCounts['active']),
          'suspended': _readInt(rawCounts['suspended']),
          'expired': _readInt(rawCounts['expired']),
        };
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _error = _cleanError(e);
      });
    }
  }

  Future<void> _onFilterChanged({
    String? status,
    String? type,
    int? organizationId,
    bool clearOrganization = false,
  }) async {
    setState(() {
      if (status != null) _statusFilter = status;
      if (type != null) _typeFilter = type;
      if (clearOrganization) {
        _organizationFilter = null;
      } else if (organizationId != null) {
        _organizationFilter = organizationId;
      }
      _currentPage = 1;
    });
    await _loadData();
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    setState(() => _currentPage = page);
    await _loadData();
  }

  Future<void> _changePageSize(int? size) async {
    if (size == null) return;
    setState(() {
      _pageSize = size;
      _currentPage = 1;
    });
    await _loadData();
  }

  String _formatDate(dynamic value, {bool includeTime = false}) {
    if (value == null || value.toString().isEmpty) return 'No expiry';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    if (!includeTime) return dateText;
    return '$dateText ${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'trial':
        return 'Trial';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      case 'lifetime':
        return 'Lifetime';
      default:
        return type ?? 'Unknown';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return _green;
      case 'suspended':
        return const Color(0xFFE58A00);
      case 'expired':
        return _red;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _summaryCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: color.withValues(alpha: 0.10),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildOrganizationFilter() {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('All Organizations'),
      ),
      ..._organizations
          .map((org) {
            final id = int.tryParse(org['id']?.toString() ?? '');
            return DropdownMenuItem<int?>(
              value: id,
              child: Text(
                org['name']?.toString() ?? 'Organization',
                overflow: TextOverflow.ellipsis,
              ),
            );
          })
          .where((item) => item.value != null),
    ];

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Organization',
        filled: true,
        fillColor: _card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _organizationFilter,
          isExpanded: true,
          items: items,
          onChanged: _isLoading
              ? null
              : (value) => _onFilterChanged(
                  organizationId: value,
                  clearOrganization: value == null,
                ),
        ),
      ),
    );
  }

  Widget _licenseCard(Map<String, dynamic> license) {
    final status =
        license['effective_status']?.toString() ??
        license['license_status']?.toString() ??
        'unknown';
    final latest = _readBool(license['is_latest']);
    final orgName =
        license['organization_name']?.toString() ?? 'Unknown organization';
    final code = license['organization_code']?.toString() ?? '-';
    final expiry = _formatDate(license['expires_at']);

    return Card(
      color: _card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 19,
                  backgroundColor: Color(0xFFFFE8E8),
                  child: Icon(Icons.card_membership, color: _red, size: 20),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orgName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'License actions',
                  onSelected: (action) {
                    if (action == 'details') _showLicenseDetails(license);
                    if (action == 'renew') _showRenewDialog(license);
                    if (action.startsWith('status:')) {
                      _changeLicenseStatus(license, action.substring(7));
                    }
                  },
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<String>>[
                      const PopupMenuItem(
                        value: 'details',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.article_outlined),
                          title: Text('Details & History'),
                        ),
                      ),
                    ];
                    if (latest) {
                      items.add(const PopupMenuDivider());
                      items.add(
                        const PopupMenuItem(
                          value: 'renew',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.autorenew),
                            title: Text('Renew License'),
                          ),
                        ),
                      );
                      if (status == 'active') {
                        items.add(
                          const PopupMenuItem(
                            value: 'status:suspended',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.pause_circle_outline,
                                color: Color(0xFFE58A00),
                              ),
                              title: Text('Suspend'),
                            ),
                          ),
                        );
                        items.add(
                          const PopupMenuItem(
                            value: 'status:expired',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.block, color: _red),
                              title: Text('Mark Expired'),
                            ),
                          ),
                        );
                      } else if (status == 'suspended') {
                        items.add(
                          const PopupMenuItem(
                            value: 'status:active',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.check_circle_outline,
                                color: _green,
                              ),
                              title: Text('Reactivate'),
                            ),
                          ),
                        );
                        items.add(
                          const PopupMenuItem(
                            value: 'status:expired',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.block, color: _red),
                              title: Text('Mark Expired'),
                            ),
                          ),
                        );
                      }
                    }
                    return items;
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _typeLabel(license['license_type']?.toString())
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _dark,
                    ),
                  ),
                ),
                _statusBadge(status),
                if (latest)
                  const Text(
                    'LATEST',
                    style: TextStyle(
                      fontSize: 9,
                      color: _green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (!latest)
                  const Text(
                    'HISTORY',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _miniInfo('License ID', '#${license['id']}')),
                Expanded(
                  child: _miniInfo(
                    'Max devices',
                    '${license['max_devices'] ?? '-'}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 15,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Expires: $expiry',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showLicenseDetails(license),
                  child: const Text('View details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Future<void> _showLicenseDetails(Map<String, dynamic> item) async {
    final id = int.tryParse(item['id']?.toString() ?? '');
    if (id == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: MediaQuery.sizeOf(dialogContext).width < 760
              ? MediaQuery.sizeOf(dialogContext).width - 80
              : 680,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _authService.getLicenseById(licenseId: id),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: _red, size: 36),
                      const SizedBox(height: 12),
                      Text(
                        _cleanError(snapshot.error!),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data!;
              final license = Map<String, dynamic>.from(data['license'] as Map);
              final history = (data['history'] as List? ?? [])
                  .whereType<Map<String, dynamic>>()
                  .toList();
              final status =
                  license['effective_status']?.toString() ??
                  license['license_status']?.toString() ??
                  'unknown';
              final isLatest =
                  history.isNotEmpty &&
                  _readInt(history.first['id']) == _readInt(license['id']);

              return Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'License Details',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Divider(),
                      Text(
                        license['organization_name']?.toString() ??
                            'Organization',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'License #${license['id']}  •  ${license['organization_code'] ?? '-'}',
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _statusBadge(status),
                          Chip(
                            label: Text(
                              _typeLabel(license['license_type']?.toString()),
                            ),
                          ),
                          if (isLatest)
                            const Chip(label: Text('Latest license')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _detailLine(
                        'Organization status',
                        license['organization_status']?.toString() ?? '-',
                      ),
                      _detailLine(
                        'Maximum devices',
                        license['max_devices']?.toString() ?? '-',
                      ),
                      _detailLine(
                        'Starts at',
                        _formatDate(license['starts_at'], includeTime: true),
                      ),
                      _detailLine(
                        'Expires at',
                        _formatDate(license['expires_at'], includeTime: true),
                      ),
                      _detailLine(
                        'Created at',
                        _formatDate(license['created_at'], includeTime: true),
                      ),
                      _detailLine(
                        'Notes',
                        license['notes']?.toString().isNotEmpty == true
                            ? license['notes'].toString()
                            : '-',
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'License History',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (history.isEmpty)
                        const Text(
                          'No history records found.',
                          style: TextStyle(color: Colors.blueGrey),
                        )
                      else
                        ...history.map((row) {
                          final rowStatus =
                              row['license_status']?.toString() ?? 'unknown';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'License #${row['id']} • ${_typeLabel(row['license_type']?.toString())}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Created ${_formatDate(row['created_at'])}  |  Expires ${_formatDate(row['expires_at'])}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.blueGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _statusBadge(rowStatus),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
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
                      width: 130,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
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

  Future<void> _showCreateDialog() async {
    if (_organizations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create an organization first.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final maxDevicesController = TextEditingController(text: '2');
    final trialDaysController = TextEditingController(text: '14');
    final notesController = TextEditingController();
    int? organizationId = int.tryParse(
      _organizations.first['id']?.toString() ?? '',
    );
    String licenseType = 'trial';
    bool saving = false;
    String? dialogError;

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (saving || !formKey.currentState!.validate()) return;
              if (organizationId == null) {
                setDialogState(() => dialogError = 'Select an organization.');
                return;
              }
              setDialogState(() {
                saving = true;
                dialogError = null;
              });
              try {
                await _authService.createLicense(
                  organizationId: organizationId!,
                  licenseType: licenseType,
                  maxDevices: int.parse(maxDevicesController.text.trim()),
                  trialDays: licenseType == 'trial'
                      ? int.parse(trialDaysController.text.trim())
                      : null,
                  notes: notesController.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              } catch (e) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  saving = false;
                  dialogError = _cleanError(e);
                });
              }
            }

            return AlertDialog(
              backgroundColor: _card,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              contentTextStyle: const TextStyle(color: _muted),
              title: const Text('Issue New License'),
              content: SizedBox(
                width: MediaQuery.sizeOf(dialogContext).width < 520
                    ? MediaQuery.sizeOf(dialogContext).width - 80
                    : 440,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: organizationId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Organization',
                            border: OutlineInputBorder(),
                          ),
                          items: _organizations
                              .map((org) {
                                final id = int.tryParse(
                                  org['id']?.toString() ?? '',
                                );
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(
                                    org['name']?.toString() ?? 'Organization',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              })
                              .where((item) => item.value != null)
                              .toList(),
                          onChanged: saving
                              ? null
                              : (value) => setDialogState(
                                  () => organizationId = value,
                                ),
                        ),
                        const SizedBox(height: 13),
                        DropdownButtonFormField<String>(
                          initialValue: licenseType,
                          decoration: const InputDecoration(
                            labelText: 'License Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'trial',
                              child: Text('Trial'),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: 'yearly',
                              child: Text('Yearly'),
                            ),
                            DropdownMenuItem(
                              value: 'lifetime',
                              child: Text('Lifetime'),
                            ),
                          ],
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() => licenseType = value);
                                  }
                                },
                        ),
                        if (licenseType == 'trial') ...[
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: trialDaysController,
                            enabled: !saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Trial Duration (Days)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final days = int.tryParse(value?.trim() ?? '');
                              return days == null || days < 1 || days > 365
                                  ? 'Enter between 1 and 365 days'
                                  : null;
                            },
                          ),
                        ],
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: maxDevicesController,
                          enabled: !saving,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Maximum Devices',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final count = int.tryParse(value?.trim() ?? '');
                            return count == null || count < 1 || count > 1000
                                ? 'Enter between 1 and 1000'
                                : null;
                          },
                        ),
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: notesController,
                          enabled: !saving,
                          maxLines: 2,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Notes (Optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (licenseType == 'lifetime')
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Lifetime license • No expiry',
                              style: TextStyle(color: _green, fontSize: 12),
                            ),
                          ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              dialogError!,
                              style: const TextStyle(color: _red, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: saving ? null : submit,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add),
                  label: Text(saving ? 'Issuing...' : 'Issue License'),
                ),
              ],
            );
          },
        ),
      );

      if (result == true && mounted) {
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('License issued successfully'),
            backgroundColor: _green,
          ),
        );
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      maxDevicesController.dispose();
      trialDaysController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _showRenewDialog(Map<String, dynamic> license) async {
    final licenseId = int.tryParse(license['id']?.toString() ?? '');
    if (licenseId == null) return;

    final formKey = GlobalKey<FormState>();
    final typeValue = license['license_type']?.toString() ?? 'yearly';
    String licenseType =
        ['trial', 'monthly', 'yearly', 'lifetime'].contains(typeValue)
        ? typeValue
        : 'yearly';
    final maxDevicesController = TextEditingController(
      text: license['max_devices']?.toString() ?? '2',
    );
    final trialDaysController = TextEditingController(text: '14');
    final notesController = TextEditingController(
      text: license['notes']?.toString() ?? '',
    );
    bool saving = false;
    String? dialogError;

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (saving || !formKey.currentState!.validate()) return;
              setDialogState(() {
                saving = true;
                dialogError = null;
              });
              try {
                await _authService.renewLicense(
                  licenseId: licenseId,
                  licenseType: licenseType,
                  maxDevices: int.parse(maxDevicesController.text.trim()),
                  trialDays: licenseType == 'trial'
                      ? int.parse(trialDaysController.text.trim())
                      : null,
                  notes: notesController.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              } catch (e) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  saving = false;
                  dialogError = _cleanError(e);
                });
              }
            }

            return AlertDialog(
              backgroundColor: _card,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              contentTextStyle: const TextStyle(color: _muted),
              title: Text('Renew License #$licenseId'),
              content: SizedBox(
                width: MediaQuery.sizeOf(dialogContext).width < 500
                    ? MediaQuery.sizeOf(dialogContext).width - 80
                    : 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: licenseType,
                          decoration: const InputDecoration(
                            labelText: 'New License Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'trial',
                              child: Text('Trial'),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: 'yearly',
                              child: Text('Yearly'),
                            ),
                            DropdownMenuItem(
                              value: 'lifetime',
                              child: Text('Lifetime'),
                            ),
                          ],
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(() => licenseType = value);
                                  }
                                },
                        ),
                        if (licenseType == 'trial') ...[
                          const SizedBox(height: 13),
                          TextFormField(
                            controller: trialDaysController,
                            enabled: !saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Trial Duration (Days)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final days = int.tryParse(value?.trim() ?? '');
                              return days == null || days < 1 || days > 365
                                  ? 'Enter between 1 and 365 days'
                                  : null;
                            },
                          ),
                        ],
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: maxDevicesController,
                          enabled: !saving,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Maximum Devices',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final count = int.tryParse(value?.trim() ?? '');
                            return count == null || count < 1 || count > 1000
                                ? 'Enter between 1 and 1000'
                                : null;
                          },
                        ),
                        const SizedBox(height: 13),
                        TextFormField(
                          controller: notesController,
                          enabled: !saving,
                          maxLines: 2,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Renewal starts immediately and extends any remaining term.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              dialogError!,
                              style: const TextStyle(color: _red, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: saving ? null : submit,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.autorenew),
                  label: Text(saving ? 'Renewing...' : 'Confirm Renewal'),
                ),
              ],
            );
          },
        ),
      );

      if (result == true && mounted) {
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('License renewed successfully'),
            backgroundColor: _green,
          ),
        );
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      maxDevicesController.dispose();
      trialDaysController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _changeLicenseStatus(
    Map<String, dynamic> license,
    String status,
  ) async {
    final id = int.tryParse(license['id']?.toString() ?? '');
    if (id == null) return;
    final name =
        license['organization_name']?.toString() ?? 'this organization';
    final actionLabel = status == 'active'
        ? 'reactivate'
        : status == 'suspended'
        ? 'suspend'
        : 'mark as expired';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '${status == 'active'
              ? 'Reactivate'
              : status == 'suspended'
              ? 'Suspend'
              : 'Expire'} License?',
        ),
        content: Text(
          'Are you sure you want to $actionLabel the latest license for $name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'active' ? _green : _red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              status == 'active'
                  ? 'Reactivate'
                  : status == 'suspended'
                  ? 'Suspend'
                  : 'Mark Expired',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _authService.updateLicenseStatus(licenseId: id, status: status);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'active'
                ? 'License reactivated'
                : status == 'suspended'
                ? 'License suspended'
                : 'License marked expired',
          ),
          backgroundColor: _green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(e)), backgroundColor: _red),
      );
    }
  }

  Widget _paginationControls() {
    final start = _total == 0 ? 0 : ((_currentPage - 1) * _pageSize) + 1;
    final end = (_currentPage * _pageSize) > _total
        ? _total
        : (_currentPage * _pageSize);
    final pages = _totalPages == 0 ? 1 : _totalPages;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final range = Text(
                'Showing $start-$end of $_total licenses',
                style: const TextStyle(fontSize: 11, color: _muted),
              );

              final pageSize = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Rows:',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                  const SizedBox(width: 6),
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

              if (constraints.maxWidth < 420) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: range),
                    const SizedBox(width: 8),
                    pageSize,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: range),
                  const SizedBox(width: 8),
                  pageSize,
                ],
              );
            },
          ),
          const Divider(height: 12, color: _border),
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 90),
          const Icon(Icons.error_outline, color: _red, size: 44),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 10.0;
              final columns = constraints.maxWidth >= 760 ? 4 : 2;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: width,
                    child: _summaryCard(
                      'Total',
                      _statusCounts['all'] ?? 0,
                      Icons.card_membership,
                      _dark,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _summaryCard(
                      'Active',
                      _statusCounts['active'] ?? 0,
                      Icons.verified_outlined,
                      _green,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _summaryCard(
                      'Suspended',
                      _statusCounts['suspended'] ?? 0,
                      Icons.pause_circle_outline,
                      const Color(0xFFE58A00),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _summaryCard(
                      'Expired',
                      _statusCounts['expired'] ?? 0,
                      Icons.event_busy_outlined,
                      _red,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 650
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (12 * (columns - 1))) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: _filterDropdown<String>(
                      label: 'License Type',
                      value: _typeFilter,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Types'),
                        ),
                        DropdownMenuItem(value: 'trial', child: Text('Trial')),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'yearly',
                          child: Text('Yearly'),
                        ),
                        DropdownMenuItem(
                          value: 'lifetime',
                          child: Text('Lifetime'),
                        ),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value != null) _onFilterChanged(type: value);
                            },
                    ),
                  ),
                  SizedBox(width: width, child: _buildOrganizationFilter()),
                  SizedBox(
                    width: width,
                    child: _filterDropdown<String>(
                      label: 'Status',
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Statuses'),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'suspended',
                          child: Text('Suspended'),
                        ),
                        DropdownMenuItem(
                          value: 'expired',
                          child: Text('Expired'),
                        ),
                      ],
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value != null) {
                                _onFilterChanged(status: value);
                              }
                            },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 650;
              final searchWidth = wide
                  ? constraints.maxWidth - 190
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: searchWidth,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) => _submitSearch(),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText:
                            'Search organization, code, notes or license ID',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          onPressed: _submitSearch,
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
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 8),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'License Records',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '$_total found',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_licenses.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.card_membership_outlined,
                    size: 42,
                    color: Colors.blueGrey,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No licenses found',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Change the filters or issue a new license.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final twoColumns = constraints.maxWidth >= 720;
                final cardWidth = twoColumns
                    ? (constraints.maxWidth - spacing) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _licenses
                      .map(
                        (license) => SizedBox(
                          width: cardWidth,
                          child: _licenseCard(license),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          if (_total > 0) ...[
            const SizedBox(height: 16),
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
            'License Management',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: _dark,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _loadData,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isLoading ? null : _showCreateDialog,
          backgroundColor: _red,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Issue License'),
        ),
      ),
    );
  }
}
