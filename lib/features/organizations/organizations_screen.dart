import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import 'organization_edit_screen.dart';

class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _organizations = [];

  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'active';

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizations() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final organizations = await _authService.getOrganizations();

      if (!mounted) return;

      setState(() {
        _organizations = organizations;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _filteredOrganizations {
    final query = _searchController.text.trim().toLowerCase();

    final statusFiltered = _organizations.where((organization) {
      final status =
          organization['status']?.toString().toLowerCase() ?? 'unknown';

      if (_statusFilter == 'all') return true;

      if (_statusFilter == 'active') {
        return status == 'active';
      }

      // Inactive includes suspended organizations.
      return status != 'active';
    }).toList();

    if (query.isEmpty) return statusFiltered;

    return statusFiltered.where((organization) {
      return [
        organization['name'],
        organization['organization_code'],
        organization['slug'],
        organization['email'],
      ].any(
        (value) => value?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
  }

  Color _licenseColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return const Color(0xFF16834A);
      case 'expired':
      case 'suspended':
        return const Color(0xFFE50914);
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'No expiry';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _showCreateOrganizationDialog() async {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController();
    final slugController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final adminNameController = TextEditingController();
    final adminUsernameController = TextEditingController();
    final adminEmailController = TextEditingController();
    final adminPasswordController = TextEditingController();
    final confirmAdminPasswordController = TextEditingController();
    final trialDaysController = TextEditingController(text: '14');
    final maxDevicesController = TextEditingController(text: '2');
    final notesController = TextEditingController();

    String licenseType = 'trial';
    DateTime selectedExpiryDate = DateTime.now().add(const Duration(days: 14));
    bool isSaving = false;
    bool obscureAdminPassword = true;
    String? formError;

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> submit() async {
                if (isSaving) return;

                if (!formKey.currentState!.validate()) return;

                setDialogState(() {
                  isSaving = true;
                  formError = null;
                });

                try {
                  final response = await _authService.createOrganization(
                    name: nameController.text,
                    slug: slugController.text,
                    adminName: adminNameController.text,
                    adminUsername: adminUsernameController.text,
                    adminPassword: adminPasswordController.text,
                    adminEmail: adminEmailController.text,
                    email: emailController.text,
                    phone: phoneController.text,
                    address: addressController.text,
                    licenseType: licenseType,
                    trialDays: int.parse(trialDaysController.text.trim()),
                    maxDevices: int.parse(maxDevicesController.text.trim()),
                    expiresAt: licenseType == 'lifetime'
                        ? null
                        : '${selectedExpiryDate.year.toString().padLeft(4, '0')}-${selectedExpiryDate.month.toString().padLeft(2, '0')}-${selectedExpiryDate.day.toString().padLeft(2, '0')}',
                    notes: notesController.text,
                  );

                  if (!dialogContext.mounted) return;

                  Navigator.of(dialogContext).pop(response);
                } catch (e) {
                  if (!dialogContext.mounted) return;

                  setDialogState(() {
                    isSaving = false;
                    formError = e.toString().replaceFirst('Exception: ', '');
                  });
                }
              }

              return AlertDialog(
                title: const Text(
                  'Create Organization',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: SizedBox(
                  width: MediaQuery.sizeOf(dialogContext).width < 520
                      ? double.infinity
                      : 460,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _formField(
                            controller: nameController,
                            label: 'Organization Name',
                            required: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Organization name is required';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              if (slugController.text.isEmpty) {
                                slugController.text = value
                                    .toLowerCase()
                                    .trim()
                                    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                                    .replaceAll(RegExp(r'^-|-$'), '');
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          _formField(
                            controller: slugController,
                            label: 'Organization Slug',
                            required: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Slug is required';
                              }

                              if (!RegExp(r'^[a-z0-9-]+$')
                                  .hasMatch(value.trim().toLowerCase())) {
                                return 'Use lowercase letters, numbers and hyphens';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _formField(
                            controller: emailController,
                            label: 'Email (Optional)',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value != null &&
                                  value.trim().isNotEmpty &&
                                  !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(value.trim())) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _formField(
                            controller: phoneController,
                            label: 'Phone (Optional)',
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          _formField(
                            controller: addressController,
                            label: 'Address (Optional)',
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Initial Gym Admin Account',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _formField(
                            controller: adminNameController,
                            label: 'Gym Admin Name',
                            required: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Gym Admin name is required';
                              }
                              if (value.trim().length > 150) {
                                return 'Maximum 150 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _formField(
                            controller: adminUsernameController,
                            label: 'Gym Owner Username',
                            required: true,
                            keyboardType: TextInputType.text,
                            validator: (value) {
                              final username = (value?.trim() ?? '')
                                  .toLowerCase();
                              if (username.isEmpty) {
                                return 'Gym Owner username is required';
                              }
                              if (!RegExp(r'^[a-z0-9][a-z0-9._-]{2,49}$')
                                  .hasMatch(username)) {
                                return 'Use 3–50 characters: letters, numbers, dots, underscores or hyphens';
                              }
                              return null;
                            },
                          ),
                          _formField(
                            controller: adminEmailController,
                            label: 'Gym Owner Email (Optional)',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isNotEmpty &&
                                  !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(email)) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _formField(
                            controller: adminPasswordController,
                            label: 'Initial Admin Password',
                            required: true,
                            keyboardType: TextInputType.visiblePassword,
                            obscureText: obscureAdminPassword,
                            suffixIcon: IconButton(
                              tooltip: obscureAdminPassword
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                obscureAdminPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  obscureAdminPassword = !obscureAdminPassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Initial Admin password is required';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              if (value.length > 72) {
                                return 'Password must not exceed 72 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _formField(
                            controller: confirmAdminPasswordController,
                            label: 'Confirm Admin Password',
                            required: true,
                            keyboardType: TextInputType.visiblePassword,
                            obscureText: obscureAdminPassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm the Admin password';
                              }
                              if (value != adminPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'License Configuration',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                            onChanged: isSaving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setDialogState(() {
                                        licenseType = value;

                                        if (value != 'lifetime') {
                                          final days = value == 'trial'
                                              ? int.tryParse(
                                                      trialDaysController.text,
                                                    ) ??
                                                    14
                                              : value == 'monthly'
                                              ? 30
                                              : 365;

                                          selectedExpiryDate = DateTime.now()
                                              .add(Duration(days: days));
                                        }
                                      });
                                    }
                                  },
                          ),
                          const SizedBox(height: 14),

                          if (licenseType != 'lifetime') ...[
                            const Text(
                              'License Expiry Date',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                alignment: Alignment.centerLeft,
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: dialogContext,
                                        initialDate:
                                            selectedExpiryDate.isBefore(
                                              DateTime.now(),
                                            )
                                            ? DateTime.now()
                                            : selectedExpiryDate,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime(2100),
                                        helpText: 'SELECT LICENSE EXPIRY',
                                      );

                                      if (picked != null) {
                                        setDialogState(() {
                                          selectedExpiryDate = picked;
                                        });
                                      }
                                    },
                              icon: const Icon(Icons.calendar_month),
                              label: Text(
                                'Expires: ${_formatDate(selectedExpiryDate.toIso8601String())}',
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Select the date until which this license is valid.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.all_inclusive,
                                    color: Color(0xFF16834A),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Lifetime license — No expiry date',
                                    style: TextStyle(
                                      color: Color(0xFF16834A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (licenseType == 'trial') ...[
                            const SizedBox(height: 14),
                            _formField(
                              controller: trialDaysController,
                              label: 'Trial Duration (Days)',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final days = int.tryParse(value?.trim() ?? '');

                                if (days == null || days < 1 || days > 365) {
                                  return 'Enter between 1 and 365 days';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 14),
                          _formField(
                            controller: maxDevicesController,
                            label: 'Maximum Devices',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final count = int.tryParse(value?.trim() ?? '');

                              if (count == null || count < 1 || count > 1000) {
                                return 'Enter between 1 and 1000';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _formField(
                            controller: notesController,
                            label: 'License Notes (Optional)',
                            maxLines: 2,
                          ),
                          if (formError != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              formError!,
                              style: const TextStyle(
                                color: Color(0xFFE50914),
                                fontSize: 13,
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
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSaving ? null : submit,
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Organization'),
                  ),
                ],
              );
            },
          );
        },
      );

      // Wait for the dialog closing transition before disposing its controllers.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (!mounted || result == null) return;

      await _loadOrganizations();

      if (!mounted) return;

      final organization = result['organization'];
      final code = organization is Map
          ? organization['organization_code']?.toString()
          : null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            code == null
                ? 'Organization created successfully'
                : 'Organization created successfully. Code: $code',
          ),
          backgroundColor: const Color(0xFF16834A),
        ),
      );
    } finally {
      nameController.dispose();
      slugController.dispose();
      emailController.dispose();
      phoneController.dispose();
      addressController.dispose();
      adminNameController.dispose();
      adminUsernameController.dispose();
      adminEmailController.dispose();
      adminPasswordController.dispose();
      confirmAdminPasswordController.dispose();
      trialDaysController.dispose();
      maxDevicesController.dispose();
      notesController.dispose();
    }
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: obscureText,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: suffixIcon,
      ),
    );
  }

  Future<void> _openEditOrganization(Map<String, dynamic> organization) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OrganizationEditScreen(organization: organization),
      ),
    );

    if (updated == true && mounted) {
      await _loadOrganizations();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization updated successfully'),
          backgroundColor: Color(0xFF16834A),
        ),
      );
    }
  }

  Future<void> _changeOrganizationStatus(
    Map<String, dynamic> organization,
    String newStatus,
  ) async {
    final organizationName =
        organization['name']?.toString() ?? 'this organization';

    final isDeactivating = newStatus == 'inactive';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isDeactivating
              ? 'Deactivate Organization?'
              : 'Reactivate Organization?',
        ),
        content: Text(
          isDeactivating
              ? 'Are you sure you want to deactivate $organizationName? '
                    'New device activations will be blocked.'
              : 'Are you sure you want to reactivate $organizationName? '
                    'Device activation will be allowed again if its license is valid.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDeactivating
                  ? const Color(0xFFE50914)
                  : const Color(0xFF16834A),
            ),
            child: Text(isDeactivating ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final organizationId = int.tryParse(organization['id'].toString());

      if (organizationId == null || organizationId <= 0) {
        throw Exception('Invalid organization ID.');
      }

      await _authService.setOrganizationStatus(
        organizationId: organizationId,
        status: newStatus,
      );

      await _loadOrganizations();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDeactivating
                ? 'Organization deactivated successfully'
                : 'Organization reactivated successfully',
          ),
          backgroundColor: const Color(0xFF16834A),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFE50914),
        ),
      );
    }
  }

  Widget _organizationStatusMenu(Map<String, dynamic> organization) {
    final isInactive =
        organization['status']?.toString().toLowerCase() == 'inactive';

    return PopupMenuButton<String>(
      tooltip: 'Organization actions',
      onSelected: (value) {
        if (value == 'edit') {
          _openEditOrganization(organization);
        } else if (value == 'deactivate') {
          _changeOrganizationStatus(organization, 'inactive');
        } else if (value == 'reactivate') {
          _changeOrganizationStatus(organization, 'active');
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit Organization'),
          ),
        ),
        PopupMenuItem(
          value: isInactive ? 'reactivate' : 'deactivate',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isInactive ? Icons.check_circle_outline : Icons.block,
              color: isInactive
                  ? const Color(0xFF16834A)
                  : const Color(0xFFE50914),
            ),
            title: Text(isInactive ? 'Reactivate' : 'Deactivate'),
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.more_vert, color: Colors.blueGrey),
      ),
    );
  }

  Widget _buildOrganizationCard(Map<String, dynamic> organization) {
    final name = organization['name']?.toString() ?? 'Unnamed Organization';
    final code = organization['organization_code']?.toString() ?? '-';
    final licenseType = organization['license_type']?.toString() ?? 'N/A';
    final licenseStatus =
        organization['license_status']?.toString() ?? 'Unknown';
    final organizationStatus =
        organization['status']?.toString().toLowerCase() ?? 'unknown';
    final maxDevices = organization['max_devices']?.toString() ?? '-';
    final expiryDate = _formatDate(organization['expires_at']);
    final email = organization['email']?.toString() ?? '';
    final phone = organization['phone']?.toString() ?? '';

    final statusColor = _licenseColor(organizationStatus);

    return Card(
      color: const Color(0xFF202020),
      elevation: 2,
      shadowColor: Colors.black,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF383838)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                   backgroundColor: Color(0xFF35151D),
                  child: Icon(
                    Icons.business_outlined,
                     color: Color(0xFFFF1744),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        code,
                        style: const TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    organizationStatus.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _organizationStatusMenu(organization),
              ],
            ),
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _infoItem('License Type', licenseType.toUpperCase()),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoItem('License Status', licenseStatus.toUpperCase()),
                      const SizedBox(height: 11),
                      _infoItem('Maximum Devices', maxDevices),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 15,
                          color: Color(0xFFB0B0B0),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Expires: $expiryDate',
                    style: const TextStyle(
                          color: Color(0xFFB0B0B0),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 7),
              _contactLine(Icons.email_outlined, email),
            ],
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 5),
              _contactLine(Icons.phone_outlined, phone),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ],
    );
  }

  Widget _contactLine(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.blueGrey),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _organizations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _organizations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 48,
          color: Color(0xFFB0B0B0),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blueGrey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadOrganizations,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final organizations = _filteredOrganizations;

    if (organizations.isEmpty) {
      return Center(
        child: Text(
          _organizations.isEmpty
              ? 'No organizations have been created yet.'
              : 'No organizations found for this filter.',
          style: const TextStyle(color: Colors.blueGrey),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1500
            ? 4
            : constraints.maxWidth >= 1050
                ? 3
                : constraints.maxWidth >= 600
                    ? 2
                    : 1;

        return RefreshIndicator(
          onRefresh: _loadOrganizations,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 260,
            ),
            itemCount: organizations.length,
            itemBuilder: (context, index) {
              final organization = organizations[index];

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openEditOrganization(organization),
                child: _buildOrganizationCard(organization),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCount = _filteredOrganizations.length;

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        title: const Text(
          'Organizations',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadOrganizations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All Organizations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$filteredCount found',
                      style: const TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final searchField = TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search name, organization code or email',
                        hintStyle: const TextStyle(color: Color(0xFF888888)),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close),
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF202020),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFD6DEE8),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFD6DEE8),
                          ),
                        ),
                      ),
                    );

                    final statusFilter = DropdownButtonFormField<String>(
                      style: const TextStyle(color: Colors.white),
                      initialValue: _statusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFF202020),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Inactive'),
                        ),
                        DropdownMenuItem(value: 'all', child: Text('All')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _statusFilter = value;
                          });
                        }
                      },
                    );

                    if (constraints.maxWidth >= 560) {
                      return Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 14),
                          SizedBox(width: 190, child: statusFilter),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 12),
                        statusFilter,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateOrganizationDialog,
        backgroundColor: const Color(0xFFE50914),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Organization'),
      ),
    );
  }
}
