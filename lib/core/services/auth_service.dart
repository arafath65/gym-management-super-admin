import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';

class AuthService {
  AuthService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'platform_admin_token';

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/platform-admin/login',
        data: {'email': email.trim(), 'password': password},
      );

      final responseData = response.data;

      if (responseData is! Map<String, dynamic>) {
        throw Exception('Unexpected response from server.');
      }

      final token = responseData['token'];

      if (token == null || token.toString().isEmpty) {
        throw Exception('Login succeeded, but no token was returned.');
      }

      await _storage.write(key: _tokenKey, value: token.toString());

      return responseData;
    } on DioException catch (e) {
      final responseData = e.response?.data;

      if (responseData is Map<String, dynamic> &&
          responseData['message'] != null) {
        throw Exception(responseData['message'].toString());
      }

      if (e.response?.statusCode == 401) {
        throw Exception('Invalid email or password.');
      }

      throw Exception(e.message ?? 'Unable to connect to the server.');
    }
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<List<Map<String, dynamic>>> getOrganizations() async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final response = await _dio.get(
        '/organizations',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map<String, dynamic> ||
          responseData['success'] != true) {
        throw Exception(
          responseData is Map<String, dynamic>
              ? responseData['message']?.toString() ??
                    'Failed to load organizations.'
              : 'Unexpected server response.',
        );
      }

      final organizations = responseData['organizations'];

      if (organizations is! List) {
        throw Exception('Invalid organizations response.');
      }

      return organizations.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (e) {
      final responseData = e.response?.data;

      if (responseData is Map<String, dynamic> &&
          responseData['message'] != null) {
        throw Exception(responseData['message'].toString());
      }

      throw Exception(e.message ?? 'Unable to load organizations.');
    }
  }

  Future<int> getActiveDeviceCount() async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final response = await _dio.get(
        '/platform-admin/dashboard-stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map<String, dynamic> ||
          responseData['success'] != true) {
        throw Exception(
          responseData is Map<String, dynamic>
              ? responseData['message']?.toString() ??
                    'Failed to load dashboard statistics.'
              : 'Unexpected server response.',
        );
      }

      final stats = responseData['stats'];

      if (stats is! Map<String, dynamic> || stats['active_devices'] == null) {
        throw Exception('Invalid dashboard statistics response.');
      }

      final count = stats['active_devices'];

      if (count is num) {
        return count.toInt();
      }

      final parsedCount = int.tryParse(count.toString());

      if (parsedCount == null) {
        throw Exception('Invalid active devices count.');
      }

      return parsedCount;
    } on DioException catch (e) {
      final responseData = e.response?.data;

      if (responseData is Map<String, dynamic> &&
          responseData['message'] != null) {
        throw Exception(responseData['message'].toString());
      }

      throw Exception(e.message ?? 'Unable to load active devices.');
    }
  }

  Future<Map<String, int>> getDashboardStats() async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final response = await _dio.get(
        '/platform-admin/dashboard-stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map<String, dynamic> ||
          responseData['success'] != true) {
        throw Exception(
          responseData is Map<String, dynamic>
              ? responseData['message']?.toString() ??
                    'Failed to load dashboard statistics.'
              : 'Unexpected server response.',
        );
      }

      final stats = responseData['stats'];

      if (stats is! Map) {
        throw Exception('Invalid dashboard statistics response.');
      }

      int readCount(dynamic value, String field) {
        if (value is num) return value.toInt();

        final parsed = int.tryParse(value?.toString() ?? '');

        if (parsed == null) {
          throw Exception('Invalid $field count.');
        }

        return parsed;
      }

      return {
        'active_devices': readCount(stats['active_devices'], 'active devices'),
        'active_licenses': readCount(
          stats['active_licenses'],
          'active licenses',
        ),
        'pending_devices': readCount(
          stats['pending_devices'],
          'pending devices',
        ),
      };
    } on DioException catch (e) {
      final responseData = e.response?.data;

      if (responseData is Map<String, dynamic> &&
          responseData['message'] != null) {
        throw Exception(responseData['message'].toString());
      }

      throw Exception(e.message ?? 'Unable to load dashboard statistics.');
    }
  }

  Future<Map<String, dynamic>> createOrganization({
    required String name,
    required String slug,
    String? email,
    String? phone,
    String? address,
    String licenseType = 'trial',
    int trialDays = 14,
    int maxDevices = 2,
    String? expiresAt,
    String? notes,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final response = await _dio.post(
        '/organizations',
        data: {
          'name': name.trim(),
          'slug': slug.trim().toLowerCase(),
          'email': email?.trim(),
          'phone': phone?.trim(),
          'address': address?.trim(),
          'licenseType': licenseType,
          'trialDays': trialDays,
          'maxDevices': maxDevices,
          'expiresAt': expiresAt,
          'notes': notes?.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map<String, dynamic> ||
          responseData['success'] != true) {
        throw Exception(
          responseData is Map<String, dynamic>
              ? responseData['message']?.toString() ??
                    'Failed to create organization.'
              : 'Unexpected server response.',
        );
      }

      return responseData;
    } on DioException catch (e) {
      final responseData = e.response?.data;

      if (responseData is Map<String, dynamic> &&
          responseData['message'] != null) {
        throw Exception(responseData['message'].toString());
      }

      throw Exception(e.message ?? 'Unable to create organization.');
    }
  }

  Future<Map<String, dynamic>> updateOrganization({
    required int organizationId,
    required String name,
    required String slug,
    String? email,
    String? phone,
    String? address,
    String? licenseType,
    int? maxDevices,
    String? expiresAt,
    String? notes,
    int? trialDays,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final Map<String, dynamic> requestData = {
        'name': name.trim(),
        'slug': slug.trim().toLowerCase(),
        'email': email?.trim(),
        'phone': phone?.trim(),
        'address': address?.trim(),
      };

      final bool licenseFieldsProvided =
          licenseType != null ||
          maxDevices != null ||
          expiresAt != null ||
          notes != null ||
          trialDays != null;

      if (licenseFieldsProvided) {
        if (licenseType == null || maxDevices == null) {
          throw Exception('Select a license type and maximum device count.');
        }

        requestData.addAll({
          'licenseType': licenseType,
          'maxDevices': maxDevices,
          'expiresAt': expiresAt,
          'notes': notes?.trim(),
          'trialDays': trialDays,
        });
      }

      final response = await _dio.put(
        '/organizations/$organizationId',
        data: requestData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map<String, dynamic> ||
          responseData['success'] != true) {
        throw Exception(
          responseData is Map<String, dynamic>
              ? responseData['message']?.toString() ??
                    'Failed to update organization.'
              : 'Unexpected server response.',
        );
      }

      return responseData;
    } on DioException catch (e) {
      final responseData = e.response?.data;

      if (responseData is Map<String, dynamic> &&
          responseData['message'] != null) {
        throw Exception(responseData['message'].toString());
      }

      throw Exception(e.message ?? 'Unable to update organization.');
    }
  }

  Future<Map<String, dynamic>> setOrganizationStatus({
    required int organizationId,
    required String status,
  }) async {
    try {
      if (!['active', 'inactive'].contains(status)) {
        throw Exception('Invalid organization status.');
      }

      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final response = await _dio.patch(
        '/organizations/$organizationId/status',
        data: {'status': status},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final responseData = response.data;

      if (responseData is! Map<String, dynamic> ||
          responseData['success'] != true) {
        throw Exception(
          responseData is Map<String, dynamic>
              ? responseData['message']?.toString() ??
                    'Failed to update organization status.'
              : 'Unexpected server response.',
        );
      }

      return responseData;
    } on DioException catch (e) {
      final responseData = e.response?.data;

      if (responseData is Map<String, dynamic> &&
          responseData['message'] != null) {
        throw Exception(responseData['message'].toString());
      }

      throw Exception(e.message ?? 'Unable to update organization status.');
    }
  }

  // -------------------------------------------------------
  // DEVICE MANAGEMENT
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getDevices({
    String? status,
    int? organizationId,
    int? branchId,
    String? search,
    int page = 1,
    int limit = 25,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final query = <String, dynamic>{'page': page, 'limit': limit};

      if (status != null && status.isNotEmpty && status != 'all') {
        query['status'] = status;
      }

      if (organizationId != null) {
        query['organizationId'] = organizationId;
      }

      if (branchId != null) {
        query['branchId'] = branchId;
      }

      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }

      final response = await _dio.get(
        '/devices',
        queryParameters: query,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data;

      if (data is! Map<String, dynamic> ||
          data['success'] != true ||
          data['devices'] is! List ||
          data['pagination'] is! Map ||
          data['statusCounts'] is! Map) {
        throw Exception('Invalid devices response.');
      }

      return data;
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map<String, dynamic> && data['message'] != null) {
        throw Exception(data['message'].toString());
      }

      throw Exception(e.message ?? 'Unable to load devices.');
    }
  }

  Future<List<Map<String, dynamic>>> getBranches({
    required int organizationId,
    bool activeOnly = true,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final response = await _dio.get(
        '/branches/$organizationId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data;

      if (data is! Map<String, dynamic> ||
          data['success'] != true ||
          data['branches'] is! List) {
        throw Exception('Invalid branches response.');
      }

      final branchList = (data['branches'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();

      if (activeOnly) {
        return branchList
            .where((branch) => branch['status'] == 'active')
            .toList();
      }

      return branchList;
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map<String, dynamic> && data['message'] != null) {
        throw Exception(data['message'].toString());
      }

      throw Exception(e.message ?? 'Unable to load branches.');
    }
  }

  Future<Map<String, dynamic>> registerDevice({
    required int organizationId,
    int? branchId,
    required String deviceUuid,
    required String deviceName,
    required String deviceType,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final response = await _dio.post(
        '/devices/register',
        data: {
          'organization_id': organizationId,
          'registered_branch_id': branchId,
          'device_uuid': deviceUuid.trim(),
          'device_name': deviceName.trim(),
          'device_type': deviceType,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data;

      if (data is! Map<String, dynamic> || data['success'] != true) {
        throw Exception(
          data is Map<String, dynamic>
              ? data['message']?.toString() ?? 'Device registration failed.'
              : 'Unexpected server response.',
        );
      }

      return data;
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map<String, dynamic> && data['message'] != null) {
        throw Exception(data['message'].toString());
      }

      throw Exception(e.message ?? 'Unable to register device.');
    }
  }

  Future<Map<String, dynamic>> regenerateDeviceActivationCode({
    required int deviceId,
  }) async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final response = await _dio.post(
        '/devices/$deviceId/activation-code',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data;

      if (data is! Map<String, dynamic> || data['success'] != true) {
        throw Exception(
          data is Map<String, dynamic>
              ? data['message']?.toString() ??
                    'Unable to generate activation code.'
              : 'Unexpected server response.',
        );
      }

      return data;
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map<String, dynamic> && data['message'] != null) {
        throw Exception(data['message'].toString());
      }

      throw Exception(e.message ?? 'Unable to generate activation code.');
    }
  }

  Future<Map<String, dynamic>> revokeDevice({required int deviceId}) async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final response = await _dio.patch(
        '/devices/$deviceId/revoke',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data;

      if (data is! Map<String, dynamic> || data['success'] != true) {
        throw Exception(
          data is Map<String, dynamic>
              ? data['message']?.toString() ?? 'Unable to revoke device.'
              : 'Unexpected server response.',
        );
      }

      return data;
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map<String, dynamic> && data['message'] != null) {
        throw Exception(data['message'].toString());
      }

      throw Exception(e.message ?? 'Unable to revoke device.');
    }
  }
  // -------------------------------------------------------
  // LICENSE MANAGEMENT
  // -------------------------------------------------------

  String _licenseApiError(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] != null) {
      return data['message'].toString();
    }
    return error.message ?? fallback;
  }

  Future<Map<String, dynamic>> getLicenses({
    String? search,
    String status = 'all',
    String licenseType = 'all',
    int? organizationId,
    int page = 1,
    int limit = 25,
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final query = <String, dynamic>{
        'status': status,
        'licenseType': licenseType,
        'page': page,
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (organizationId != null) {
        query['organizationId'] = organizationId;
      }

      final response = await _dio.get(
        '/licenses',
        queryParameters: query,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['success'] != true ||
          data['licenses'] is! List ||
          data['pagination'] is! Map ||
          data['statusCounts'] is! Map) {
        throw Exception('Invalid licenses response.');
      }
      return data;
    } on DioException catch (e) {
      throw Exception(_licenseApiError(e, 'Unable to load licenses.'));
    }
  }

  Future<Map<String, dynamic>> getLicenseById({required int licenseId}) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final response = await _dio.get(
        '/licenses/$licenseId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['success'] != true ||
          data['license'] is! Map ||
          data['history'] is! List) {
        throw Exception('Invalid license details response.');
      }
      return data;
    } on DioException catch (e) {
      throw Exception(_licenseApiError(e, 'Unable to load license details.'));
    }
  }

  Future<Map<String, dynamic>> createLicense({
    required int organizationId,
    required String licenseType,
    required int maxDevices,
    int? trialDays,
    String? notes,
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final requestData = <String, dynamic>{
        'organizationId': organizationId,
        'licenseType': licenseType,
        'maxDevices': maxDevices,
        'notes': notes?.trim(),
      };
      if (trialDays != null) requestData['trialDays'] = trialDays;

      final response = await _dio.post(
        '/licenses',
        data: requestData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['success'] != true ||
          data['license'] is! Map) {
        throw Exception(
          data is Map<String, dynamic>
              ? data['message']?.toString() ?? 'Unable to issue license.'
              : 'Unexpected server response.',
        );
      }
      return data;
    } on DioException catch (e) {
      throw Exception(_licenseApiError(e, 'Unable to issue license.'));
    }
  }

  Future<Map<String, dynamic>> renewLicense({
    required int licenseId,
    required String licenseType,
    required int maxDevices,
    int? trialDays,
    String? notes,
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final requestData = <String, dynamic>{
        'licenseType': licenseType,
        'maxDevices': maxDevices,
        'notes': notes?.trim(),
      };
      if (trialDays != null) requestData['trialDays'] = trialDays;

      final response = await _dio.post(
        '/licenses/$licenseId/renew',
        data: requestData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['success'] != true ||
          data['license'] is! Map) {
        throw Exception(
          data is Map<String, dynamic>
              ? data['message']?.toString() ?? 'Unable to renew license.'
              : 'Unexpected server response.',
        );
      }
      return data;
    } on DioException catch (e) {
      throw Exception(_licenseApiError(e, 'Unable to renew license.'));
    }
  }

  Future<Map<String, dynamic>> updateLicenseStatus({
    required int licenseId,
    required String status,
  }) async {
    try {
      if (!['active', 'suspended', 'expired'].contains(status)) {
        throw Exception('Invalid license status.');
      }
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final response = await _dio.patch(
        '/licenses/$licenseId/status',
        data: {'status': status},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['success'] != true ||
          data['license'] is! Map) {
        throw Exception(
          data is Map<String, dynamic>
              ? data['message']?.toString() ??
                    'Unable to update license status.'
              : 'Unexpected server response.',
        );
      }
      return data;
    } on DioException catch (e) {
      throw Exception(_licenseApiError(e, 'Unable to update license status.'));
    }
  }

  // -------------------------------------------------------
  // PLATFORM AUDIT LOGS (READ ONLY)
  // -------------------------------------------------------

  Future<Map<String, dynamic>> getPlatformAuditLogs({
    String? search,
    String? action,
    String? entityType,
    String? fromDate,
    String? toDate,
    int? organizationId,
    int? platformAdminId,
    int page = 1,
    int limit = 25,
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again.');
      }

      final query = <String, dynamic>{'page': page, 'limit': limit};

      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (action != null && action.isNotEmpty && action != 'all') {
        query['action'] = action;
      }
      if (entityType != null && entityType.isNotEmpty && entityType != 'all') {
        query['entityType'] = entityType;
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        query['fromDate'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        query['toDate'] = toDate;
      }
      if (organizationId != null) {
        query['organizationId'] = organizationId;
      }
      if (platformAdminId != null) {
        query['platformAdminId'] = platformAdminId;
      }

      final response = await _dio.get(
        '/platform-admin/audit-logs',
        queryParameters: query,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['success'] != true ||
          data['auditLogs'] is! List ||
          data['pagination'] is! Map ||
          data['actions'] is! List ||
          data['entityTypes'] is! List) {
        throw Exception('Invalid platform audit logs response.');
      }

      return data;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception(e.message ?? 'Unable to load platform audit logs.');
    }
  }
}
