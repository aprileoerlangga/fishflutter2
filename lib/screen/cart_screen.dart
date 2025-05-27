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

class _CartScreenState extends State<CartScreen> {
  List<dynamic> cartItems = [];
  List<bool> _selectedItems = [];
  List<int> _quantities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCartItems();
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
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to fetch cart data')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update quantity: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() {
        _quantities[index] = cartItems[index]['jumlah'] ?? 1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating quantity: $e')),
        );
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
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove item: ${response.body}')),
      );
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
    return 'Rp ${_totalPrice.toStringAsFixed(0)}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  CartHeader(
                    itemCount: cartItems.length,
                    totalPrice: _formattedTotalPrice,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: cartItems.isEmpty
                          ? const Center(child: Text('Keranjang kosong'))
                          : ListView.separated(
                              itemCount: cartItems.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 24),
                              itemBuilder: (context, index) {
                                final item = cartItems[index];
                                final product = item['product'] ?? {};
                                final imageUrl = 'http://127.0.0.1:8000/storage/${product['gambar'][0]}';

                                int currentQuantity;
                                if (_quantities.isNotEmpty && index < _quantities.length) {
                                  currentQuantity = _quantities[index];
                                } else {
                                  final itemQty = item['jumlah'] ?? item['quantity'] ?? 1;
                                  currentQuantity = itemQty is int 
                                      ? itemQty 
                                      : int.tryParse(itemQty.toString()) ?? 1;
                                }

                                return CartItem(
                                  isSelected: _selectedItems.isNotEmpty && index < _selectedItems.length
                                      ? _selectedItems[index]
                                      : false,
                                  onSelectionChanged: () => _toggleSelection(index),
                                  quantity: currentQuantity,
                                  onQuantityChanged: (qty) => _updateCartItem(index, qty),
                                  category: product['jenis_ikan'] ?? '-',
                                  name: product['nama'] ?? 'Produk',
                                  price: double.tryParse(product['harga']?.toString() ?? '0') ?? 0,
                                  onDelete: () => _removeCartItem(index),
                                  imageUrl: imageUrl, 
                                );
                              },
                            ),
                    ),
                  ),
                  CartFooter(
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
                  ),
                ],
              ),
      ),
    );
  }
}

class CartHeader extends StatelessWidget {
  final int itemCount;
  final String totalPrice;

  const CartHeader({super.key, required this.itemCount, required this.totalPrice});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      color: const Color(0xFF88D8E9),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 8),
          Text(
            'Keranjang ($itemCount) - $totalPrice',
            style: const TextStyle(
              color: Color(0xFF101010),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class CartItem extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onSelectionChanged;
  final int quantity;
  final Function(int) onQuantityChanged;
  final String category;
  final String name;
  final double price;
  final VoidCallback onDelete;
  final String imageUrl;

  const CartItem({
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
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: isSelected,
          onChanged: (_) => onSelectionChanged(),
        ),
        const SizedBox(width: 16),
        Image.network(
          imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 50,
            height: 50,
            color: Colors.grey[300],
            child: const Icon(Icons.image),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Rp${price.toStringAsFixed(0)}/kg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: quantity > 1 ? () => onQuantityChanged(quantity - 1) : null,
                  ),
                  Text(quantity.toString(), style: const TextStyle(fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => onQuantityChanged(quantity + 1),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class CartFooter extends StatelessWidget {
  final bool isAllSelected;
  final VoidCallback onSelectAll;
  final String totalPrice;
  final int selectedCount;
  final VoidCallback onCheckout;

  const CartFooter({
    super.key,
    required this.isAllSelected,
    required this.onSelectAll,
    required this.totalPrice,
    required this.selectedCount,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey)),
        color: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Checkbox(
                value: isAllSelected,
                onChanged: (_) => onSelectAll(),
              ),
              const Text('Semua'),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Total'),
              Text(totalPrice),
            ],
          ),
          ElevatedButton(
            onPressed: selectedCount == 0 ? null : onCheckout,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF88D8E9),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text('Checkout ($selectedCount)'),
          ),
        ],
      ),
    );
  }
}