import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import 'register_face_screen.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  // List to store employees fetched from API
  final List<Map<String, dynamic>> _allEmployees = [];

  // Filtered employees list for search functionality
  late List<Map<String, dynamic>> _filteredEmployees;

  // Loading state
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _filteredEmployees = _allEmployees;
  }

Future<void> _loadEmployees() async {
  setState(() {
    _isLoading = true;
  });

  try {
    const storage = FlutterSecureStorage();
    final branchId = await storage.read(key: 'branch_id');
    final token = await storage.read(key: 'auth_token');

    if (branchId == null || token == null) {
      throw Exception('Missing branch ID or authentication token.');
    }

    final uri = Uri.parse('http://10.0.2.2:5000/api/employee/getAllEmplyeeByBranch/$branchId');

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Server responded with status ${response.statusCode}');
    }

    final Map<String, dynamic> data = json.decode(response.body);
    final List<dynamic> employees = data['employees'];

    if (employees.isEmpty) {
      throw Exception('No employees found for this branch.');
    }

    _allEmployees.clear();

    for (final emp in employees) {
      try {
        // First, let's see the ENTIRE employee object
        debugPrint('🔍 FULL EMPLOYEE OBJECT: ${emp.toString()}');
        
        // Parse user name
        final userName = emp['userName'] ?? {};
        final firstName = userName['firstName']?.toString() ?? '';
        final lastName = userName['lastName']?.toString() ?? '';
        final fullName = '$firstName $lastName'.trim();

        // Format join date
        final rawJoinDate = emp['createdAt']?.toString();
        final joinDateFormatted = rawJoinDate != null
            ? DateFormat('MMMM dd, yyyy').format(DateTime.parse(rawJoinDate))
            : 'N/A';

        // Let's check ALL possible image fields in the response
        debugPrint('🖼️ Checking ALL possible image fields:');
        debugPrint('userFaceImage: ${emp['userFaceImage']}');
        debugPrint('faceImage: ${emp['faceImage']}');
        debugPrint('avatar: ${emp['avatar']}');
        debugPrint('profileImage: ${emp['profileImage']}');
        debugPrint('image: ${emp['image']}');
        debugPrint('photo: ${emp['photo']}');
        
        // Handle face image from multiple possible fields
        String? faceImageUrl;
        
        // Check userFaceImage (your current field)
        final List<dynamic>? userFaceImages = emp['userFaceImage'];
        if (userFaceImages != null && userFaceImages.isNotEmpty) {
          final firstImage = userFaceImages[0];
          debugPrint('📱 userFaceImage[0]: $firstImage (Type: ${firstImage.runtimeType})');
          
          if (firstImage is String && firstImage.isNotEmpty) {
            faceImageUrl = firstImage;
            debugPrint('✅ Found valid userFaceImage URL: $faceImageUrl');
          } else if (firstImage is Map) {
            // Maybe the image data is nested in an object
            debugPrint('📦 userFaceImage is a Map: $firstImage');
            faceImageUrl = firstImage['url']?.toString() ?? 
                         firstImage['secure_url']?.toString() ?? 
                         firstImage['public_id']?.toString();
            debugPrint('🔗 Extracted URL from Map: $faceImageUrl');
          }
        }
        
        // If no userFaceImage, check other possible fields
        if (faceImageUrl == null || faceImageUrl.isEmpty) {
          debugPrint('⚠️ No userFaceImage found, checking other fields...');
          
          // Check direct string fields
          final possibleFields = ['avatar', 'profileImage', 'image', 'photo', 'faceImage'];
          for (final field in possibleFields) {
            final value = emp[field];
            if (value is String && value.isNotEmpty) {
              faceImageUrl = value;
              debugPrint('✅ Found image in $field: $faceImageUrl');
              break;
            } else if (value != null) {
              debugPrint('❌ $field exists but is not a valid string: $value (Type: ${value.runtimeType})');
            }
          }
        }
        
        // Final URL validation
        if (faceImageUrl != null && faceImageUrl.isNotEmpty) {
          if (Uri.tryParse(faceImageUrl)?.hasAbsolutePath == true) {
            debugPrint('🎉 FINAL VALID IMAGE URL: $faceImageUrl');
          } else {
            debugPrint('❌ Invalid URL format: $faceImageUrl');
            faceImageUrl = null; // Reset to null if invalid
          }
        } else {
          debugPrint('💔 NO IMAGE URL FOUND FOR THIS EMPLOYEE');
        }

        // Handle designation - Fix the designation parsing
        final designation = emp['designationId'];
        String designationName = 'Employee'; // Default value
        
        debugPrint('🏷️ Raw designation data: $designation (Type: ${designation.runtimeType})');
        
        if (designation is Map) {
          // If designation is a map, get the 'name' field
          designationName = designation['name']?.toString() ?? 
                           designation['designationName']?.toString() ?? 
                           'Employee';
          debugPrint('📋 Extracted from Map - designationName: $designationName');
        } else if (designation is String) {
          // If designation is already a string
          designationName = designation;
          debugPrint('📋 Direct string - designationName: $designationName');
        }

        debugPrint('════════════════════════════');
        debugPrint('👤 FINAL EMPLOYEE SUMMARY:');
        debugPrint('Name: $fullName');
        debugPrint('Position: $designationName');
        debugPrint('Avatar URL: $faceImageUrl');
        debugPrint('Has Biometric: ${emp['faceIdExist'] == 1}');
        debugPrint('════════════════════════════');

        _allEmployees.add({
          'id': emp['userId'] ?? '',
          'name': fullName,
          'position': designationName, // This should now be clean
          'email': emp['userEmail'] ?? '',
          'avatar': faceImageUrl,
          'phone': emp['phoneNo'] ?? '+91 9XXXXXXXX',
          'joinDate': joinDateFormatted,
          'gender': emp['gender'] ?? '',
          'faceImage': userFaceImages ?? [],
          'hasBiometric': emp['faceIdExist'] == 1,
        });
      } catch (parseError) {
        debugPrint('❌ Error parsing employee entry: $parseError');
      }
    }

    setState(() {
      _filteredEmployees = List.from(_allEmployees);
      _isLoading = false;
    });
  } catch (e, stackTrace) {
    debugPrint('❌ Load Employee Error: $e');
    debugPrintStack(stackTrace: stackTrace);

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to load employees:\n${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  // Logout functionality
  void _handleLogout() {
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.shade100.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logout Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.logout_outlined,
                        size: 60,
                        color: Colors.cyan.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyan.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Content
                    Text(
                      'Are you sure you want to log out?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Cancel Button
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            foregroundColor: Colors.cyan.shade700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Logout Button
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop(); // Close dialog

                            // Log out via AuthProvider
                            final authProvider = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );
                            await authProvider.logout();
                            // ✅ No need to navigate — app.dart will reactively show LoginScreen
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                          ),
                          child: const Text(
                            'Logout',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  // Search function
  void _searchEmployees(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredEmployees = _allEmployees;
      } else {
        _filteredEmployees =
            _allEmployees
                .where(
                  (employee) =>
                      employee['name'].toString().toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      employee['position'].toString().toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      employee['id'].toString().toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      employee['email'].toString().toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.cyan.shade700),
                    const SizedBox(height: 16),
                    Text(
                      'Loading employees...',
                      style: TextStyle(color: Colors.cyan.shade700),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadEmployees,
                color: Colors.cyan.shade700,
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(context),
                    _buildSearchBar(),
                    _buildEmployeeList(context),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegisterFaceScreen()),
          ).then((_) => _loadEmployees()); // Refresh after registration
        },
        backgroundColor: Colors.cyan.shade700,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
        elevation: 4,
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.cyan.shade700,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Employee Directory',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.cyan.shade800, Colors.cyan.shade500],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -20,
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -10,
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Refresh',
          onPressed: _loadEmployees,
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: 'Logout',
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, position, ID, email...',
                icon: Icon(Icons.search, color: Colors.cyan.shade700),
                border: InputBorder.none,
              ),
              onChanged: _searchEmployees,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeList(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver:
          _filteredEmployees.isEmpty
              ? SliverToBoxAdapter(
                child: Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No employees found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final employee = _filteredEmployees[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildEmployeeCard(context, employee, index),
                  );
                }, childCount: _filteredEmployees.length),
              ),
    );
  }

  Widget _buildEmployeeCard(
    BuildContext context,
    Map<String, dynamic> employee,
    int index,
  ) {
    final List<Color> cardColors = [
      Colors.blue.shade50,
      Colors.green.shade50,
      Colors.purple.shade50,
      Colors.orange.shade50,
      Colors.cyan.shade50,
    ];

    final List<Color> avatarColors = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.purple.shade600,
      Colors.orange.shade600,
      Colors.cyan.shade600,
    ];

    final colorIndex = index % cardColors.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEmployeeModal(context, employee),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, cardColors[colorIndex]],
              stops: const [0.7, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: 'avatar-${employee['id']}',
                  child: _buildAvatar(employee, avatarColors[colorIndex]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        employee['position'],
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${employee['id']}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.cyan.shade700,
                    ),
                    onPressed: () => _showEmployeeModal(context, employee),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> employee, Color fallbackColor) {
    final String? avatarUrl = employee['avatar'];
    
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 28,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey.shade200,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: 28,
          backgroundColor: fallbackColor,
          child: Text(
            employee['name'] != null && employee['name'].toString().isNotEmpty
                ? employee['name'].toString()[0].toUpperCase()
                : 'E',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      return CircleAvatar(
        radius: 28,
        backgroundColor: fallbackColor,
        child: Text(
          employee['name'] != null && employee['name'].toString().isNotEmpty
              ? employee['name'].toString()[0].toUpperCase()
              : 'E',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
  }

  void _showEmployeeModal(BuildContext context, Map<String, dynamic> employee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (BuildContext context) => _EmployeeDetailsModal(employee: employee),
    );
  }
}

class _EmployeeDetailsModal extends StatelessWidget {
  final Map<String, dynamic> employee;

  const _EmployeeDetailsModal({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_buildModalHeader(), _buildEmployeeDetails(context)],
      ),
    );
  }

  Widget _buildModalHeader() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.cyan.shade800, Colors.cyan.shade500],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          // Decorative elements
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -20,
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Close button
          Positioned(
            top: 16,
            right: 16,
            child: Builder(
              builder:
                  (BuildContext context) => Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
            ),
          ),
          // Employee avatar and name
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'avatar-${employee['id']}',
                  child: _buildModalAvatar(employee),
                ),
                const SizedBox(height: 16),
                Text(
                  employee['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  employee['position'],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalAvatar(Map<String, dynamic> employee) {
    final String? avatarUrl = employee['avatar'];
    
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 50,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey.shade200,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: 50,
          backgroundColor: Colors.white,
          child: Text(
            employee['name'] != null && employee['name'].toString().isNotEmpty
                ? employee['name'].toString()[0].toUpperCase()
                : 'E',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.cyan.shade700,
            ),
          ),
        ),
      );
    } else {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.white,
        child: Text(
          employee['name'] != null && employee['name'].toString().isNotEmpty
              ? employee['name'].toString()[0].toUpperCase()
              : 'E',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.cyan.shade700,
          ),
        ),
      );
    }
  }

  Widget _buildEmployeeDetails(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailSection('Employee Information'),
              const SizedBox(height: 16),
              _buildDetailRow(
                Icons.badge_outlined,
                'Employee ID',
                employee['id'],
              ),
              _buildDetailRow(Icons.email_outlined, 'Email', employee['email']),
              _buildDetailRow(
                Icons.phone_outlined,
                'Phone',
                employee['phone'] ?? '+91 9XXXXXXXX',
              ),
              _buildDetailRow(
                Icons.calendar_today_outlined,
                'Joined',
                employee['joinDate'] ?? 'January 15, 2023',
              ),
              if (employee['gender'] != null &&
                  employee['gender'].toString().isNotEmpty)
                _buildDetailRow(
                  Icons.person_outline,
                  'Gender',
                  employee['gender'],
                ),

              const SizedBox(height: 30),
              _buildDetailSection('Biometric Information'),
              const SizedBox(height: 16),
              _buildBiometricStatus(employee['hasBiometric'] == true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 3,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.cyan.shade700,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.cyan.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.cyan.shade700, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricStatus(bool isEnabled) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isEnabled ? Colors.green.shade100 : Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEnabled ? Icons.face : Icons.no_accounts,
              color: isEnabled ? Colors.green.shade700 : Colors.red.shade700,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEnabled
                      ? 'Face Recognition Enabled'
                      : 'Face Recognition Not Set Up',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        isEnabled ? Colors.green.shade700 : Colors.red.shade700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEnabled
                      ? 'Employee can use facial authentication'
                      : 'Employee needs to register face for authentication',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}