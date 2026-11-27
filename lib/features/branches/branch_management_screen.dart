import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  static const Color _red = Color(0xFFE50914);
  static const Color _dark = Color(0xFF111111);
  static const Color _background = Color(0xFFD9DEE7);

  List<Map<String, dynamic>> _organizations = [];
  List<Map<String, dynamic>> _branches = [];

  int? _selectedOrganizationId;
  String _statusFilter = 'active';
  String _search = '';

  bool _isLoadingOrganizations = true;
  bool _isLoadingBranches = false;

  String? _error;
  String? _organizationError;

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

  int? _readId(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _loadOrganizations() async {
    setState(() {
      _isLoadingOrganizations = true;
      _organizationError = null;
    });

    try {
      final organizations = await _authService.getOrganizations();

      if (!mounted) return;

      setState(() {
        _organizations = organizations;
        _isLoadingOrganizations = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingOrganizations = false;
        _organizationError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadBranches() async {
    final organizationId = _selectedOrganizationId;

    if (organizationId == null) {
      setState(() {
        _branches = [];
        _isLoadingBranches = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoadingBranches = true;
      _error = null;
    });

    try {
      final branches = await _authService.getBranches(
        organizationId: organizationId,
        activeOnly: false,
      );

      if (!mounted) return;

      setState(() {
        _branches = branches;
        _isLoadingBranches = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingBranches = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _onOrganizationChanged(int? value) async {
    setState(() {
      _selectedOrganizationId = value;
      _branches = [];
      _search = '';
      _searchController.clear();
      _statusFilter = 'active';
    });

    await _loadBranches();
  }

  List<Map<String, dynamic>> get _filteredBranches {
    final query = _search.trim().toLowerCase();

    return _branches.where((branch) {
      final status = branch['status']?.toString().toLowerCase() ?? '';

      if (_statusFilter != 'all' && status != _statusFilter) {
        return false;
      }

      if (query.isEmpty) return true;

      return [
        branch['name'],
        branch['branch_code'],
        branch['phone'],
        branch['address'],
      ].any(
        (value) => value?.toString().toLowerCase().contains(query) ?? false,
      );
    }).toList();
  }

  int _countStatus(String status) {
    if (status == 'all') return _branches.length;

    return _branches
        .where((branch) => branch['status']?.toString().toLowerCase() == status)
        .length;
  }

  Future<void> _showBranchDialog({Map<String, dynamic>? branch}) async {
    final organizationId = _selectedOrganizationId;

    if (organizationId == null) return;

    if (branch != null &&
        branch['status']?.toString().toLowerCase() != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reactivate this branch before editing it.'),
          backgroundColor: _red,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: branch?['name']?.toString() ?? '',
    );
    final codeController = TextEditingController(
      text: branch?['branch_code']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: branch?['phone']?.toString() ?? '',
    );
    final addressController = TextEditingController(
      text: branch?['address']?.toString() ?? '',
    );

    bool saving = false;
    String? formError;

    try {
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> submit() async {
                if (saving || !formKey.currentState!.validate()) return;

                setDialogState(() {
                  saving = true;
                  formError = null;
                });

                try {
                  if (branch == null) {
                    await _authService.createBranch(
                      organizationId: organizationId,
                      name: nameController.text,
                      branchCode: codeController.text,
                      phone: phoneController.text,
                      address: addressController.text,
                    );
                  } else {
                    final branchId = _readId(branch['id']);

                    if (branchId == null) {
                      throw Exception('Invalid branch ID.');
                    }

                    await _authService.updateBranch(
                      organizationId: organizationId,
                      branchId: branchId,
                      name: nameController.text,
                      branchCode: codeController.text,
                      phone: phoneController.text,
                      address: addressController.text,
                    );
                  }

                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  if (!dialogContext.mounted) return;

                  setDialogState(() {
                    saving = false;
                    formError = e.toString().replaceFirst('Exception: ', '');
                  });
                }
              }

              return AlertDialog(
                title: Text(
                  branch == null ? 'Create Branch' : 'Edit Branch',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                        children: [
                          _formField(
                            controller: nameController,
                            label: 'Branch Name',
                            required: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Branch name is required';
                              }
                              if (value.trim().length > 150) {
                                return 'Maximum 150 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _formField(
                            controller: codeController,
                            label: 'Branch Code',
                            required: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Branch code is required';
                              }
                              if (value.trim().length > 50) {
                                return 'Maximum 50 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _formField(
                            controller: phoneController,
                            label: 'Phone',
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value != null && value.trim().length > 30) {
                                return 'Maximum 30 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _formField(
                            controller: addressController,
                            label: 'Address',
                            maxLines: 3,
                          ),
                          if (formError != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formError!,
                                style: const TextStyle(
                                  color: _red,
                                  fontSize: 12,
                                ),
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
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: saving ? null : submit,
                    child: saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            branch == null ? 'Create Branch' : 'Save Changes',
                          ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (saved == true && mounted) {
        await _loadBranches();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              branch == null
                  ? 'Branch created successfully'
                  : 'Branch updated successfully',
            ),
            backgroundColor: const Color(0xFF16834A),
          ),
        );
      }
    } finally {
      nameController.dispose();
      codeController.dispose();
      phoneController.dispose();
      addressController.dispose();
    }
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    bool required = false,
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
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Future<void> _changeBranchStatus(
    Map<String, dynamic> branch,
    String newStatus,
  ) async {
    final organizationId = _selectedOrganizationId;
    final branchId = _readId(branch['id']);

    if (organizationId == null || branchId == null) return;

    final name = branch['name']?.toString() ?? 'this branch';
    final deactivating = newStatus == 'inactive';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(deactivating ? 'Deactivate Branch?' : 'Reactivate Branch?'),
        content: Text(
          deactivating
              ? 'Are you sure you want to deactivate $name?'
              : 'Are you sure you want to reactivate $name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: deactivating ? _red : const Color(0xFF16834A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(deactivating ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _authService.setBranchStatus(
        organizationId: organizationId,
        branchId: branchId,
        status: newStatus,
      );

      await _loadBranches();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deactivating
                ? 'Branch deactivated successfully'
                : 'Branch reactivated successfully',
          ),
          backgroundColor: const Color(0xFF16834A),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _red,
        ),
      );
    }
  }

  Widget _statusChip(String status) {
    final active = status == 'active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE5F5EB) : const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: active ? const Color(0xFF16834A) : _red,
        ),
      ),
    );
  }

  Widget _branchActionsMenu(Map<String, dynamic> branch, bool active) {
    return PopupMenuButton<String>(
      tooltip: 'Branch actions',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'edit' && active) {
          _showBranchDialog(branch: branch);
        } else if (value == 'deactivate' && active) {
          _changeBranchStatus(branch, 'inactive');
        } else if (value == 'reactivate' && !active) {
          _changeBranchStatus(branch, 'active');
        }
      },
      itemBuilder: (context) {
        if (active) {
          return const [
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'deactivate',
              child: Row(
                children: [
                  Icon(Icons.block, color: _red, size: 18),
                  SizedBox(width: 10),
                  Text('Deactivate'),
                ],
              ),
            ),
          ];
        }

        return const [
          PopupMenuItem<String>(
            value: 'reactivate',
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF16834A),
                  size: 18,
                ),
                SizedBox(width: 10),
                Text('Reactivate'),
              ],
            ),
          ),
        ];
      },
    );
  }

  Widget _branchCard(Map<String, dynamic> branch) {
    final status = branch['status']?.toString().toLowerCase() ?? 'inactive';
    final active = status == 'active';

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFFE8E8),
                  child: Icon(Icons.store_outlined, color: _red),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch['name']?.toString() ?? 'Unnamed Branch',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        branch['branch_code']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(status),
                _branchActionsMenu(branch, active),
              ],
            ),
            if ((branch['phone']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(branch['phone'].toString())),
                ],
              ),
            ],
            if ((branch['address']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      branch['address'].toString(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD5DBE4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          isExpanded: true,
          items: [
            DropdownMenuItem(
              value: 'active',
              child: Text('Active (${_countStatus('active')})'),
            ),
            DropdownMenuItem(
              value: 'inactive',
              child: Text('Inactive (${_countStatus('inactive')})'),
            ),
            DropdownMenuItem(
              value: 'all',
              child: Text('All (${_countStatus('all')})'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _statusFilter = value);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBranches;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'BRANCH MANAGEMENT',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _selectedOrganizationId == null || _isLoadingBranches
                ? null
                : _loadBranches,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _selectedOrganizationId == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              onPressed: () => _showBranchDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Create Branch'),
            ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 12 : 20,
          vertical: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Organization Branches',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select an organization to view and manage its branches.',
              style: TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.white,
              elevation: 0,
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
                      'Organization',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingOrganizations)
                      const LinearProgressIndicator()
                    else if (_organizationError != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _organizationError!,
                            style: const TextStyle(color: _red),
                          ),
                          TextButton.icon(
                            onPressed: _loadOrganizations,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      )
                    else
                      DropdownButtonFormField<int>(
                        initialValue: _selectedOrganizationId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Select organization',
                        ),
                        items: _organizations.map((organization) {
                          final id = _readId(organization['id'])!;
                          final name =
                              organization['name']?.toString() ??
                              'Organization $id';
                          final code = organization['organization_code']
                              ?.toString();

                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              code == null || code.isEmpty
                                  ? name
                                  : '$name ($code)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _onOrganizationChanged,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_selectedOrganizationId == null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 42,
                      color: Colors.blueGrey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Select an organization',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Its branches will appear here.',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
            ] else if (_isLoadingBranches) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: _red),
                ),
              ),
            ] else if (_error != null) ...[
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(_error!, style: const TextStyle(color: _red)),
                      TextButton.icon(
                        onPressed: _loadBranches,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;

                  final searchField = TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search branch name, code, phone or address',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _search = value);
                    },
                  );

                  final statusFilter = SizedBox(
                    width: isMobile ? double.infinity : 190,
                    child: _buildStatusFilters(),
                  );

                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 12),
                        statusFilter,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      statusFilter,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Branches',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${filtered.length} found',
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.store_outlined,
                        size: 40,
                        color: Colors.blueGrey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No branches found',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Create a branch or change your filters.',
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1500
                        ? 4
                        : constraints.maxWidth >= 1050
                            ? 3
                            : constraints.maxWidth >= 600
                                ? 2
                                : 1;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: constraints.maxWidth < 600 ? 240 : 190,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _branchCard(filtered[index]);
                      },
                    );
                  },
                ),
              const SizedBox(height: 80),
            ],
          ],
        ),
      ),
    );
  }
}
