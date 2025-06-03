import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_app_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import 'sign_in_screen.dart';
import 'order_history_screen.dart';
import 'order_detail_screen.dart';
import 'address_management_screen.dart';
import 'package:fishflutter/screen/utils/api_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? user;
  bool _isLoading = true;
  List<dynamic> recentOrders = [];
  Map<String, int> orderStats = {
    'total': 0,
    'pending': 0,
    'completed': 0,
    'cancelled': 0,
  };

  late AnimationController _animationController;
  late AnimationController _statsController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _statsAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    fetchProfile();
    fetchOrderStats();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _statsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _statsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _statsController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _statsController.dispose();
    super.dispose();
  }

  Future<void> fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        ApiConfig.uri('/api/user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          user = data['data']['user'] ?? data['data'] ?? data;
          _isLoading = false;
        });
        
        await prefs.setString('user', json.encode(user));
        _animationController.forward();
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Gagal mengambil data profil');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> fetchOrderStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        ApiConfig.uri('/api/orders?limit=5'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        List<dynamic> orders = [];
        if (data['success'] == true && data['data'] != null) {
          if (data['data']['data'] != null) {
            orders = data['data']['data'];
          } else if (data['data'] is List) {
            orders = data['data'];
          }
        } else if (data['data'] != null) {
          orders = data['data'] is List ? data['data'] : [];
        }
        
        int total = orders.length;
        int pending = orders.where((order) => 
          order['status']?.toString().toLowerCase() == 'pending' ||
          order['status']?.toString().toLowerCase() == 'menunggu' ||
          order['status']?.toString().toLowerCase() == 'diproses'
        ).length;
        int completed = orders.where((order) => 
          order['status']?.toString().toLowerCase() == 'completed' ||
          order['status']?.toString().toLowerCase() == 'selesai'
        ).length;
        int cancelled = orders.where((order) => 
          order['status']?.toString().toLowerCase() == 'cancelled' ||
          order['status']?.toString().toLowerCase() == 'dibatalkan'
        ).length;
        
        setState(() {
          recentOrders = orders.take(3).toList(); // Ambil 3 pesanan terbaru
          orderStats = {
            'total': total,
            'pending': pending,
            'completed': completed,
            'cancelled': cancelled,
          };
        });
        _statsController.forward();
      }
    } catch (e) {
      print('Error fetching order stats: $e');
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFD32F2F)),
            SizedBox(width: 8),
            Text('Konfirmasi Keluar'),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('token') ?? '';
                
                await http.post(
                  ApiConfig.uri('/api/logout'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                );
              } catch (e) {
                print('Logout API error: $e');
              } finally {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SignInScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: user?['name'] ?? '');
    final emailController = TextEditingController(text: user?['email'] ?? '');
    final phoneController = TextEditingController(text: user?['phone'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF1976D2)),
            SizedBox(width: 8),
            Text('Edit Profil'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(nameController, 'Nama', Icons.person),
              const SizedBox(height: 16),
              _buildDialogTextField(emailController, 'Email', Icons.email, enabled: false),
              const SizedBox(height: 16),
              _buildDialogTextField(phoneController, 'No. Telepon', Icons.phone),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updateProfile(nameController.text, phoneController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String label, IconData icon, {bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1976D2)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
        ),
      ),
    );
  }

  Future<void> _updateProfile(String name, String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.put(
        ApiConfig.uri('/api/user'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'name': name,
          'phone': phone,
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Profil berhasil diperbarui'),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        fetchProfile();
      } else {
        final data = json.decode(response.body);
        String errorMsg = 'Gagal memperbarui profil';
        if (data['errors'] != null) {
          data['errors'].forEach((key, value) {
            errorMsg += '\n${value[0]}';
          });
        }
        _showErrorSnackBar(errorMsg);
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(orderId: order['id']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: SafeArea(
        child: Column(
          children: [
            // Modern App Bar
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1565C0),
                    Color(0xFF0D47A1),
                    Color(0xFF002171),
                  ],
                ),
              ),
              child: const CustomAppBar(),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                      ),
                    )
                  : user == null
                      ? const Center(child: Text('Tidak ada data profil'))
                      : RefreshIndicator(
                          onRefresh: () async {
                            await fetchProfile();
                            await fetchOrderStats();
                          },
                          color: const Color(0xFF1976D2),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                // Profile Header
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: Container(
                                      margin: const EdgeInsets.all(20),
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                        ),
                                        borderRadius: BorderRadius.circular(25),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF1976D2).withOpacity(0.3),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          // Avatar
                                          Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.person,
                                              size: 50,
                                              color: Color(0xFF1976D2),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          
                                          // User Info
                                          Text(
                                            user?['name'] ?? '-',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            user?['email'] ?? '-',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 16,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          if (user?['phone'] != null && user!['phone'].toString().isNotEmpty)
                                            Text(
                                              user!['phone'],
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 14,
                                                color: Colors.white60,
                                              ),
                                            ),
                                          
                                          const SizedBox(height: 20),
                                          
                                          // Edit Button
                                          ElevatedButton.icon(
                                            onPressed: _showEditProfileDialog,
                                            icon: const Icon(Icons.edit, size: 18),
                                            label: const Text('Edit Profil'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: const Color(0xFF1976D2),
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(25),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Order Statistics
                                AnimatedBuilder(
                                  animation: _statsAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _statsAnimation.value,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _buildStatCard(
                                                'Total Pesanan',
                                                orderStats['total'].toString(),
                                                Icons.shopping_bag,
                                                const Color(0xFF4CAF50),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _buildStatCard(
                                                'Menunggu',
                                                orderStats['pending'].toString(),
                                                Icons.access_time,
                                                const Color(0xFFFF9800),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _buildStatCard(
                                                'Selesai',
                                                orderStats['completed'].toString(),
                                                Icons.check_circle,
                                                const Color(0xFF2E7D32),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 24),

                                // Recent Orders Section
                                if (recentOrders.isNotEmpty)
                                  FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Pesanan Terbaru',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0D47A1),
                                                  fontFamily: 'Inter',
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => const OrderHistoryScreen(),
                                                    ),
                                                  );
                                                },
                                                child: const Text('Lihat Semua'),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ...recentOrders.map((order) => 
                                            _buildRecentOrderCard(order)
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 24),

                                // Menu Items
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Column(
                                      children: [
                                        _buildModernMenuTile(
                                          icon: Icons.receipt_long,
                                          title: 'Riwayat Pesanan',
                                          subtitle: 'Lihat semua pesanan Anda',
                                          color: const Color(0xFF1976D2),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              PageRouteBuilder(
                                                pageBuilder: (context, animation, secondaryAnimation) =>
                                                    const OrderHistoryScreen(),
                                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                  return SlideTransition(
                                                    position: Tween<Offset>(
                                                      begin: const Offset(1.0, 0.0),
                                                      end: Offset.zero,
                                                    ).animate(animation),
                                                    child: child,
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        _buildModernMenuTile(
                                          icon: Icons.location_on,
                                          title: 'Kelola Alamat',
                                          subtitle: 'Atur alamat pengiriman',
                                          color: const Color(0xFF4CAF50),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              PageRouteBuilder(
                                                pageBuilder: (context, animation, secondaryAnimation) =>
                                                    const AddressManagementScreen(),
                                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                  return SlideTransition(
                                                    position: Tween<Offset>(
                                                      begin: const Offset(1.0, 0.0),
                                                      end: Offset.zero,
                                                    ).animate(animation),
                                                    child: child,
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        _buildModernMenuTile(
                                          icon: Icons.notifications_outlined,
                                          title: 'Pengaturan Notifikasi',
                                          subtitle: 'Atur notifikasi aplikasi',
                                          color: const Color(0xFFFF5722),
                                          onTap: () {
                                            _showNotificationSettings();
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        _buildModernMenuTile(
                                          icon: Icons.security,
                                          title: 'Keamanan',
                                          subtitle: 'Ubah password dan keamanan',
                                          color: const Color(0xFF795548),
                                          onTap: () {
                                            _showSecurityDialog();
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        _buildModernMenuTile(
                                          icon: Icons.help_outline,
                                          title: 'Pusat Bantuan',
                                          subtitle: 'FAQ dan panduan aplikasi',
                                          color: const Color(0xFFFF9800),
                                          onTap: () {
                                            _showHelpCenter();
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        _buildModernMenuTile(
                                          icon: Icons.star_outline,
                                          title: 'Beri Rating',
                                          subtitle: 'Berikan rating untuk aplikasi',
                                          color: const Color(0xFFFFC107),
                                          onTap: () {
                                            _showRatingDialog();
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        _buildModernMenuTile(
                                          icon: Icons.info_outline,
                                          title: 'Tentang Aplikasi',
                                          subtitle: 'Informasi aplikasi IwakMart',
                                          color: const Color(0xFF9C27B0),
                                          onTap: _showAboutDialog,
                                        ),
                                        const SizedBox(height: 24),
                                        
                                        // Logout Button
                                        Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFD32F2F).withOpacity(0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(16),
                                              onTap: _logout,
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 16),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.logout, color: Colors.white),
                                                    SizedBox(width: 12),
                                                    Text(
                                                      'Keluar dari Akun',
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 100), // Space for bottom nav
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildRecentOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final statusLabel = _getStatusText(status);
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showOrderDetail(order),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getStatusIcon(status),
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order['nomor_pesanan'] ?? 'Order #${order['id']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(order['total']),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(order['created_at']),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color(0xFF666666),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods for status handling
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'menunggu':
        return const Color(0xFFFF9800);
      case 'paid':
      case 'dibayar':
        return const Color(0xFF2196F3);
      case 'processing':
      case 'diproses':
        return const Color(0xFF9C27B0);
      case 'shipped':
      case 'dikirim':
        return const Color(0xFF607D8B);
      case 'completed':
      case 'selesai':
        return const Color(0xFF4CAF50);
      case 'cancelled':
      case 'dibatalkan':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'menunggu':
        return Icons.access_time_rounded;
      case 'paid':
      case 'dibayar':
        return Icons.payment_rounded;
      case 'processing':
      case 'diproses':
        return Icons.build_rounded;
      case 'shipped':
      case 'dikirim':
        return Icons.local_shipping_rounded;
      case 'completed':
      case 'selesai':
        return Icons.check_circle_rounded;
      case 'cancelled':
      case 'dibatalkan':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'menunggu':
        return 'Menunggu';
      case 'paid':
      case 'dibayar':
        return 'Dibayar';
      case 'processing':
      case 'diproses':
        return 'Diproses';
      case 'shipped':
      case 'dikirim':
        return 'Dikirim';
      case 'completed':
      case 'selesai':
        return 'Selesai';
      case 'cancelled':
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'Rp 0';
    
    try {
      final priceValue = double.tryParse(price.toString()) ?? 0;
      return 'Rp ${priceValue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    } catch (e) {
      return 'Rp 0';
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '-';
    }
  }

  void _showNotificationSettings() {
    bool orderNotif = true;
    bool promoNotif = false;
    bool chatNotif = true;
    bool appointmentNotif = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.notifications, color: Color(0xFFFF5722)),
              SizedBox(width: 8),
              Text('Pengaturan Notifikasi'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Notifikasi Pesanan'),
                subtitle: const Text('Pemberitahuan status pesanan'),
                value: orderNotif,
                onChanged: (value) => setDialogState(() => orderNotif = value),
                activeColor: const Color(0xFF1976D2),
              ),
              SwitchListTile(
                title: const Text('Notifikasi Promo'),
                subtitle: const Text('Penawaran dan diskon khusus'),
                value: promoNotif,
                onChanged: (value) => setDialogState(() => promoNotif = value),
                activeColor: const Color(0xFF1976D2),
              ),
              SwitchListTile(
                title: const Text('Notifikasi Chat'),
                subtitle: const Text('Pesan dari penjual'),
                value: chatNotif,
                onChanged: (value) => setDialogState(() => chatNotif = value),
                activeColor: const Color(0xFF1976D2),
              ),
              SwitchListTile(
                title: const Text('Notifikasi Janji Temu'),
                subtitle: const Text('Pengingat janji temu'),
                value: appointmentNotif,
                onChanged: (value) => setDialogState(() => appointmentNotif = value),
                activeColor: const Color(0xFF1976D2),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Pengaturan notifikasi disimpan'),
                      ],
                    ),
                    backgroundColor: const Color(0xFF4CAF50),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF795548)),
            SizedBox(width: 8),
            Text('Keamanan Akun'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.lock, color: Color(0xFF1976D2)),
              title: const Text('Ubah Password'),
              subtitle: const Text('Ganti password akun Anda'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _showChangePasswordDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.fingerprint, color: Color(0xFF4CAF50)),
              title: const Text('Biometrik'),
              subtitle: const Text('Login dengan sidik jari'),
              trailing: Switch(
                value: false,
                onChanged: (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fitur biometrik akan segera hadir'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                activeColor: const Color(0xFF1976D2),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ubah Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password Saat Ini',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password Baru',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Konfirmasi Password Baru',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordController.text == confirmPasswordController.text) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password berhasil diubah'),
                    backgroundColor: Color(0xFF4CAF50),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Konfirmasi password tidak cocok'),
                    backgroundColor: Color(0xFFD32F2F),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ubah'),
          ),
        ],
      ),
    );
  }

  void _showHelpCenter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help, color: Color(0xFFFF9800)),
            SizedBox(width: 8),
            Text('Pusat Bantuan'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Frequently Asked Questions (FAQ)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildFAQItem('Bagaimana cara memesan ikan?', 
                'Pilih ikan yang diinginkan, tambahkan ke keranjang, lalu checkout.'),
              _buildFAQItem('Apakah ikan yang dijual segar?', 
                'Ya, semua ikan yang dijual adalah ikan segar, anda bisa melihat informasi lebih lanjut di halaman produk.'),
              _buildFAQItem('Bagaimana cara membayar?', 
                'Anda bisa membayar dengan COD atau transfer bank.'),
              _buildFAQItem('Berapa lama pengiriman?', 
                'Pengiriman reguler 2-3 hari, express 1 hari.'),
              const SizedBox(height: 16),
              const Text(
                'Kontak Customer Service:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('📞 WhatsApp: +62 812-3456-7890'),
              const Text('📧 Email: support@iwakmart.com'),
              const Text('⏰ Jam Operasional: 08:00 - 22:00 WIB'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            answer,
            style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
          ),
        ),
      ],
    );
  }

  void _showRatingDialog() {
    int rating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFFFC107)),
              SizedBox(width: 8),
              Text('Beri Rating'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Berikan rating untuk aplikasi IwakMart',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        rating = index + 1;
                      });
                    },
                    child: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFFC107),
                      size: 40,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Komentar (Opsional)',
                  border: OutlineInputBorder(),
                  hintText: 'Berikan komentar Anda tentang aplikasi...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: rating > 0 ? () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.thumb_up, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Terima kasih atas rating $rating bintang!'),
                      ],
                    ),
                    backgroundColor: const Color(0xFF4CAF50),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
              ),
              child: const Text('Kirim Rating'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.waves, color: Color(0xFF1976D2)),
            ),
            const SizedBox(width: 12),
            const Text('Tentang IwakMart'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.waves,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'IwakMart v1.0.0',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Marketplace Ikan Segar Terpercaya',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'IwakMart adalah aplikasi marketplace yang menghubungkan Anda dengan penjual ikan segar terpercaya. Nikmati kemudahan berbelanja ikan segar berkualitas tinggi dengan cepat dan aman.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F8FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1976D2).withOpacity(0.2),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fitur Unggulan:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('🐟 Ikan segar berkualitas tinggi'),
                    Text('🚚 Pengiriman cepat dan aman'),
                    Text('💬 Chat langsung dengan penjual'),
                    Text('📍 Janji temu dengan petani/nelayan'),
                    Text('📱 Interface yang user-friendly'),
                    Text('🔒 Transaksi yang aman'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}