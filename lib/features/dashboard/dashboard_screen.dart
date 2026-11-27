import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../organizations/organizations_screen.dart';
import '../devices/device_management_screen.dart';
import '../branches/branch_management_screen.dart';
import '../audit_logs/audit_logs_screen.dart';
import '../licenses/license_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.adminName});

  final String adminName;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();

  int? _organizationCount;
  bool _isLoadingOrganizations = true;
  String? _organizationError;

  int? _activeDeviceCount;
  bool _isLoadingActiveDevices = true;
  String? _activeDeviceError;
  int? _activeLicenseCount;
  int? _pendingDeviceCount;

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
    _loadActiveDevices();
  }

  Future<void> _loadOrganizations() async {
    try {
      final organizations = await _authService.getOrganizations();

      if (!mounted) return;

      setState(() {
        _organizationCount = organizations.length;
        _isLoadingOrganizations = false;
        _organizationError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingOrganizations = false;
        _organizationError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadActiveDevices() async {
    try {
      final stats = await _authService.getDashboardStats();

      if (!mounted) return;

      setState(() {
        _activeDeviceCount = stats['active_devices'];
        _activeLicenseCount = stats['active_licenses'];
        _pendingDeviceCount = stats['pending_devices'];
        _isLoadingActiveDevices = false;
        _activeDeviceError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingActiveDevices = false;
        _activeDeviceError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GYM SUPER ADMIN',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: const Color(0xFFD9DEE7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${widget.adminName}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage your gym platform',
                style: TextStyle(color: Colors.blueGrey),
              ),
              const SizedBox(height: 24),

              const Text(
                'Platform Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 4
                      : constraints.maxWidth >= 560
                          ? 2
                          : 1;

                  const spacing = 12.0;
                  final cardWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                      columns;

                  final cards = [
                    _SummaryCard(
                      title: 'Organizations',
                      value: _isLoadingOrganizations
                          ? '...'
                          : _organizationCount?.toString() ?? '—',
                      icon: Icons.business_outlined,
                    ),
                    _SummaryCard(
                      title: 'Active Devices',
                      value: _isLoadingActiveDevices
                          ? '...'
                          : _activeDeviceCount?.toString() ?? '—',
                      icon: Icons.devices_outlined,
                    ),
                    _SummaryCard(
                      title: 'Active Licenses',
                      value: _isLoadingActiveDevices
                          ? '...'
                          : _activeLicenseCount?.toString() ?? '—',
                      icon: Icons.verified_outlined,
                    ),
                    _SummaryCard(
                      title: 'Pending Devices',
                      value: _isLoadingActiveDevices
                          ? '...'
                          : _pendingDeviceCount?.toString() ?? '—',
                      icon: Icons.pending_actions_outlined,
                    ),
                  ];

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: cards
                        .map(
                          (card) => SizedBox(
                            width: cardWidth,
                            child: card,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              if (_organizationError != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Organizations: $_organizationError',
                  style: const TextStyle(
                    color: Color(0xFFE50914),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoadingOrganizations = true;
                      _organizationError = null;
                    });
                    _loadOrganizations();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],

              if (_activeDeviceError != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Dashboard statistics: $_activeDeviceError',
                  style: const TextStyle(
                    color: Color(0xFFE50914),
                    fontSize: 12,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoadingActiveDevices = true;
                      _activeDeviceError = null;
                    });
                    _loadActiveDevices();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Dashboard Statistics'),
                ),
              ],
              const SizedBox(height: 28),
              const Text(
                'Management',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              _MenuTile(
                icon: Icons.business,
                title: 'Organizations',
                subtitle: 'Manage gym organizations and branches',
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const OrganizationsScreen(),
                    ),
                  );

                  if (!mounted) return;

                  _loadOrganizations();
                  _loadActiveDevices();
                },
              ),
              _MenuTile(
                icon: Icons.account_tree_outlined,
                title: 'Branch Management',
                subtitle: 'Create, edit and manage organization branches',
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const BranchManagementScreen(),
                    ),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.devices,
                title: 'Device Management',
                subtitle: 'Register, activate and manage devices',
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const DeviceManagementScreen(),
                    ),
                  );

                  if (!mounted) return;

                  _loadActiveDevices();
                },
              ),
              _MenuTile(
                icon: Icons.card_membership,
                title: 'License Management',
                subtitle: 'Manage subscriptions and license status',
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const LicenseManagementScreen(),
                    ),
                  );

                  if (!mounted) return;
                  _loadActiveDevices();
                },
              ),
              _MenuTile(
                icon: Icons.history,
                title: 'Audit Logs',
                subtitle: 'Review platform activity',
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AuditLogsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E7EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFE50914), size: 28),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E7EF)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFE8E8),
          child: Icon(icon, color: const Color(0xFFE50914)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
