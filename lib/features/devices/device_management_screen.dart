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

  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _organizations = [];

  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'all';

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _authService.getDevices(search: _searchController.text.trim()),
        _authService.getOrganizations(),
      ]);

      if (!mounted) return;

      setState(() {
        _devices = results[0];
        _organizations = results[1];
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _filteredDevices {
    if (_statusFilter == 'all') return _devices;

    return _devices
        .where((device) => device['status'] == _statusFilter)
        .toList();
  }

  int _countStatus(String status) {
    return _devices.where((device) => device['status'] == status).length;
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Never';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'â€”';

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

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E7EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFFE8E8),
                  child: Icon(
                    device['device_type'] == 'android_tablet'
                        ? Icons.tablet_android
                        : Icons.devices,
                    color: _red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device['device_name']?.toString() ?? 'Unnamed Device',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _typeLabel(device['device_type']),
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(status),
                PopupMenuButton<String>(
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
                              Icon(
                                Icons.refresh,
                                color: Color(0xFF16834A),
                                size: 19,
                              ),
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
                ),
              ],
            ),
            const SizedBox(height: 14),
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
              device['device_uuid']?.toString() ?? 'â€”',
            ),
            const SizedBox(height: 7),
            _detailRow(
              Icons.schedule,
              'Last seen',
              _formatDate(device['last_seen_at']),
            ),
            if (status == 'pending') ...[
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

  Widget _filterChip(String label, String value, int count) {
    final selected = _statusFilter == value;

    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      selectedColor: const Color(0xFFFFE8E8),
      labelStyle: TextStyle(
        color: selected ? _red : _dark,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(color: selected ? _red : const Color(0xFFD5DBE4)),
      onSelected: (_) {
        setState(() {
          _statusFilter = value;
        });
      },
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
                                value: _devices.length,
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
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _loadData(),
                      decoration: InputDecoration(
                        hintText: 'Search device, UUID or organization',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Search',
                          onPressed: () => _loadData(),
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
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 7,
                      runSpacing: 4,
                      children: [
                        _filterChip('All', 'all', _devices.length),
                        _filterChip(
                          'Pending',
                          'pending',
                          _countStatus('pending'),
                        ),
                        _filterChip('Active', 'active', _countStatus('active')),
                        _filterChip(
                          'Revoked',
                          'revoked',
                          _countStatus('revoked'),
                        ),
                      ],
                    ),
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
                      ...filtered.map(
                        (device) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _deviceCard(device),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
