import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';

class OrganizationEditScreen extends StatefulWidget {
  const OrganizationEditScreen({super.key, required this.organization});

  final Map<String, dynamic> organization;

  @override
  State<OrganizationEditScreen> createState() => _OrganizationEditScreenState();
}

class _OrganizationEditScreenState extends State<OrganizationEditScreen> {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _maxDevicesController;
  late final TextEditingController _notesController;
  late final TextEditingController _gymOwnerNameController;
  late final TextEditingController _gymOwnerUsernameController;
  late final TextEditingController _gymOwnerEmailController;

  late String _licenseType;
  late DateTime _expiryDate;

  bool _isSaving = false;
  String? _error;

  bool _isLoadingGymOwner = true;
  String? _gymOwnerError;
  Map<String, dynamic>? _gymOwner;

  @override
  void initState() {
    super.initState();

    final organization = widget.organization;

    _nameController = TextEditingController(
      text: organization['name']?.toString() ?? '',
    );

    _slugController = TextEditingController(
      text: organization['slug']?.toString() ?? '',
    );

    _emailController = TextEditingController(
      text: organization['email']?.toString() ?? '',
    );

    _phoneController = TextEditingController(
      text: organization['phone']?.toString() ?? '',
    );

    _addressController = TextEditingController(
      text: organization['address']?.toString() ?? '',
    );

    _maxDevicesController = TextEditingController(
      text: organization['max_devices']?.toString() ?? '2',
    );

    _notesController = TextEditingController(
      text: organization['license_notes']?.toString() ?? '',
    );
    _gymOwnerNameController = TextEditingController();
    _gymOwnerUsernameController = TextEditingController();
    _gymOwnerEmailController = TextEditingController();

    _licenseType = organization['license_type']?.toString() ?? 'trial';

    final existingExpiry = DateTime.tryParse(
      organization['expires_at']?.toString() ?? '',
    );

    final today = DateUtils.dateOnly(DateTime.now());

    // An expired license needs a new future expiry date when edited.
    _expiryDate =
        existingExpiry != null &&
            DateUtils.dateOnly(existingExpiry).isAfter(today)
        ? DateUtils.dateOnly(existingExpiry)
        : today.add(const Duration(days: 30));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadGymOwner();
    });
  }

  Future<void> _loadGymOwner() async {
    final organizationId = int.tryParse(
      widget.organization['id']?.toString() ?? '',
    );
    if (organizationId == null || organizationId <= 0) {
      if (!mounted) return;
      setState(() {
        _isLoadingGymOwner = false;
        _gymOwnerError = 'Invalid organization ID.';
      });
      return;
    }

    setState(() {
      _isLoadingGymOwner = true;
      _gymOwnerError = null;
    });

    try {
      final owner = await _authService.getOrganizationGymOwner(
        organizationId: organizationId,
      );
      if (!mounted) return;
      setState(() {
        _gymOwner = owner;
        _gymOwnerNameController.text = owner?['full_name']?.toString() ?? '';
        _gymOwnerUsernameController.text = owner?['username']?.toString() ?? '';
        _gymOwnerEmailController.text = owner?['email']?.toString() ?? '';
        _isLoadingGymOwner = false;
        _gymOwnerError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingGymOwner = false;
        _gymOwnerError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _maxDevicesController.dispose();
    _notesController.dispose();
    _gymOwnerNameController.dispose();
    _gymOwnerUsernameController.dispose();
    _gymOwnerEmailController.dispose();
    super.dispose();
  }

  String _dateText(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _selectExpiryDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate.isBefore(today) ? today : _expiryDate,
      firstDate: today,
      lastDate: DateTime(2100),
      helpText: 'SELECT LICENSE EXPIRY',
    );

    if (picked != null && mounted) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final organizationId = int.tryParse(widget.organization['id'].toString());

      if (organizationId == null || organizationId <= 0) {
        throw Exception('Invalid organization ID.');
      }

      final expiryDate = _licenseType == 'lifetime'
          ? null
          : '${_expiryDate.year.toString().padLeft(4, '0')}-'
                '${_expiryDate.month.toString().padLeft(2, '0')}-'
                '${_expiryDate.day.toString().padLeft(2, '0')}';

      await _authService.updateOrganization(
        organizationId: organizationId,
        name: _nameController.text,
        slug: _slugController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        licenseType: _licenseType,
        maxDevices: int.parse(_maxDevicesController.text.trim()),
        expiresAt: expiryDate,
        notes: _notesController.text,
        gymOwnerName: _gymOwner == null ? null : _gymOwnerNameController.text,
        gymOwnerUsername: _gymOwner == null
            ? null
            : _gymOwnerUsernameController.text,
        gymOwnerEmail: _gymOwner == null ? null : _gymOwnerEmailController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  Widget _buildGymOwnerAccountCard() {
    final owner = _gymOwner;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E7EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.manage_accounts_outlined,
                  color: Color(0xFFE50914),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Gym Owner Account',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh Gym Owner account',
                  onPressed: _isLoadingGymOwner ? null : _loadGymOwner,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoadingGymOwner)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_gymOwnerError != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _gymOwnerError!,
                    style: const TextStyle(color: Color(0xFFE50914)),
                  ),
                  TextButton.icon(
                    onPressed: _loadGymOwner,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              )
            else if (owner == null)
              const Text(
                'No Gym Owner account was found for this organization.',
                style: TextStyle(color: Colors.blueGrey),
              )
            else ...[
              _field(
                controller: _gymOwnerNameController,
                label: 'Gym Owner Name',
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Gym Owner name is required';
                  if (name.length > 150) return 'Maximum 150 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _field(
                controller: _gymOwnerUsernameController,
                label: 'Login Username',
                keyboardType: TextInputType.text,
                validator: (value) {
                  final username = (value?.trim() ?? '').toLowerCase();

                  if (username.isEmpty) {
                    return 'Login username is required';
                  }

                  if (!RegExp(r'^[a-z0-9][a-z0-9._-]{2,49}$')
                      .hasMatch(username)) {
                    return 'Use 3–50 characters: letters, numbers, dots, underscores or hyphens';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 14),
              _field(
                controller: _gymOwnerEmailController,
                label: 'Gym Owner Email (Optional)',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';

                  if (email.isNotEmpty &&
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Enter a valid email address';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _showResetGymOwnerPasswordDialog,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Reset Password'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE50914),
                    side: const BorderSide(color: Color(0xFFE50914)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showResetGymOwnerPasswordDialog() async {
    final organizationId = int.tryParse(
      widget.organization['id']?.toString() ?? '',
    );
    if (organizationId == null || organizationId <= 0 || _gymOwner == null) {
      return;
    }

    final didReset = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GymOwnerPasswordResetDialog(
        onSubmit: (newPassword) =>
            _authService.resetOrganizationGymOwnerPassword(
              organizationId: organizationId,
              newPassword: newPassword,
            ),
      ),
    );

    if (didReset == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gym Owner password reset successfully'),
          backgroundColor: Color(0xFF16834A),
        ),
      );
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final organization = widget.organization;

    final organizationCode =
        organization['organization_code']?.toString() ?? '-';

    final isCurrentlyExpired =
        organization['expires_at'] != null &&
        DateTime.tryParse(organization['expires_at'].toString())
                ?.isBefore(DateTime.now()) ==
            true;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Organization',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E7EF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Organization Information',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Organization Code: $organizationCode',
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _field(
                        controller: _nameController,
                        label: 'Organization Name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Organization name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _field(
                        controller: _slugController,
                        label: 'Organization Slug',
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
                      const SizedBox(height: 16),
                      _field(
                        controller: _emailController,
                        label: 'Email',
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
                      const SizedBox(height: 16),
                      _field(
                        controller: _phoneController,
                        label: 'Phone',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _field(
                        controller: _addressController,
                        label: 'Address',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildGymOwnerAccountCard(),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E7EF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'License Configuration',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _licenseType,
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
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() {
                                    _licenseType = value;

                                    if (value != 'lifetime') {
                                      final today = DateUtils.dateOnly(
                                        DateTime.now(),
                                      );

                                      if (!_expiryDate.isAfter(today)) {
                                        _expiryDate = today.add(
                                          const Duration(days: 30),
                                        );
                                      }
                                    }
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 16),
                      if (_licenseType == 'lifetime')
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.all_inclusive,
                            color: Color(0xFF16834A),
                          ),
                          title: Text('Lifetime license'),
                          subtitle: Text('No expiry date'),
                        )
                      else ...[
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _selectExpiryDate,
                          icon: const Icon(Icons.calendar_month),
                          label: Text('Expiry date: ${_dateText(_expiryDate)}'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                        if (isCurrentlyExpired) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'The previous license has expired. '
                            'A new future expiry date is selected. '
                            'Saving will update the license expiry.',
                            style: TextStyle(
                              color: Color(0xFFE58A00),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      _field(
                        controller: _maxDevicesController,
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
                      const SizedBox(height: 16),
                      _field(
                        controller: _notesController,
                        label: 'License Notes',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFE50914),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveChanges,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GymOwnerPasswordResetDialog extends StatefulWidget {
  const _GymOwnerPasswordResetDialog({required this.onSubmit});

  final Future<void> Function(String newPassword) onSubmit;

  @override
  State<_GymOwnerPasswordResetDialog> createState() =>
      _GymOwnerPasswordResetDialogState();
}

class _GymOwnerPasswordResetDialogState
    extends State<_GymOwnerPasswordResetDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isSaving = false;
  bool _obscurePassword = true;
  String? _passwordError;
  String? _confirmError;
  String? _submitError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final password = _passwordController.text;
    final confirmation = _confirmController.text;
    final passwordError = password.isEmpty
        ? 'New password is required'
        : password.length < 8
        ? 'Password must be at least 8 characters'
        : password.length > 72
        ? 'Password must not exceed 72 characters'
        : null;
    final confirmError = confirmation.isEmpty
        ? 'Please confirm the new password'
        : confirmation != password
        ? 'Passwords do not match'
        : null;

    setState(() {
      _passwordError = passwordError;
      _confirmError = confirmError;
      _submitError = null;
    });

    if (passwordError != null || confirmError != null) return;

    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(password);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _submitError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Gym Owner Password'),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width < 480
            ? double.infinity
            : 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              keyboardType: TextInputType.visiblePassword,
              enabled: !_isSaving,
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'New Password',
                border: const OutlineInputBorder(),
                errorText: _passwordError,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: _isSaving
                      ? null
                      : () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmController,
              obscureText: _obscurePassword,
              keyboardType: TextInputType.visiblePassword,
              enabled: !_isSaving,
              onChanged: (_) {
                if (_confirmError != null) {
                  setState(() => _confirmError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: const OutlineInputBorder(),
                errorText: _confirmError,
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _submitError!,
                  style: const TextStyle(color: Color(0xFFE50914)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Reset Password'),
        ),
      ],
    );
  }
}
