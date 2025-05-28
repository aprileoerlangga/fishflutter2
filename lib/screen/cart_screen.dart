import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fishflutter/screen/utils/api_config.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  List<dynamic> cartItems = [];
  List<bool> _selectedItems = [];
  List<int> _quantities = [];
  bool _isLoading = true;

  late AnimationController _animationController;
  late AnimationController _fabController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    fetchCartItems();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> fetchCartItems() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await http.get(
        ApiConfig.uri('/api/cart'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['data']?['items'] ?? [];
        setState(() {
          cartItems = items;
          _selectedItems = List.generate(items.length, (i) => true);
          _quantities = items.map<int>((item) {
            final quantity = item['quantity'] ?? item['jumlah'] ?? 1;
            return quantity is int ? quantity : int.tryParse(quantity.toString()) ?? 1;
          }).toList();
          _isLoading = false;
        });
        
        _animationController.forward();
        Future.delayed(const Duration(milliseconds: 500), () {
          _fabController.forward();
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          _showErrorSnackBar('Gagal mengambil data keranjang');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      _selectedItems[index] = !_selectedItems[index];
    });
  }

  Future<void> _updateCartItem(int index, int newQuantity) async {
    if (newQuantity < 1) return;

    setState(() {
      _quantities[index] = newQuantity;
      cartItems[index]['jumlah'] = newQuantity;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final item = cartItems[index];
      final cartItemId = item['id'];

      final url = ApiConfig.uri('/api/cart/$cartItemId');
      final body = {'jumlah': newQuantity.toString()};

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode != 200 && mounted) {
        setState(() {
          _quantities[index] = cartItems[index]['jumlah'] ?? 1;
        });
        _showErrorSnackBar('Gagal mengupdate jumlah: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _quantities[index] = cartItems[index]['jumlah'] ?? 1;
      });
      if (mounted) {
        _showErrorSnackBar('Error mengupdate jumlah: $e');
      }
    }
  }

  Future<void> _removeCartItem(int index) async {
    if (index < 0 || index >= cartItems.length) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final item = cartItems[index];
    final cartItemId = item['id'];

    final url = ApiConfig.uri('/api/cart/$cartItemId');

    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    
    if (response.statusCode == 200) {
      setState(() {
        cartItems.removeAt(index);
        if (index < _selectedItems.length) _selectedItems.removeAt(index);
        if (index < _quantities.length) _quantities.removeAt(index);
      });
      _showSuccessSnackBar('Item berhasil dihapus dari keranjang');
    } else if (mounted) {
      _showErrorSnackBar('Gagal menghapus item: ${response.body}');
    }
  }

  double get _totalPrice {
    double total = 0;
    for (int i = 0; i < cartItems.length; i++) {
      if (_selectedItems.isNotEmpty && i < _selectedItems.length && _selectedItems[i]) {
        final item = cartItems[i];
        final product = item['product'] ?? {};
        final price = double.tryParse(product['harga']?.toString() ?? '0') ?? 0;
        final qty = _quantities.isNotEmpty && i < _quantities.length 
            ? _quantities[i] 
            : (item['jumlah'] is int 
                ? item['jumlah'] 
                : int.tryParse(item['jumlah']?.toString() ?? '1') ?? 1);
        total += price * qty;
      }
    }
    return total;
  }

  String get _formattedTotalPrice {
    return 'Rp ${_totalPrice.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  int get _selectedCount =>
      _selectedItems.where((item) => item).length;

  List<dynamic> get _selectedCartItems {
    List<dynamic> selected = [];
    for (int i = 0; i < cartItems.length; i++) {
      if (i < _selectedItems.length && _selectedItems[i]) {
        selected.add(cartItems[i]);
      }
    }
    return selected;
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

  void _showSuccessSnackBar(String message) {
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
                    
                    // Cart Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.shopping_cart,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Title and Item Count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keranjang Belanja',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${cartItems.length} item - $_formattedTotalPrice',
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
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                      ),
                    )
                  : cartItems.isEmpty
                      ? _buildEmptyState(isTablet)
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: cartItems.length,
                                    itemBuilder: (context, index) {
                                      final item = cartItems[index];
                                      final product = item['product'] ?? {};
                                      final String imageUrl = ApiConfig.imageUrl(product['gambar'][0]);

                                      int currentQuantity;
                                      if (_quantities.isNotEmpty && index < _quantities.length) {
                                        currentQuantity = _quantities[index];
                                      } else {
                                        final itemQty = item['jumlah'] ?? item['quantity'] ?? 1;
                                        currentQuantity = itemQty is int 
                                            ? itemQty 
                                            : int.tryParse(itemQty.toString()) ?? 1;
                                      }

                                      return ModernCartItem(
                                        isSelected: _selectedItems.isNotEmpty && index < _selectedItems.length
                                            ? _selectedItems[index]
                                            : false,
                                        onSelectionChanged: () => _toggleSelection(index),
                                        quantity: currentQuantity,
                                        onQuantityChanged: (qty) => _updateCartItem(index, qty),
                                        category: product['jenis_ikan'] ?? '-',
                                        name: product['nama'] ?? 'Produk',
                                        price: double.tryParse(product['harga']?.toString() ?? '0') ?? 0,
                                        onDelete: () => _showDeleteConfirmation(index),
                                        imageUrl: imageUrl,
                                        isTablet: isTablet,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
            ),

            // Modern Footer
            if (cartItems.isNotEmpty)
              ScaleTransition(
                scale: _fabAnimation,
                child: ModernCartFooter(
                  isAllSelected: _selectedItems.isNotEmpty && _selectedItems.every((item) => item),
                  onSelectAll: () {
                    setState(() {
                      final newValue = !_selectedItems.every((item) => item);
                      for (var i = 0; i < _selectedItems.length; i++) {
                        _selectedItems[i] = newValue;
                      }
                    });
                  },
                  totalPrice: _formattedTotalPrice,
                  selectedCount: _selectedCount,
                  onCheckout: () {
                    if (_selectedCount > 0) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CheckoutScreen(
                            totalPrice: _formattedTotalPrice,
                            selectedCount: _selectedCount,
                            cartItems: _selectedCartItems,
                          ),
                        ),
                      );
                    }
                  },
                  isTablet: isTablet,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isTablet) {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: isTablet ? 80 : 64,
                color: const Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Keranjang Kosong',
              style: TextStyle(
                fontSize: isTablet ? 20 : 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D47A1),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada produk di keranjang Anda.\nMulai berbelanja sekarang!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey[600],
                fontFamily: 'Inter',
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Mulai Belanja'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 8,
                shadowColor: const Color(0xFF1976D2).withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int index) {
    final item = cartItems[index];
    final product = item['product'] ?? {};
    final productName = product['nama'] ?? 'Produk';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFD32F2F)),
            SizedBox(width: 8),
            Text('Hapus Item'),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus "$productName" dari keranjang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeCartItem(index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class ModernCartItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onSelectionChanged;
  final int quantity;
  final Function(int) onQuantityChanged;
  final String category;
  final String name;
  final double price;
  final VoidCallback onDelete;
  final String imageUrl;
  final bool isTablet;

  const ModernCartItem({
    super.key,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.quantity,
    required this.onQuantityChanged,
    required this.category,
    required this.name,
    required this.price,
    required this.onDelete,
    required this.imageUrl,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected 
              ? const Color(0xFF1976D2).withOpacity(0.3) 
              : Colors.grey.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected 
                ? const Color(0xFF1976D2).withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Row(
          children: [
            // Checkbox
            Container(
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF1976D2) 
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFF1976D2)
                      : Colors.grey.withOpacity(0.4),
                ),
              ),
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => onSelectionChanged(),
                activeColor: Colors.transparent,
                checkColor: Colors.white,
                side: BorderSide.none,
              ),
            ),

            const SizedBox(width: 16),

            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: isTablet ? 80 : 60,
                height: isTablet ? 80 : 60,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFE3F2FD),
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: const Color(0xFF1976D2),
                      size: isTablet ? 32 : 24,
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10,
                        color: const Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D47A1),
                      fontFamily: 'Inter',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}/kg',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: const Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Quantity Controls
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F8FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF1976D2).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF1976D2),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                              ),
                              child: IconButton(
                                constraints: BoxConstraints(
                                  minWidth: isTablet ? 40 : 32,
                                  minHeight: isTablet ? 40 : 32,
                                ),
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                  size: isTablet ? 20 : 16,
                                ),
                                onPressed: quantity > 1
                                    ? () => onQuantityChanged(quantity - 1)
                                    : null,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 16 : 12,
                                vertical: isTablet ? 12 : 8,
                              ),
                              child: Text(
                                '$quantity',
                                style: TextStyle(
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0D47A1),
                                ),
                              ),
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF1976D2),
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              child: IconButton(
                                constraints: BoxConstraints(
                                  minWidth: isTablet ? 40 : 32,
                                  minHeight: isTablet ? 40 : 32,
                                ),
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: isTablet ? 20 : 16,
                                ),
                                onPressed: () => onQuantityChanged(quantity + 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: const Color(0xFFD32F2F),
                            size: isTablet ? 24 : 20,
                          ),
                          onPressed: onDelete,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModernCartFooter extends StatelessWidget {
  final bool isAllSelected;
  final VoidCallback onSelectAll;
  final String totalPrice;
  final int selectedCount;
  final VoidCallback onCheckout;
  final bool isTablet;

  const ModernCartFooter({
    super.key,
    required this.isAllSelected,
    required this.onSelectAll,
    required this.totalPrice,
    required this.selectedCount,
    required this.onCheckout,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Select All
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1976D2).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isAllSelected 
                        ? const Color(0xFF1976D2) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isAllSelected 
                          ? const Color(0xFF1976D2)
                          : Colors.grey.withOpacity(0.4),
                    ),
                  ),
                  child: Checkbox(
                    value: isAllSelected,
                    onChanged: (_) => onSelectAll(),
                    activeColor: Colors.transparent,
                    checkColor: Colors.white,
                    side: BorderSide.none,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Pilih Semua',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D47A1),
                    fontFamily: 'Inter',
                  ),
                ),
                const Spacer(),
                Text(
                  '$selectedCount item dipilih',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    color: const Color(0xFF1976D2),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Total and Checkout
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      totalPrice,
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
              Expanded(
                flex: 3,
                child: Container(
                  height: isTablet ? 56 : 48,
                  decoration: BoxDecoration(
                    gradient: selectedCount == 0
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                          ),
                    color: selectedCount == 0 ? Colors.grey[300] : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: selectedCount == 0
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
                      onTap: selectedCount == 0 ? null : onCheckout,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              color: selectedCount == 0 
                                  ? Colors.grey[600] 
                                  : Colors.white,
                              size: isTablet ? 24 : 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Checkout ($selectedCount)',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                                color: selectedCount == 0 
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
        ],
      ),
    );
  }
}