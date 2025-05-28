import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fishflutter/screen/utils/api_config.dart';

class CheckoutScreen extends StatefulWidget {
  final String totalPrice;
  final int selectedCount;
  final List<dynamic> cartItems;

  const CheckoutScreen({
    super.key,
    required this.totalPrice,
    required this.selectedCount,
    required this.cartItems,
  });

  @override
  CheckoutScreenState createState() => CheckoutScreenState();
}

class CheckoutScreenState extends State<CheckoutScreen> with TickerProviderStateMixin {
  List<dynamic> addresses = [];
  int? selectedAddressId;
  String selectedShippingMethod = 'reguler';
  String selectedPaymentMethod = 'cod';
  double shippingCost = 10000;
  bool _isLoading = false;
  bool _isLoadingAddresses = true;
  final _notesController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    fetchAddresses();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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
    _notesController.dispose();
    super.dispose();
  }

  Future<void> fetchAddresses() async {
    setState(() => _isLoadingAddresses = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        ApiConfig.uri('/api/addresses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            addresses = data['data'] ?? [];
            // Set alamat utama sebagai default
            if (addresses.isNotEmpty) {
              final mainAddress = addresses.firstWhere(
                (addr) => addr['alamat_utama'] == true,
                orElse: () => addresses[0],
              );
              selectedAddressId = mainAddress['id'];
            }
            _isLoadingAddresses = false;
          });
          _animationController.forward();
        } else {
          setState(() => _isLoadingAddresses = false);
        }
      } else {
        setState(() => _isLoadingAddresses = false);
      }
    } catch (e) {
      setState(() => _isLoadingAddresses = false);
    }
  }

  double safeParseDouble(String value) {
    return double.tryParse(value) ?? 0.0;
  }

  double get _totalPrice {
    double total = 0;
    for (final item in widget.cartItems) {
      final product = item['product'] ?? {};
      final price = safeParseDouble(product['harga']?.toString() ?? '0');
      final quantity = item['jumlah'] ?? 1;
      total += price * quantity;
    }
    return total;
  }

  double get _grandTotal => _totalPrice + shippingCost;

  Future<void> _processCheckout() async {
    if (selectedAddressId == null) {
      _showError('Mohon pilih alamat pengiriman');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) throw Exception('Token tidak ditemukan');

      // Format items data
      final items = widget.cartItems.map((item) => {
        'product_id': item['product']['id'],
        'jumlah': item['jumlah'],
      }).toList();

      // Data untuk checkout
      final checkoutData = {
        'alamat_id': selectedAddressId,
        'metode_pengiriman': selectedShippingMethod,
        'biaya_kirim': shippingCost,
        'metode_pembayaran': selectedPaymentMethod,
        'items': items,
        if (_notesController.text.isNotEmpty) 'catatan': _notesController.text,
      };

      debugPrint('Sending checkout data: ${json.encode(checkoutData)}');

      final response = await http.post(
        ApiConfig.uri('/api/orders/checkout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(checkoutData),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        
        // Success - show success animation then navigate
        _showSuccessDialog();
      } else {
        // Handle errors
        String errorMessage = 'Checkout gagal';
        
        if (responseData['errors'] != null) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          errorMessage = errors.values
              .expand((e) => e as List)
              .join('\n');
        } else if (responseData['message'] != null) {
          errorMessage = responseData['message'];
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pesanan Berhasil!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pesanan Anda telah berhasil dibuat.\nAnda akan menerima konfirmasi segera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'Inter',
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Kembali ke Beranda'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.pushNamed(context, '/order-history');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Lihat Pesanan'),
          ),
        ],
      ),
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
            // Modern Header dengan Gradient
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
                padding: EdgeInsets.all(isTablet ? 24 : 16),
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
                    
                    // Checkout Icon
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
                    
                    // Title and Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Checkout',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${widget.selectedCount} item dipilih',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontFamily: 'Inter',
                              fontSize: isTablet ? 14 : 12,
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
              child: _isLoadingAddresses
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(isTablet ? 24 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order Summary Card
                              _buildModernCard(
                                'Ringkasan Pesanan',
                                Icons.receipt_outlined,
                                const Color(0xFF1976D2),
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${widget.selectedCount} item dipilih',
                                          style: TextStyle(
                                            fontSize: isTablet ? 16 : 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0D47A1),
                                          ),
                                        ),
                                        Text(
                                          'Rp ${_totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                          style: TextStyle(
                                            fontSize: isTablet ? 16 : 14,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF4CAF50),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    ...widget.cartItems.map((item) {
                                      final product = item['product'] ?? {};
                                      final quantity = item['jumlah'] ?? 1;
                                      final price = safeParseDouble(product['harga']?.toString() ?? '0');
                                      
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                width: isTablet ? 50 : 40,
                                                height: isTablet ? 50 : 40,
                                                color: const Color(0xFFE3F2FD),
                                                child: product['gambar'] != null && product['gambar'].isNotEmpty
                                                    ? Image.network(
                                                        'http://127.0.0.1:8000/storage/${product['gambar'][0]}',
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
                                                    '${product['nama'] ?? 'Produk'} (${quantity}x)',
                                                    style: TextStyle(
                                                      fontSize: isTablet ? 14 : 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF0D47A1),
                                                    ),
                                                  ),
                                                  Text(
                                                    'Rp${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}/kg',
                                                    style: TextStyle(
                                                      fontSize: isTablet ? 12 : 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              'Rp${(price * quantity).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                                              style: TextStyle(
                                                fontSize: isTablet ? 14 : 13,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF4CAF50),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                                isTablet: isTablet,
                              ),

                              const SizedBox(height: 20),

                              // Shipping Address Card
                              _buildAddressCard(isTablet),

                              const SizedBox(height: 20),

                              // Shipping Method Card
                              _buildShippingMethodCard(isTablet),

                              const SizedBox(height: 20),

                              // Payment Method Card
                              _buildPaymentMethodCard(isTablet),

                              const SizedBox(height: 20),

                              // Notes Card
                              _buildModernCard(
                                'Catatan (Opsional)',
                                Icons.note_outlined,
                                const Color(0xFFFF9800),
                                TextField(
                                  controller: _notesController,
                                  maxLines: 3,
                                  style: TextStyle(
                                    fontSize: isTablet ? 16 : 14,
                                    fontFamily: 'Inter',
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Tambahkan catatan untuk penjual...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[500],
                                      fontFamily: 'Inter',
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.withOpacity(0.3),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF1976D2),
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FBFF),
                                  ),
                                ),
                                isTablet: isTablet,
                              ),

                              const SizedBox(height: 20),

                              // Total Summary Card
                              _buildTotalSummaryCard(isTablet),

                              const SizedBox(height: 100), // Space for floating button
                            ],
                          ),
                        ),
                      ),
                    ),
            ),

            // Floating Checkout Button
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 16),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total Pembayaran',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: Colors.grey[600],
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rp ${_grandTotal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                          style: TextStyle(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4CAF50),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    height: isTablet ? 56 : 48,
                    decoration: BoxDecoration(
                      gradient: (_isLoading || addresses.isEmpty || selectedAddressId == null)
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                            ),
                      color: (_isLoading || addresses.isEmpty || selectedAddressId == null) 
                          ? Colors.grey[300] 
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: (_isLoading || addresses.isEmpty || selectedAddressId == null)
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF1976D2).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: (_isLoading || addresses.isEmpty || selectedAddressId == null) 
                            ? null 
                            : _processCheckout,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 24),
                          child: Center(
                            child: _isLoading
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: isTablet ? 20 : 16,
                                        height: isTablet ? 20 : 16,
                                        child: const CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Memproses...',
                                        style: TextStyle(
                                          fontSize: isTablet ? 16 : 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.payment_rounded,
                                        color: (_isLoading || addresses.isEmpty || selectedAddressId == null)
                                            ? Colors.grey[600]
                                            : Colors.white,
                                        size: isTablet ? 24 : 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Proses Checkout',
                                        style: TextStyle(
                                          fontSize: isTablet ? 16 : 14,
                                          fontWeight: FontWeight.bold,
                                          color: (_isLoading || addresses.isEmpty || selectedAddressId == null)
                                              ? Colors.grey[600]
                                              : Colors.white,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCard(String title, IconData icon, Color iconColor, Widget child, {required bool isTablet}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: isTablet ? 24 : 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D47A1),
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(bool isTablet) {
    if (addresses.isEmpty) {
      return _buildModernCard(
        'Alamat Pengiriman',
        Icons.location_on_outlined,
        const Color(0xFFFF5722),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5722).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.location_off,
                    size: isTablet ? 48 : 40,
                    color: const Color(0xFFFF5722),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada alamat tersimpan',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D47A1),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tambahkan alamat untuk melanjutkan checkout',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/address-management').then((_) {
                        fetchAddresses();
                      });
                    },
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Tambah Alamat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        isTablet: isTablet,
      );
    }

    return _buildModernCard(
      'Alamat Pengiriman',
      Icons.location_on_outlined,
      const Color(0xFF4CAF50),
      Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pilih Alamat Pengiriman',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0D47A1),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/address-management').then((_) {
                    fetchAddresses();
                  });
                },
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Kelola'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1976D2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...addresses.map((address) {
            final isSelected = selectedAddressId == address['id'];
            final isMain = address['alamat_utama'] == true;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFF1976D2) 
                      : Colors.grey.withOpacity(0.3),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected 
                    ? const Color(0xFF1976D2).withOpacity(0.05)
                    : Colors.transparent,
              ),
              child: RadioListTile<int>(
                value: address['id'],
                groupValue: selectedAddressId,
                onChanged: (value) {
                  setState(() {
                    selectedAddressId = value;
                  });
                },
                activeColor: const Color(0xFF1976D2),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        address['nama_penerima'] ?? 'Nama Penerima',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 16 : 14,
                          color: const Color(0xFF0D47A1),
                        ),
                      ),
                    ),
                    if (isMain)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Utama',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address['telepon'] ?? '-',
                      style: TextStyle(fontSize: isTablet ? 14 : 12),
                    ),
                    Text(
                      address['alamat_lengkap'] ?? '-',
                      style: TextStyle(fontSize: isTablet ? 14 : 12),
                    ),
                    Text(
                      '${address['kecamatan'] ?? '-'}, ${address['kota'] ?? '-'}, ${address['provinsi'] ?? '-'} ${address['kode_pos'] ?? '-'}',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      isTablet: isTablet,
    );
  }

  Widget _buildShippingMethodCard(bool isTablet) {
    return _buildModernCard(
      'Metode Pengiriman',
      Icons.local_shipping_outlined,
      const Color(0xFF9C27B0),
      Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selectedShippingMethod == 'reguler'
                    ? const Color(0xFF1976D2)
                    : Colors.grey.withOpacity(0.3),
                width: selectedShippingMethod == 'reguler' ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: selectedShippingMethod == 'reguler'
                  ? const Color(0xFF1976D2).withOpacity(0.05)
                  : Colors.transparent,
            ),
            child: RadioListTile<String>(
              title: Row(
                children: [
                  Icon(
                    Icons.local_shipping,
                    color: const Color(0xFF1976D2),
                    size: isTablet ? 24 : 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reguler (2-3 hari)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isTablet ? 16 : 14,
                            color: const Color(0xFF0D47A1),
                          ),
                        ),
                        Text(
                          'Pengiriman standar dengan harga terjangkau',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                'Rp 10.000',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4CAF50),
                ),
              ),
              value: 'reguler',
              groupValue: selectedShippingMethod,
              onChanged: (value) {
                setState(() {
                  selectedShippingMethod = value!;
                  shippingCost = 10000;
                });
              },
              activeColor: const Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selectedShippingMethod == 'express'
                    ? const Color(0xFF1976D2)
                    : Colors.grey.withOpacity(0.3),
                width: selectedShippingMethod == 'express' ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: selectedShippingMethod == 'express'
                  ? const Color(0xFF1976D2).withOpacity(0.05)
                  : Colors.transparent,
            ),
            child: RadioListTile<String>(
              title: Row(
                children: [
                  Icon(
                    Icons.flash_on,
                    color: const Color(0xFFFF5722),
                    size: isTablet ? 24 : 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Express (1 hari)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isTablet ? 16 : 14,
                            color: const Color(0xFF0D47A1),
                          ),
                        ),
                        Text(
                          'Pengiriman cepat untuk kebutuhan mendesak',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                'Rp 20.000',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4CAF50),
                ),
              ),
              value: 'express',
              groupValue: selectedShippingMethod,
              onChanged: (value) {
                setState(() {
                  selectedShippingMethod = value!;
                  shippingCost = 20000;
                });
              },
              activeColor: const Color(0xFF1976D2),
            ),
          ),
        ],
      ),
      isTablet: isTablet,
    );
  }

  Widget _buildPaymentMethodCard(bool isTablet) {
    return _buildModernCard(
      'Metode Pembayaran',
      Icons.payment_outlined,
      const Color(0xFF2E7D32),
      Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selectedPaymentMethod == 'cod'
                    ? const Color(0xFF1976D2)
                    : Colors.grey.withOpacity(0.3),
                width: selectedPaymentMethod == 'cod' ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: selectedPaymentMethod == 'cod'
                  ? const Color(0xFF1976D2).withOpacity(0.05)
                  : Colors.transparent,
            ),
            child: RadioListTile<String>(
              title: Row(
                children: [
                  Icon(
                    Icons.money,
                    color: const Color(0xFF4CAF50),
                    size: isTablet ? 24 : 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash on Delivery (COD)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isTablet ? 16 : 14,
                            color: const Color(0xFF0D47A1),
                          ),
                        ),
                        Text(
                          'Bayar saat barang diterima',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              value: 'cod',
              groupValue: selectedPaymentMethod,
              onChanged: (value) {
                setState(() => selectedPaymentMethod = value!);
              },
              activeColor: const Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selectedPaymentMethod == 'transfer'
                    ? const Color(0xFF1976D2)
                    : Colors.grey.withOpacity(0.3),
                width: selectedPaymentMethod == 'transfer' ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: selectedPaymentMethod == 'transfer'
                  ? const Color(0xFF1976D2).withOpacity(0.05)
                  : Colors.transparent,
            ),
            child: RadioListTile<String>(
              title: Row(
                children: [
                  Icon(
                    Icons.account_balance,
                    color: const Color(0xFF1976D2),
                    size: isTablet ? 24 : 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transfer Bank',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isTablet ? 16 : 14,
                            color: const Color(0xFF0D47A1),
                          ),
                        ),
                        Text(
                          'Transfer ke rekening toko',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              value: 'transfer',
              groupValue: selectedPaymentMethod,
              onChanged: (value) {
                setState(() => selectedPaymentMethod = value!);
              },
              activeColor: const Color(0xFF1976D2),
            ),
          ),
        ],
      ),
      isTablet: isTablet,
    );
  }

  Widget _buildTotalSummaryCard(bool isTablet) {
    return Container(
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
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: const Color(0xFF2E7D32),
                    size: isTablet ? 24 : 20,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Ringkasan Pembayaran',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E7D32),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildPriceRow(
              'Subtotal',
              'Rp ${_totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
              isTablet,
            ),
            const SizedBox(height: 12),
            _buildPriceRow(
              'Ongkir ($selectedShippingMethod)',
              'Rp ${shippingCost.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
              isTablet,
            ),
            const Divider(height: 24, thickness: 2),
            _buildPriceRow(
              'Total',
              'Rp ${_grandTotal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
              isTablet,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, bool isTablet, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? (isTablet ? 18 : 16) : (isTablet ? 16 : 14),
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? const Color(0xFF2E7D32) : const Color(0xFF0D47A1),
            fontFamily: 'Inter',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? (isTablet ? 18 : 16) : (isTablet ? 16 : 14),
            fontWeight: FontWeight.bold,
            color: isTotal ? const Color(0xFF2E7D32) : const Color(0xFF4CAF50),
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}