import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fishflutter/screen/utils/api_config.dart';
import 'order_detail_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  OrderHistoryScreenState createState() => OrderHistoryScreenState();
}

class OrderHistoryScreenState extends State<OrderHistoryScreen> with TickerProviderStateMixin {
  List<dynamic> orders = [];
  bool _isLoading = true;
  int currentPage = 1;
  bool hasMoreData = true;
  String? selectedStatus;
  bool _isLoadingMore = false;

  late AnimationController _animationController;
  late AnimationController _floatingController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    fetchOrders();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _floatingAnimation = Tween<double>(begin: -20, end: 20).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  Future<void> fetchOrders({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        currentPage = 1;
        hasMoreData = true;
        _isLoading = true;
        orders.clear();
      });
    } else if (_isLoadingMore) {
      return;
    }

    setState(() {
      if (isRefresh) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      String url = '/api/orders?page=$currentPage';
      if (selectedStatus != null && selectedStatus!.isNotEmpty) {
        url += '&status=$selectedStatus';
      }
      
      final response = await http.get(
        ApiConfig.uri(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          final responseData = data['data'] ?? {};
          final newOrders = responseData['data'] ?? [];
          final pagination = responseData['pagination'] ?? {};

          setState(() {
            if (isRefresh) {
              orders = newOrders;
            } else {
              orders.addAll(newOrders);
            }
            
            final currentPageFromApi = pagination['current_page'] ?? 1;
            final totalPages = pagination['total_pages'] ?? 1;
            hasMoreData = currentPageFromApi < totalPages;
            currentPage = currentPageFromApi + 1;
            
            _isLoading = false;
            _isLoadingMore = false;
          });
          
          if (isRefresh) {
            _animationController.forward();
          }
        } else {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
          });
          if (mounted) {
            _showError(data['message'] ?? 'Gagal mengambil data');
          }
        }
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        if (mounted) {
          _showError('Gagal mengambil riwayat pesanan');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        _showError('Terjadi kesalahan: $e');
      }
    }
  }

  Future<void> cancelOrder(int orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.post(
        ApiConfig.uri('/api/orders/$orderId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            _showSuccess('Pesanan berhasil dibatalkan');
            fetchOrders(isRefresh: true);
          }
        } else {
          if (mounted) {
            _showError(data['message'] ?? 'Gagal membatalkan pesanan');
          }
        }
      } else {
        final data = json.decode(response.body);
        if (mounted) {
          _showError(data['message'] ?? 'Gagal membatalkan pesanan');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Terjadi kesalahan: $e');
      }
    }
  }

  void _showError(String message) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showCancelConfirmation(int orderId, String orderNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFD32F2F), size: 28),
            SizedBox(width: 12),
            Text('Batalkan Pesanan'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan pesanan $orderNumber?',
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              cancelOrder(orderId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.filter_list_rounded, color: Color(0xFF1976D2), size: 28),
            SizedBox(width: 12),
            Text('Filter Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('Semua', null),
            _buildFilterOption('Menunggu', 'menunggu'),
            _buildFilterOption('Dibayar', 'dibayar'),
            _buildFilterOption('Diproses', 'diproses'),
            _buildFilterOption('Dikirim', 'dikirim'),
            _buildFilterOption('Selesai', 'selesai'),
            _buildFilterOption('Dibatalkan', 'dibatalkan'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(String label, String? value) {
    return RadioListTile<String?>(
      title: Text(
        label,
        style: const TextStyle(fontFamily: 'Inter'),
      ),
      value: value,
      groupValue: selectedStatus,
      onChanged: (newValue) {
        setState(() {
          selectedStatus = newValue;
        });
        Navigator.pop(context);
        fetchOrders(isRefresh: true);
      },
      activeColor: const Color(0xFF1976D2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Ocean-themed Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D47A1), // Navy Blue
                    Color(0xFF1565C0), // Blue
                    Color(0xFF1976D2), // Light Blue
                    Color(0xFF2196F3), // Ocean Blue
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Animated floating elements
                  AnimatedBuilder(
                    animation: _floatingAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 30 + _floatingAnimation.value,
                        right: -40,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _floatingAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 60 - _floatingAnimation.value,
                        left: -30,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.03),
                          ),
                        ),
                      );
                    },
                  ),

                  // Header content
                  Padding(
                    padding: EdgeInsets.all(isTablet ? 32 : 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Back button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),

                            const SizedBox(width: 20),

                            // Receipt icon with glow effect
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                color: Colors.white,
                                size: isTablet ? 32 : 28,
                              ),
                            ),

                            const SizedBox(width: 20),

                            // Title and subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Riwayat Pesanan',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Inter',
                                      fontSize: isTablet ? 28 : 24,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Lacak semua pesanan ikan Anda',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontFamily: 'Inter',
                                      fontSize: isTablet ? 14 : 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Filter button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.filter_list_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: _showFilterDialog,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Stats row
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  'Total Pesanan',
                                  '${orders.length}',
                                  Icons.shopping_bag_rounded,
                                  isTablet,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  'Aktif',
                                  '${orders.where((o) => o['status'] != 'selesai' && o['status'] != 'dibatalkan').length}',
                                  Icons.pending_actions_rounded,
                                  isTablet,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  'Selesai',
                                  '${orders.where((o) => o['status'] == 'selesai').length}',
                                  Icons.check_circle_rounded,
                                  isTablet,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Filter indicator
            if (selectedStatus != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF1976D2).withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.filter_list_rounded,
                        color: const Color(0xFF1976D2),
                        size: isTablet ? 20 : 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Filter: ${_getStatusLabel(selectedStatus!)}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1976D2),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.grey[600],
                          size: isTablet ? 20 : 18,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedStatus = null;
                          });
                          fetchOrders(isRefresh: true);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            
            // Content area
            Expanded(
              child: _isLoading && orders.isEmpty
                  ? _buildLoadingState(isTablet)
                  : orders.isEmpty
                      ? _buildEmptyState(isTablet)
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: RefreshIndicator(
                              onRefresh: () => fetchOrders(isRefresh: true),
                              color: const Color(0xFF1976D2),
                              backgroundColor: Colors.white,
                              child: ListView.builder(
                                padding: EdgeInsets.all(isTablet ? 24 : 16),
                                itemCount: orders.length + (hasMoreData ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == orders.length) {
                                    // Load more indicator
                                    if (!_isLoadingMore && hasMoreData) {
                                      fetchOrders();
                                    }
                                    return _isLoadingMore
                                        ? Container(
                                            padding: const EdgeInsets.all(20),
                                            child: Center(
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const CircularProgressIndicator(
                                                    color: Color(0xFF1976D2),
                                                    strokeWidth: 2,
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Text(
                                                    'Memuat lebih banyak...',
                                                    style: TextStyle(
                                                      color: const Color(0xFF1976D2),
                                                      fontFamily: 'Inter',
                                                      fontSize: isTablet ? 16 : 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink();
                                  }
                                  
                                  final order = orders[index];
                                  return ModernOrderCard(
                                    order: order,
                                    isTablet: isTablet,
                                    onCancel: () => _showCancelConfirmation(
                                      order['id'],
                                      order['nomor_pesanan'] ?? 'Pesanan',
                                    ),
                                    onViewDetail: () => _showOrderDetail(order),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, bool isTablet) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: isTablet ? 24 : 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontFamily: 'Inter',
            fontSize: isTablet ? 12 : 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isTablet ? 80 : 64,
            height: isTablet ? 80 : 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Memuat riwayat pesanan...',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              color: const Color(0xFF0D47A1),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isTablet) {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 48 : 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated floating receipt icon
              AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatingAnimation.value * 0.3),
                    child: Container(
                      width: isTablet ? 120 : 100,
                      height: isTablet ? 120 : 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                        ),
                        borderRadius: BorderRadius.circular(60),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1976D2).withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        size: isTablet ? 60 : 50,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              Text(
                selectedStatus != null 
                    ? 'Belum ada pesanan dengan status ${_getStatusLabel(selectedStatus!)}'
                    : 'Belum ada pesanan',
                style: TextStyle(
                  fontSize: isTablet ? 24 : 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0D47A1),
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Mulai berbelanja untuk melihat\nriwayat pesanan Anda di sini',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  color: Colors.grey[600],
                  fontFamily: 'Inter',
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Modern action button
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/fish-market',
                        (route) => false,
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 32 : 24,
                        vertical: isTablet ? 16 : 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_bag_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mulai Belanja',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Inter',
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
    );
  }

  String _getStatusLabel(String status) {
    final labels = {
      'menunggu': 'Menunggu Pembayaran',
      'dibayar': 'Dibayar',
      'diproses': 'Diproses',
      'dikirim': 'Dikirim',
      'selesai': 'Selesai',
      'dibatalkan': 'Dibatalkan',
    };
    return labels[status] ?? status;
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(orderId: order['id']),
      ),
    );
  }
}

class ModernOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isTablet;
  final VoidCallback onCancel;
  final VoidCallback onViewDetail;

  const ModernOrderCard({
    super.key,
    required this.order,
    required this.isTablet,
    required this.onCancel,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'menunggu';
    final statusLabel = order['status_label'] ?? _getStatusText(status);
    final canCancel = status == 'menunggu' || status == 'diproses';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(status).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                // Order icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                    size: isTablet ? 20 : 18,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['nomor_pesanan'] ?? 'Pesanan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 18 : 16,
                          color: const Color(0xFF0D47A1),
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        _formatDate(order['tanggal_pesan']),
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.grey[600],
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getStatusColor(status),
                        _getStatusColor(status).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(status).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 12 : 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Order info container
            Container(
              padding: EdgeInsets.all(isTablet ? 16 : 14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.monetization_on_rounded,
                        color: const Color(0xFF4CAF50),
                        size: isTablet ? 18 : 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total: ',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 13,
                          color: Colors.grey[700],
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        order['total_formatted'] ?? 'Rp ${order['total'] ?? 0}',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4CAF50),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  
                  if (order['metode_pembayaran'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.payment_rounded,
                          color: const Color(0xFF1976D2),
                          size: isTablet ? 18 : 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pembayaran: ',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 13,
                            color: Colors.grey[700],
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          order['metode_pembayaran'],
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1976D2),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Items preview
            if (order['items_preview'] != null && order['items_preview'].isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1976D2).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shopping_basket_rounded,
                          color: const Color(0xFF1976D2),
                          size: isTablet ? 18 : 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Item Pesanan:',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1976D2),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...order['items_preview'].map<Widget>((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1976D2),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item['nama_produk'] ?? 'Produk'} (${item['jumlah'] ?? 0}x)',
                                style: TextStyle(
                                  fontSize: isTablet ? 13 : 12,
                                  color: Colors.grey[700],
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (order['has_more_items'] == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1976D2),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'dan lainnya...',
                              style: TextStyle(
                                fontSize: isTablet ? 13 : 12,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ] else if (order['items_count'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_basket_rounded,
                      color: const Color(0xFF1976D2),
                      size: isTablet ? 18 : 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Total ${order['items_count']} item',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 13,
                        color: const Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF1976D2).withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: onViewDetail,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: isTablet ? 14 : 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.visibility_rounded,
                                color: const Color(0xFF1976D2),
                                size: isTablet ? 18 : 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Lihat Detail',
                                style: TextStyle(
                                  color: const Color(0xFF1976D2),
                                  fontSize: isTablet ? 14 : 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                if (canCancel) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFD32F2F).withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onCancel,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: isTablet ? 14 : 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cancel_rounded,
                                  color: const Color(0xFFD32F2F),
                                  size: isTablet ? 18 : 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Batalkan',
                                  style: TextStyle(
                                    color: const Color(0xFFD32F2F),
                                    fontSize: isTablet ? 14 : 13,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu':
        return const Color(0xFFFF9800);
      case 'dibayar':
        return const Color(0xFF2196F3);
      case 'diproses':
        return const Color(0xFF9C27B0);
      case 'dikirim':
        return const Color(0xFF607D8B);
      case 'selesai':
        return const Color(0xFF4CAF50);
      case 'dibatalkan':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu':
        return Icons.access_time_rounded;
      case 'dibayar':
        return Icons.payment_rounded;
      case 'diproses':
        return Icons.build_rounded;
      case 'dikirim':
        return Icons.local_shipping_rounded;
      case 'selesai':
        return Icons.check_circle_rounded;
      case 'dibatalkan':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'menunggu':
        return 'Menunggu';
      case 'dibayar':
        return 'Dibayar';
      case 'diproses':
        return 'Diproses';
      case 'dikirim':
        return 'Dikirim';
      case 'selesai':
        return 'Selesai';
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return status;
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
}