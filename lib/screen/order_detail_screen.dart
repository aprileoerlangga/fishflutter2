import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fishflutter/screen/utils/api_config.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? orderDetail;
  List<dynamic> orderItems = [];
  bool _isLoading = true;
  bool _isActionLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    fetchOrderDetail();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> fetchOrderDetail() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      print('🔄 Fetching order detail for ID: ${widget.orderId}');
      
      final response = await http.get(
        ApiConfig.uri('/api/orders/${widget.orderId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📋 Order Detail Response: ${response.statusCode}');
      print('📋 Order Detail Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different response structures
        Map<String, dynamic>? order;
        if (data['success'] == true && data['data'] != null) {
          order = data['data'];
        } else if (data['data'] != null) {
          order = data['data'];
        } else if (data is Map<String, dynamic>) {
          order = data;
        }

        if (order != null) {
          setState(() {
            orderDetail = order;
            // Extract items from order detail
            if (order!['items'] != null) {
              orderItems = order['items'];
            } else if (order['order_items'] != null) {
              orderItems = order['order_items'];
            } else if (order['detail_items'] != null) {
              orderItems = order['detail_items'];
            }
            _isLoading = false;
          });
          
          _animationController.forward();
          
          // If items not included, fetch separately 
          if (orderItems.isEmpty) {
            fetchOrderItems();
          }
        } else {
          setState(() => _isLoading = false);
          _showError('Data pesanan tidak ditemukan');
        }
      } else if (response.statusCode == 404) {
        setState(() => _isLoading = false);
        _showError('Pesanan tidak ditemukan');
      } else {
        setState(() => _isLoading = false);
        _showError('Gagal mengambil detail pesanan (${response.statusCode})');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ Order detail error: $e');
      _showError('Terjadi kesalahan: $e');
    }
  }

  Future<void> fetchOrderItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      print('🔄 Fetching order items for ID: ${widget.orderId}');
      
      final response = await http.get(
        ApiConfig.uri('/api/orders/${widget.orderId}/items'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📦 Order Items Response: ${response.statusCode}');
      print('📦 Order Items Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> items = [];
        
        if (data['success'] == true && data['data'] != null) {
          items = data['data'];
        } else if (data['data'] != null) {
          if (data['data'] is List) {
            items = data['data'];
          } else if (data['data']['items'] != null) {
            items = data['data']['items'];
          }
        } else if (data is List) {
          items = data;
        }
        
        setState(() {
          orderItems = items;
        });
      }
    } catch (e) {
      print('❌ Order items error: $e');
    }
  }

  Future<void> cancelOrder() async {
    setState(() => _isActionLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.post(
        ApiConfig.uri('/api/orders/${widget.orderId}/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      setState(() => _isActionLoading = false);

      print('❌ Cancel Order Response: ${response.statusCode}');
      print('❌ Cancel Order Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showSuccess('Pesanan berhasil dibatalkan');
          fetchOrderDetail(); // Refresh
        } else {
          _showError(data['message'] ?? 'Gagal membatalkan pesanan');
        }
      } else {
        final data = json.decode(response.body);
        _showError(data['message'] ?? 'Gagal membatalkan pesanan');
      }
    } catch (e) {
      setState(() => _isActionLoading = false);
      _showError('Terjadi kesalahan: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
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
  }

  void _showSuccess(String message) {
    if (mounted) {
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFD32F2F)),
            SizedBox(width: 8),
            Text('Batalkan Pesanan'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan pesanan ${orderDetail?['nomor_pesanan'] ?? ''}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: _isActionLoading 
                ? null 
                : () {
                    Navigator.pop(context);
                    cancelOrder();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
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
                boxShadow: [
                  BoxShadow(
                    color: Color(0x30000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Back Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Order Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detail Pesanan',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (orderDetail != null)
                            Text(
                              orderDetail!['nomor_pesanan'] ?? 'Order #${widget.orderId}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                      ),
                    )
                  : orderDetail == null
                      ? _buildErrorState()
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Order Status Card
                                  _buildStatusCard(),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Order Info Card
                                  _buildOrderInfoCard(),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Shipping Address Card
                                  if (orderDetail!['alamat'] != null || orderDetail!['address'] != null)
                                    _buildAddressCard(),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Order Items Card
                                  _buildOrderItemsCard(),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Price Summary Card
                                  _buildPriceSummaryCard(),
                                  
                                  const SizedBox(height: 80), // Space for action buttons
                                ],
                              ),
                            ),
                          ),
                        ),
            ),

            // Bottom Action Buttons
            if (orderDetail != null && _showActionButtons())
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x20000000),
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_canCancel())
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
                              onTap: _isActionLoading ? null : _showCancelConfirmation,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: _isActionLoading
                                    ? const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD32F2F)),
                                          ),
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cancel_rounded,
                                            color: Color(0xFFD32F2F),
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Batalkan Pesanan',
                                            style: TextStyle(
                                              color: Color(0xFFD32F2F),
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    if (_canCancel()) const SizedBox(width: 12),
                    
                    // Info button for order status
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
                            onTap: () {
                              _showStatusInfo();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFF1976D2),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Info Status',
                                    style: TextStyle(
                                      color: Color(0xFF1976D2),
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xFFD32F2F),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Pesanan Tidak Ditemukan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Detail pesanan tidak dapat dimuat.\nSilakan coba lagi nanti.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontFamily: 'Inter',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: fetchOrderDetail,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = orderDetail!['status'] ?? 'menunggu';
    final statusLabel = orderDetail!['status_label'] ?? _getStatusText(status);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor(status),
            _getStatusColor(status).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(status).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getStatusIcon(status),
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pesanan ${orderDetail!['nomor_pesanan'] ?? 'Order #${widget.orderId}'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF1976D2),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Informasi Pesanan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0D47A1),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Nomor Pesanan', orderDetail!['nomor_pesanan'] ?? 'Order #${widget.orderId}'),
          _buildInfoRow('Tanggal', _formatDateTime(orderDetail!['created_at'] ?? orderDetail!['tanggal_pesan'])),
          _buildInfoRow('Status Pembayaran', 
            orderDetail!['status_pembayaran_label'] ?? 
            orderDetail!['status_pembayaran'] ?? '-'),
          _buildInfoRow('Metode Pembayaran', 
            orderDetail!['metode_pembayaran_label'] ?? 
            orderDetail!['metode_pembayaran'] ?? '-'),
          _buildInfoRow('Metode Pengiriman', orderDetail!['metode_pengiriman'] ?? '-'),
          if (orderDetail!['catatan'] != null && 
              orderDetail!['catatan'].toString().isNotEmpty)
            _buildInfoRow('Catatan', orderDetail!['catatan']),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    final address = orderDetail!['alamat'] ?? orderDetail!['address'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Alamat Pengiriman',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0D47A1),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAddressInfo(address),
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shopping_basket,
                  color: Color(0xFFFF9800),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Item Pesanan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0D47A1),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (orderItems.isNotEmpty)
            ...orderItems.map<Widget>((item) => _buildOrderItem(item)).toList()
          else if (orderDetail!['items'] != null && orderDetail!['items'].isNotEmpty)
            ...orderDetail!['items'].map<Widget>((item) => _buildOrderItem(item)).toList()
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Tidak ada item pesanan',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E8), Color(0xFFC8E6C9)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF2E7D32),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Ringkasan Pembayaran',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPriceRow('Subtotal', 
            orderDetail!['subtotal_formatted'] ?? 
            _formatPrice(orderDetail!['subtotal'])),
          _buildPriceRow('Ongkir', 
            orderDetail!['biaya_kirim_formatted'] ?? 
            _formatPrice(orderDetail!['biaya_kirim'] ?? orderDetail!['ongkir'])),
          if (orderDetail!['pajak'] != null && (orderDetail!['pajak'] ?? 0) > 0)
            _buildPriceRow('Pajak', 
              orderDetail!['pajak_formatted'] ?? 
              _formatPrice(orderDetail!['pajak'])),
          const Divider(height: 24, thickness: 2),
          _buildPriceRow(
            'Total',
            orderDetail!['total_formatted'] ?? 
            _formatPrice(orderDetail!['total']),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const Text(': '),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF0D47A1),
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressInfo(Map<String, dynamic>? address) {
    if (address == null) {
      return const Text(
        'Alamat tidak tersedia',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          address['nama_penerima'] ?? address['nama'] ?? '-',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF0D47A1),
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.phone, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              address['telepon'] ?? address['phone'] ?? '-',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address['alamat_lengkap'] ?? address['alamat'] ?? '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${address['kecamatan'] ?? '-'}, ${address['kota'] ?? '-'}, ${address['provinsi'] ?? '-'} ${address['kode_pos'] ?? '-'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final product = item['product'] ?? item['produk'] ?? {};
    String imageUrl = '';
    
    if (product['gambar'] != null && product['gambar'] is List && product['gambar'].isNotEmpty) {
      imageUrl = ApiConfig.imageUrl(product['gambar'][0]);
    } else if (product['gambar'] != null && product['gambar'] is String) {
      imageUrl = ApiConfig.imageUrl(product['gambar']);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1976D2).withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.image, color: Color(0xFF1976D2)),
                    )
                  : const Icon(Icons.image, color: Color(0xFF1976D2)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['nama_produk'] ?? product['nama'] ?? 'Produk',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF0D47A1),
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Harga: ${item['harga_formatted'] ?? _formatPrice(item['harga'])}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  'Jumlah: ${item['jumlah'] ?? 0}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          Text(
            item['subtotal_formatted'] ?? _formatPrice(item['subtotal']),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF2E7D32),
              fontFamily: 'Inter',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E7D32),
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'menunggu':
      case 'pending':
        return const Color(0xFFFF9800);
      case 'dibayar':
      case 'paid':
        return const Color(0xFF2196F3);
      case 'diproses':
      case 'processing':
        return const Color(0xFF9C27B0);
      case 'dikirim':
      case 'shipped':
        return const Color(0xFF607D8B);
      case 'selesai':
      case 'completed':
      case 'delivered':
        return const Color(0xFF4CAF50);
      case 'dibatalkan':
      case 'cancelled':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'menunggu':
      case 'pending':
        return Icons.access_time_rounded;
      case 'dibayar':
      case 'paid':
        return Icons.payment_rounded;
      case 'diproses':
      case 'processing':
        return Icons.build_rounded;
      case 'dikirim':
      case 'shipped':
        return Icons.local_shipping_rounded;
      case 'selesai':
      case 'completed':
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'dibatalkan':
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'menunggu':
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'dibayar':
      case 'paid':
        return 'Dibayar';
      case 'diproses':
      case 'processing':
        return 'Diproses';
      case 'dikirim':
      case 'shipped':
        return 'Dikirim';
      case 'selesai':
      case 'completed':
      case 'delivered':
        return 'Selesai';
      case 'dibatalkan':
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status ?? 'Status Tidak Diketahui';
    }
  }

  bool _showActionButtons() {
    return true; // Always show action buttons
  }

  bool _canCancel() {
    final status = orderDetail?['status']?.toString().toLowerCase();
    return status == 'menunggu' || status == 'pending' || status == 'diproses' || status == 'processing';
  }

  void _showStatusInfo() {
    final status = orderDetail?['status'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF1976D2)),
            SizedBox(width: 8),
            Text('Status Pesanan'),
          ],
        ),
        content: Text(_getStatusInfo(status)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getStatusInfo(String? status) {
    switch (status?.toLowerCase()) {
      case 'menunggu':
      case 'pending':
        return 'Pesanan Anda sedang menunggu konfirmasi pembayaran. Anda masih bisa membatalkan pesanan.';
      case 'dibayar':
      case 'paid':
        return 'Pembayaran Anda telah diterima. Pesanan akan segera diproses oleh penjual.';
      case 'diproses':
      case 'processing':
        return 'Pesanan Anda sedang diproses oleh penjual. Anda masih bisa membatalkan pesanan.';
      case 'dikirim':
      case 'shipped':
        return 'Pesanan Anda sudah dikirim. Silakan tunggu hingga pesanan tiba di alamat Anda.';
      case 'selesai':
      case 'completed':
      case 'delivered':
        return 'Pesanan Anda telah selesai. Terima kasih telah berbelanja!';
      case 'dibatalkan':
      case 'cancelled':
        return 'Pesanan Anda telah dibatalkan.';
      default:
        return 'Status pesanan: ${status ?? 'Tidak diketahui'}';
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) return '-';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
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
}