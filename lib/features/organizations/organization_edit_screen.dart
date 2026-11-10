import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';

class OrganizationEditScreen extends StatefulWidget {
  const OrganizationEditScreen({
    super.key,
    required this.organization,
  });

  final Map<String, dynamic> organization;

  @override
  State<OrganizationEditScreen> createState() =>
      _OrganizationEditScreenState();
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

  late String _licenseType;
  late DateTime _expiryDate;

  bool _isSaving = false;
  String? _error;

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

    _licenseType =
        organization['license_type']?.toString() ?? 'trial';

    final existingExpiry = DateTime.tryParse(
      organization['expires_at']?.toString() ?? '',
    );

    final today = DateUtils.dateOnly(DateTime.now());

    // An expired license needs a new future expiry date when edited.
    _expiryDate = existingExpiry != null &&
            DateUtils.dateOnly(existingExpiry).isAfter(today)
        ? DateUtils.dateOnly(existingExpiry)
        : today.add(const Duration(days: 30));
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
      final organizationId = int.tryParse(
        widget.organization['id'].toString(),
      );

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
        DateTime.tryParse(
              organization['expires_at'].toString(),
            )?.isBefore(DateTime.now()) == true;

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
                  side: const BorderSide(
                    color: Color(0xFFE2E7EF),
                  ),
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
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(
                    color: Color(0xFFE2E7EF),
                  ),
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
                                      final today =
                                          DateUtils.dateOnly(
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
                          onPressed:
                              _isSaving ? null : _selectExpiryDate,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            'Expiry date: ${_dateText(_expiryDate)}',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                              double.infinity,
                              48,
                            ),
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
                          final count = int.tryParse(
                            value?.trim() ?? '',
                          );

                          if (count == null ||
                              count < 1 ||
                              count > 1000) {
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
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save Changes',
                  ),
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
