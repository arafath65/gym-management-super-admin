import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/auth_service.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  final Set<String> _expandedDeviceIds = <String>{};

  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _organizations = [];
  List<Map<String, dynamic>> _branches = [];

  bool _isLoading = true;
  bool _isLoadingBranches = false;
  bool _organizationsLoaded = false;

  String? _error;
  String? _branchError;

  String _statusFilter = 'all';

  int? _selectedOrganizationId;
  int? _selectedBranchId;

  int _currentPage = 1;
  int _pageSize = 25;
  int _totalDevices = 0;
  int _totalPages = 0;

  int _loadRequestId = 0;
  int _branchRequestId = 0;

  Map<String, int> _statusCounts = {
    'all': 0,
    'pending': 0,
    'active': 0,
    'revoked': 0,
  };

  static const Color _red = Color(0xFFE50914);
  static const Color _dark = Color(0xFF111111);
  static const Color _background = Color(0xFFD9DEE7);

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

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    // Ignore any older request while the user is typing.
    _loadRequestId++;

    setState(() {
      _currentPage = 1;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _loadData(showLoading: false);
    });
  }

  Future<void> _submitSearch() async {
    _searchDebounce?.cancel();

    if (_currentPage != 1) {
      setState(() {
        _currentPage = 1;
      });
    }

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

      final response = await _authService.getDevices(
        status: _statusFilter,
        organizationId: _selectedOrganizationId,
        branchId: _selectedBranchId,
        search: _searchController.text.trim(),
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

      int readCount(String key) {
        final value = rawCounts[key];

        if (value is num) return value.toInt();

        return int.tryParse(value?.toString() ?? '') ?? 0;
      }

      final rawDevices = response['devices'] as List;

      setState(() {
        _devices = rawDevices.whereType<Map<String, dynamic>>().toList();

        _currentPage = pagination['page'] is num
            ? (pagination['page'] as num).toInt()
            : _currentPage;

        _totalPages = pagination['totalPages'] is num
            ? (pagination['totalPages'] as num).toInt()
            : 0;

        _totalDevices = pagination['total'] is num
            ? (pagination['total'] as num).toInt()
            : 0;

        _statusCounts = {
          'all': readCount('all'),
          'pending': readCount('pending'),
          'active': readCount('active'),
          'revoked': readCount('revoked'),
        };

        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadBranches(int organizationId) async {
    final requestId = ++_branchRequestId;

    setState(() {
      _isLoadingBranches = true;
      _branchError = null;
      _branches = [];
    });

    try {
      final branches = await _authService.getBranches(
        organizationId: organizationId,
        activeOnly: false,
      );

      if (!mounted || requestId != _branchRequestId) return;

      setState(() {
        _branches = branches;
        _isLoadingBranches = false;
      });
    } catch (e) {
      if (!mounted || requestId != _branchRequestId) return;

      setState(() {
        _branches = [];
        _isLoadingBranches = false;
        _branchError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _onOrganizationChanged(int? organizationId) async {
    setState(() {
      _selectedOrganizationId = organizationId;
      _selectedBranchId = null;
      _currentPage = 1;
      _branches = [];
      _branchError = null;
    });

    if (organizationId != null) {
      await _loadBranches(organizationId);
    } else {
      _branchRequestId++;
      setState(() {
        _isLoadingBranches = false;
      });
    }

    await _loadData();
  }

  Future<void> _onBranchChanged(int? branchId) async {
    setState(() {
      _selectedBranchId = branchId;
      _currentPage = 1;
    });

    await _loadData();
  }

  Future<void> _onStatusChanged(String? status) async {
    if (status == null) return;

    setState(() {
      _statusFilter = status;
      _currentPage = 1;
    });

    await _loadData();
  }

  Future<void> _onPageSizeChanged(int? value) async {
    if (value == null) return;

    setState(() {
      _pageSize = value;
      _currentPage = 1;
    });

    await _loadData();
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages || page == _currentPage) {
      return;
    }

    setState(() {
      _currentPage = page;
    });

    await _loadData();
  }

  List<Map<String, dynamic>> get _filteredDevices => _devices;

  int _countStatus(String status) {
    return _statusCounts[status] ?? 0;
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Never';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _typeLabel(dynamic value) {
    switch (value?.toString()) {
      case 'android_tablet':
        return 'Android Tablet';
      case 'android_mobile':
        return 'Android Mobile';
      default:
        return 'Other Device';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFF16834A);
      case 'pending':
        return const Color(0xFFE58A00);
      case 'revoked':
        return const Color(0xFFC62828);
      default:
        return Colors.blueGrey;
    }
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _showActivationCode(
    String code, {
    String title = 'Device Activation Code',
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share this code with the device user. '
                'It will not be displayed again.',
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E4EA)),
                ),
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: _dark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Valid for 24 hours.',
                style: TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Activation code copied')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Code'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRegisterDialog() async {
    if (_organizations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create an organization first.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final uuidController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final firstOrganizationId = int.tryParse(
      _organizations.first['id'].toString(),
    );

    if (firstOrganizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to read organization information.'),
        ),
      );
      return;
    }

    int selectedOrganizationId = firstOrganizationId;
    int? selectedBranchId;
    String selectedDeviceType = 'android_tablet';

    List<Map<String, dynamic>> branches = [];
    bool branchesLoading = true;
    bool saving = false;
    String? dialogError;

    try {
      branches = await _authService.getBranches(
        organizationId: selectedOrganizationId,
      );
    } catch (_) {
      branches = [];
    }

    branchesLoading = false;

    if (!mounted) {
      nameController.dispose();
      uuidController.dispose();
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            return AlertDialog(
              title: const Text('Register Device'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: selectedOrganizationId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Organization',
                            border: OutlineInputBorder(),
                          ),
                          items: _organizations
                              .map((organization) {
                                final id = int.tryParse(
                                  organization['id'].toString(),
                                );

                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(
                                    organization['name']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              })
                              .where((item) => item.value != null)
                              .toList(),
                          onChanged: saving
                              ? null
                              : (value) async {
                                  if (value == null) return;

                                  dialogSetState(() {
                                    selectedOrganizationId = value;
                                    selectedBranchId = null;
                                    branches = [];
                                    branchesLoading = true;
                                    dialogError = null;
                                  });

                                  try {
                                    final loadedBranches = await _authService
                                        .getBranches(organizationId: value);

                                    if (!dialogContext.mounted) return;

                                    dialogSetState(() {
                                      branches = loadedBranches;
                                      branchesLoading = false;
                                    });
                                  } catch (e) {
                                    if (!dialogContext.mounted) return;

                                    dialogSetState(() {
                                      branches = [];
                                      branchesLoading = false;
                                      dialogError = e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      );
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int?>(
                          initialValue: selectedBranchId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Branch (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('No branch assigned'),
                            ),
                            ...branches.map((branch) {
                              return DropdownMenuItem<int?>(
                                value: int.tryParse(branch['id'].toString()),
                                child: Text(
                                  branch['name']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: saving || branchesLoading
                              ? null
                              : (value) {
                                  dialogSetState(() {
                                    selectedBranchId = value;
                                  });
                                },
                        ),
                        if (branchesLoading) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(),
                        ],
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: nameController,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Device Name',
                            hintText: 'Front Desk Tablet',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Device name is required';
                            }
                            if (value.trim().length > 150) {
                              return 'Maximum 150 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: uuidController,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Device UUID',
                            hintText: 'Enter the device unique ID',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Device UUID is required';
                            }
                            if (value.trim().length > 150) {
                              return 'Maximum 150 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedDeviceType,
                          decoration: const InputDecoration(
                            labelText: 'Device Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'android_tablet',
                              child: Text('Android Tablet'),
                            ),
                            DropdownMenuItem(
                              value: 'android_mobile',
                              child: Text('Android Mobile'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  dialogSetState(() {
                                    selectedDeviceType = value;
                                  });
                                },
                        ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            dialogError!,
                            style: const TextStyle(color: _red, fontSize: 12),
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
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: saving || branchesLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          dialogSetState(() {
                            saving = true;
                            dialogError = null;
                          });

                          try {
                            final response = await _authService.registerDevice(
                              organizationId: selectedOrganizationId,
                              branchId: selectedBranchId,
                              deviceUuid: uuidController.text,
                              deviceName: nameController.text,
                              deviceType: selectedDeviceType,
                            );

                            if (!dialogContext.mounted) return;

                            Navigator.of(dialogContext).pop(response);
                          } catch (e) {
                            if (!dialogContext.mounted) return;

                            dialogSetState(() {
                              saving = false;
                              dialogError = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                            });
                          }
                        },
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
                  label: Text(saving ? 'Registering...' : 'Register'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    uuidController.dispose();

    if (!mounted || result == null) return;

    await _loadData(showLoading: false);

    final activationCode = result['activation_code']?.toString();

    if (activationCode != null && activationCode.isNotEmpty) {
      await _showActivationCode(activationCode, title: 'Device Registered');
    }
  }

  Future<void> _handleDeviceAction(
    Map<String, dynamic> device,
    String action,
  ) async {
    final deviceId = int.tryParse(device['id'].toString());

    if (deviceId == null) return;

    if (action == 'revoke') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Revoke Device?'),
            content: Text(
              'Revoke "${device['device_name']}"?\n\n'
              'This will invalidate its current device token.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Revoke Device'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      try {
        await _authService.revokeDevice(deviceId: deviceId);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device revoked successfully')),
        );

        await _loadData(showLoading: false);
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }

      return;
    }

    try {
      final response = await _authService.regenerateDeviceActivationCode(
        deviceId: deviceId,
      );

      if (!mounted) return;

      await _loadData(showLoading: false);

      final code = response['activation_code']?.toString();

      if (code != null && code.isNotEmpty) {
        await _showActivationCode(
          code,
          title: action == 'reactivate'
              ? 'Device Reactivated'
              : 'New Activation Code',
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _summaryCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E7EF)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.10),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceCard(Map<String, dynamic> device) {
    final status = device['status']?.toString() ?? 'unknown';
    final organizationName =
        device['organization_name']?.toString() ?? 'Unknown organization';
    final branchName = device['branch_name']?.toString();

    final deviceKey =
        device['id']?.toString() ?? device['device_uuid']?.toString() ?? '';

    final isExpanded = _expandedDeviceIds.contains(deviceKey);

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E7EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (deviceKey.isEmpty) return;

                      setState(() {
                        if (isExpanded) {
                          _expandedDeviceIds.remove(deviceKey);
                        } else {
                          _expandedDeviceIds.add(deviceKey);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFFFE8E8),
                            child: Icon(
                              device['device_type'] == 'android_tablet'
                                  ? Icons.tablet_android
                                  : Icons.devices,
                              color: _red,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device['device_name']?.toString() ??
                                      'Unnamed Device',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _typeLabel(device['device_type']),
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _statusBadge(status),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.blueGrey,
                            size: 21,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _deviceActionsMenu(device, status),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _detailRow(
                Icons.business_outlined,
                'Organization',
                organizationName,
              ),
              const SizedBox(height: 7),
              _detailRow(
                Icons.location_on_outlined,
                'Branch',
                branchName == null || branchName.isEmpty
                    ? 'No branch assigned'
                    : branchName,
              ),
              const SizedBox(height: 7),
              _detailRow(
                Icons.fingerprint,
                'Device UUID',
                device['device_uuid']?.toString() ?? '-',
              ),
              const SizedBox(height: 7),
              _detailRow(
                Icons.access_time,
                'Last seen',
                _formatDate(device['last_seen_at']),
              ),
              const SizedBox(height: 7),
              _detailRow(
                Icons.timer_outlined,
                'Activation expires',
                _formatDate(device['activation_expires_at']),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _deviceActionsMenu(Map<String, dynamic> device, String status) {
    return PopupMenuButton<String>(
      tooltip: 'Device actions',
      onSelected: (value) => _handleDeviceAction(device, value),
      itemBuilder: (context) {
        if (status == 'active') {
          return const [
            PopupMenuItem(
              value: 'revoke',
              child: Row(
                children: [
                  Icon(Icons.block, color: _red, size: 19),
                  SizedBox(width: 10),
                  Text('Revoke Device'),
                ],
              ),
            ),
          ];
        }

        if (status == 'revoked') {
          return const [
            PopupMenuItem(
              value: 'reactivate',
              child: Row(
                children: [
                  Icon(Icons.refresh, color: Color(0xFF16834A), size: 19),
                  SizedBox(width: 10),
                  Text('Reactivate Device'),
                ],
              ),
            ),
          ];
        }

        return const [
          PopupMenuItem(
            value: 'regenerate',
            child: Row(
              children: [
                Icon(Icons.key, size: 19),
                SizedBox(width: 10),
                Text('Regenerate Code'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'revoke',
            child: Row(
              children: [
                Icon(Icons.block, color: _red, size: 19),
                SizedBox(width: 10),
                Text('Cancel Registration'),
              ],
            ),
          ),
        ];
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 8),
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Status',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5DBE4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5DBE4)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Statuses')),
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'pending', child: Text('Pending')),
            DropdownMenuItem(value: 'revoked', child: Text('Revoked')),
          ],
          onChanged: _isLoading ? null : _onStatusChanged,
        ),
      ),
    );
  }

  Widget _buildOrganizationDropdown() {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('All Organizations'),
      ),
      ..._organizations
          .map((organization) {
            final id = int.tryParse(organization['id'].toString());

            return DropdownMenuItem<int?>(
              value: id,
              child: Text(
                organization['name']?.toString() ?? 'Unnamed Organization',
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
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5DBE4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5DBE4)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _selectedOrganizationId,
          isExpanded: true,
          items: items,
          onChanged: _isLoading ? null : _onOrganizationChanged,
        ),
      ),
    );
  }

  Widget _buildBranchDropdown() {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('All Branches')),
      ..._branches
          .map((branch) {
            final id = int.tryParse(branch['id'].toString());

            final branchName = branch['name']?.toString() ?? 'Unnamed Branch';
            final branchStatus = branch['status']?.toString() ?? 'active';

            return DropdownMenuItem<int?>(
              value: id,
              child: Text(
                branchStatus == 'inactive'
                    ? '$branchName (Inactive)'
                    : branchName,
                overflow: TextOverflow.ellipsis,
              ),
            );
          })
          .where((item) => item.value != null),
    ];

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Branch',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5DBE4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5DBE4)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _selectedBranchId,
          isExpanded: true,
          items: items,
          hint: const Text('All Branches'),
          onChanged:
              _selectedOrganizationId == null ||
                  _isLoading ||
                  _isLoadingBranches
              ? null
              : _onBranchChanged,
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final start = _totalDevices == 0 ? 0 : ((_currentPage - 1) * _pageSize) + 1;

    final calculatedEnd = _currentPage * _pageSize;
    final end = calculatedEnd > _totalDevices ? _totalDevices : calculatedEnd;

    final displayedPageCount = _totalPages == 0 ? 1 : _totalPages;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E7EF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Showing $startâ€“$end of $_totalDevices devices',
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Text(
                'Rows:',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
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
                  onChanged: _isLoading ? null : _onPageSizeChanged,
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
                  'Page $_currentPage of $displayedPageCount',
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDevices;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Device Management',
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _red,
        foregroundColor: Colors.white,
        onPressed: _isLoading ? null : _showRegisterDialog,
        icon: const Icon(Icons.add),
        label: const Text('Register Device'),
      ),
      body: Container(
        color: _background,
        child: RefreshIndicator(
          onRefresh: () => _loadData(showLoading: false),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 100),
                    const Icon(Icons.error_outline, size: 44, color: _red),
                    const SizedBox(height: 12),
                    Center(child: Text(_error!, textAlign: TextAlign.center)),
                    const SizedBox(height: 12),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _loadData(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 20) / 3;

                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: width,
                              child: _summaryCard(
                                title: 'Total',
                                value: _countStatus('all'),
                                icon: Icons.devices,
                                color: _dark,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _summaryCard(
                                title: 'Active',
                                value: _countStatus('active'),
                                icon: Icons.check_circle_outline,
                                color: const Color(0xFF16834A),
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _summaryCard(
                                title: 'Pending',
                                value: _countStatus('pending'),
                                icon: Icons.pending_actions,
                                color: const Color(0xFFE58A00),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 600;
                        final searchWidth = wide
                            ? constraints.maxWidth - 190
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: searchWidth,
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _submitSearch(),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search device, UUID or organization',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: IconButton(
                                    tooltip: 'Search',
                                    onPressed: _submitSearch,
                                    icon: const Icon(Icons.arrow_forward),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: wide ? 178 : constraints.maxWidth,
                              child: _buildStatusDropdown(),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth >= 600
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: width,
                              child: _buildOrganizationDropdown(),
                            ),
                            SizedBox(
                              width: width,
                              child: _buildBranchDropdown(),
                            ),
                          ],
                        );
                      },
                    ),
                    if (_branchError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _branchError!,
                        style: const TextStyle(color: _red, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Registered Devices',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${filtered.length} devices',
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.devices_other,
                              size: 42,
                              color: Colors.blueGrey,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No devices found',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Register a device or change your filters.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 12,
                              ),
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
                            children: filtered.map((device) {
                              final key =
                                  device['id']?.toString() ??
                                  device['device_uuid']?.toString() ??
                                  '';

                              return SizedBox(
                                key: ValueKey(key),
                                width: cardWidth,
                                child: _deviceCard(device),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    if (_totalDevices > 0) ...[
                      const SizedBox(height: 4),
                      _buildPaginationControls(),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
