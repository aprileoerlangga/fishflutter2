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

class CheckoutScreenState extends State<CheckoutScreen> {
  List<dynamic> addresses = [];
  int? selectedAddressId;
  String selectedShippingMethod = 'reguler';
  String selectedPaymentMethod = 'cod';
  double shippingCost = 10000;
  bool _isLoading = false;
  bool _isLoadingAddresses = true;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAddresses();
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

  // Update the processCheckout method:
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
        
        // Success - clear cart and navigate
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil dibuat!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to home and orders screen
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.pushNamed(context, '/orders');
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
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Checkout",
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color(0xFF88D8E9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingAddresses
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rincian Pesanan
                  _buildSectionTitle('Rincian Pesanan'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${widget.selectedCount} item dipilih'),
                              Text(
                                'Rp ${_totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(),
                          ...widget.cartItems.map((item) {
                            final product = item['product'] ?? {};
                            final quantity = item['jumlah'] ?? 1;
                            final price = safeParseDouble(product['harga']?.toString() ?? '0');
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${product['nama'] ?? 'Produk'} (${quantity}x)',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    'Rp${(price * quantity).toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Alamat Pengiriman
                  _buildSectionTitle('Alamat Pengiriman'),
                  const SizedBox(height: 12),
                  
                  if (addresses.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(Icons.location_off, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text(
                              'Belum ada alamat tersimpan',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tambahkan alamat untuk melanjutkan checkout',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/addresses').then((_) {
                                  fetchAddresses();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF88D8E9),
                              ),
                              child: const Text(
                                'Tambah Alamat',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Pilih Alamat Pengiriman',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/addresses').then((_) {
                                      fetchAddresses();
                                    });
                                  },
                                  child: const Text(
                                    'Kelola',
                                    style: TextStyle(color: Color(0xFF88D8E9)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...addresses.map((address) {
                              final isSelected = selectedAddressId == address['id'];
                              final isMain = address['alamat_utama'] == true;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF88D8E9) : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: RadioListTile<int>(
                                  value: address['id'],
                                  groupValue: selectedAddressId,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedAddressId = value;
                                    });
                                  },
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          address['nama_penerima'] ?? 'Nama Penerima',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (isMain)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Utama',
                                            style: TextStyle(color: Colors.white, fontSize: 10),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(address['telepon'] ?? '-'),
                                      Text(address['alamat_lengkap'] ?? '-'),
                                      Text(
                                        '${address['kecamatan'] ?? '-'}, '
                                        '${address['kota'] ?? '-'}, '
                                        '${address['provinsi'] ?? '-'} '
                                        '${address['kode_pos'] ?? '-'}',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Metode Pengiriman
                  _buildSectionTitle('Metode Pengiriman'),
                  const SizedBox(height: 12),
                  _buildShippingMethod(),

                  const SizedBox(height: 24),

                  // Metode Pembayaran
                  _buildSectionTitle('Metode Pembayaran'),
                  const SizedBox(height: 12),
                  _buildPaymentMethod(),

                  const SizedBox(height: 24),

                  // Catatan
                  _buildSectionTitle('Catatan (Opsional)'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          hintText: 'Tambahkan catatan untuk penjual...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Total
                  _buildTotalSummary(),

                  const SizedBox(height: 32),

                  // Tombol Checkout
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isLoading || addresses.isEmpty || selectedAddressId == null) 
                          ? null 
                          : _processCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF88D8E9),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Memproses...'),
                              ],
                            )
                          : const Text(
                              'Proses Checkout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      ),
    );
  }

  Widget _buildPaymentMethod() {
    return Card(
      child: Column(
        children: [
          RadioListTile<String>(
            title: const Text('Cash on Delivery (COD)'),
            subtitle: const Text('Bayar saat barang diterima'),
            value: 'cod',
            groupValue: selectedPaymentMethod,
            onChanged: (value) {
              setState(() => selectedPaymentMethod = value!);
            },
          ),
          RadioListTile<String>(
            title: const Text('Transfer Bank'),
            subtitle: const Text('Transfer ke rekening toko'),
            value: 'transfer',
            groupValue: selectedPaymentMethod,
            onChanged: (value) {
              setState(() => selectedPaymentMethod = value!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShippingMethod() {
    return Card(
      child: Column(
        children: [
          RadioListTile<String>(
            title: const Text('Reguler (2-3 hari)'),
            subtitle: const Text('Rp 10.000'),
            value: 'reguler',
            groupValue: selectedShippingMethod,
            onChanged: (value) {
              setState(() {
                selectedShippingMethod = value!;
                shippingCost = 10000;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('Express (1 hari)'),
            subtitle: const Text('Rp 20.000'),
            value: 'express',
            groupValue: selectedShippingMethod,
            onChanged: (value) {
              setState(() {
                selectedShippingMethod = value!;
                shippingCost = 20000;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text('Rp ${_totalPrice.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ongkir ($selectedShippingMethod)'),
                Text('Rp ${shippingCost.toStringAsFixed(0)}'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Rp ${_grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
