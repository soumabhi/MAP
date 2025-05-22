import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final String baseUrl = 'http://10.0.2.2:5000/api'; // Localhost for Android emulator
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';
  static const String _branchIdKey = 'branch_id';

  // ✅ Login with branchId and password
  Future<Map<String, dynamic>> login(String branchId, String password) async {
    print('🔐 [AuthService] Login attempt for branchId: $branchId');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/branch/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'branchId': branchId,
          'password': password,
        }),
      );

      print('📡 [AuthService] Response status: ${response.statusCode}');
      print('📡 [AuthService] Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        await _storage.write(key: _tokenKey, value: data['token']);
        await _storage.write(key: _branchIdKey, value: data['data']['_id']);

        print('✅ [AuthService] Token stored for branch $branchId');

        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        print('❌ [AuthService] Login failed: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid login credentials',
        };
      }
    } catch (e) {
      print('❗ [AuthService] Exception during login: $e');
      return {
        'success': false,
        'message': 'Network error. Try again.',
      };
    }
  }

  // ✅ Check if token exists
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _tokenKey);
    print('🟢 [AuthService] isLoggedIn: ${token != null}');
    return token != null;
  }

  // ✅ Get token
  Future<String?> getToken() async {
    final token = await _storage.read(key: _tokenKey);
    print('🔑 [AuthService] getToken: $token');
    return token;
  }

  // ✅ Get headers for protected routes
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    print('📦 [AuthService] Auth headers: $headers');
    return headers;
  }

  // ✅ Logout
  Future<void> logout() async {
    print('🚪 [AuthService] Logging out...');
    await _storage.deleteAll();
    print('✅ [AuthService] Secure storage cleared');
  }

  // ✅ Get branchId
  Future<String?> getBranchId() async {
    final id = await _storage.read(key: _branchIdKey);
    print('🏢 [AuthService] getBranchId: $id');
    return id;
  }
}
