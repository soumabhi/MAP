import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _branchId;
  String? _error;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get branchId => _branchId;
  String? get error => _error;

  AuthProvider() {
    print('🟡 AuthProvider initialized');
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    print('🔍 Checking auth status...');
    _isLoading = true;
    notifyListeners();

    try {
      final loggedIn = await _authService.isLoggedIn();
      print('✅ isLoggedIn: $loggedIn');

      _isAuthenticated = loggedIn;

      if (loggedIn) {
        _branchId = await _authService.getBranchId();
        print('🏢 Authenticated Branch ID: $_branchId');
      }
    } catch (e) {
      print('❌ Error during checkAuthStatus: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String branchId, String password) async {
    print('🔐 Attempting login from AuthProvider...');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.login(branchId, password);
      print('📡 Login API result: $result');

      if (result['success']) {
        _isAuthenticated = true;
        _branchId = branchId;
        print('✅ Login success. Branch ID: $_branchId');
      } else {
        _isAuthenticated = false;
        _error = result['message'];
        print('❌ Login failed: $_error');
      }
    } catch (e) {
      _isAuthenticated = false;
      _error = 'An unexpected error occurred.';
      print('❌ Exception during login: $e');
    }

    _isLoading = false;
    notifyListeners();
    return _isAuthenticated;
  }

  Future<void> logout() async {
    print('🚪 Logging out...');
    try {
      await _authService.logout();
      _isAuthenticated = false;
      _branchId = null;
      print('✅ Logout successful.');
    } catch (e) {
      print('❌ Error during logout: $e');
    }

    notifyListeners();
  }
}
