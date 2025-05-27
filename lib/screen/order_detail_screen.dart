// File: lib/screen/order_detail_screen.dart
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

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? orderDetail;
  List<dynamic> orderItems = [];
  bool _isLoading = true;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    fetchOrderDetail();
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
        if (data['success'] == true) {
          setState(() {
            orderDetail = data['data'];
            _isLoading = false;
          });
          
          // Fetch order items separately
          fetchOrderItems();
        } else {
          setState(() => _isLoading = false);
          _showError(data['message'] ?? 'Gagal mengambil detail pesanan');
        }
      } else {
        setState(() => _isLoading = false);
        _showError('Gagal mengambil detail pesanan');
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
      
      final response = await http.get(
        ApiConfig.uri('/api/orders/${widget.orderId}/items'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            orderItems = data['data'] ?? [];
          });
        }
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Pesanan berhasil dibatalkan'),
              backgroundColor: Colors.green,
            ),
          );
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

  Future<void> completeOrder() async {
    setState(() => _isActionLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.post(
        ApiConfig.uri('/api/orders/${widget.orderId}/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      setState(() => _isActionLoading = false);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Pesanan berhasil diselesaikan'),
              backgroundColor: Colors.green,
            ),
          );
          fetchOrderDetail(); // Refresh
        } else {
          _showError(data['message'] ?? 'Gagal menyelesaikan pesanan');
        }
      } else {
        final data = json.decode(response.body);
        _showError(data['message'] ?? 'Gagal menyelesaikan pesanan');
      }
    } catch (e) {
      setState(() => _isActionLoading = false);
      _showError('Terjadi kesalahan: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selesaikan Pesanan'),
        content: Text(
          'Apakah Anda yakin telah menerima pesanan ${orderDetail?['nomor_pesanan'] ?? ''}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Belum'),
          ),
          ElevatedButton(
            onPressed: _isActionLoading 
                ? null 
                : () {
                    Navigator.pop(context);
                    completeOrder();
                  },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              'Ya, Sudah Diterima',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Detail ${orderDetail?['nomor_pesanan'] ?? 'Pesanan'}',
          style: const TextStyle(
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : orderDetail == null
              ? const Center(child: Text('Detail pesanan tidak ditemukan'))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Order Status Card
                            Card(
                              color: _getStatusCardColor(orderDetail!['status']),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getStatusIcon(orderDetail!['status']),
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            orderDetail!['status_label'] ?? orderDetail!['status'] ?? '-',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Pesanan ${orderDetail!['nomor_pesanan'] ?? ''}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Order Info
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Informasi Pesanan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow('Nomor Pesanan', orderDetail!['nomor_pesanan'] ?? '-'),
                                    _buildInfoRow('Tanggal', _formatDateTime(orderDetail!['tanggal_pesan'])),
                                    _buildInfoRow('Status Pembayaran', orderDetail!['status_pembayaran_label'] ?? orderDetail!['status_pembayaran'] ?? '-'),
                                    _buildInfoRow('Metode Pembayaran', orderDetail!['metode_pembayaran_label'] ?? orderDetail!['metode_pembayaran'] ?? '-'),
                                    _buildInfoRow('Metode Pengiriman', orderDetail!['metode_pengiriman'] ?? '-'),
                                    if (orderDetail!['catatan'] != null && orderDetail!['catatan'].toString().isNotEmpty)
                                      _buildInfoRow('Catatan', orderDetail!['catatan']),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Shipping Address
                            if (orderDetail!['address'] != null)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Alamat Pengiriman',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildAddressInfo(orderDetail!['address']),
                                    ],
                                  ),
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Order Items
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Item Pesanan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (orderItems.isNotEmpty)
                                      ...orderItems.map<Widget>((item) => _buildOrderItem(item)).toList()
                                    else if (orderDetail!['items'] != null && orderDetail!['items'].isNotEmpty)
                                      ...orderDetail!['items'].map<Widget>((item) => _buildOrderItem(item)).toList()
                                    else
                                      const Text('Tidak ada item'),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Price Summary
                            Card(
                              color: const Color(0xFFF8F9FA),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _buildPriceRow('Subtotal', orderDetail!['subtotal_formatted'] ?? 'Rp ${orderDetail!['subtotal'] ?? 0}'),
                                    _buildPriceRow('Ongkir', orderDetail!['biaya_kirim_formatted'] ?? 'Rp ${orderDetail!['biaya_kirim'] ?? 0}'),
                                    if (orderDetail!['pajak'] != null && orderDetail!['pajak'] > 0)
                                      _buildPriceRow('Pajak', orderDetail!['pajak_formatted'] ?? 'Rp ${orderDetail!['pajak'] ?? 0}'),
                                    const Divider(),
                                    _buildPriceRow(
                                      'Total',
                                      orderDetail!['total_formatted'] ?? 'Rp ${orderDetail!['total'] ?? 0}',
                                      isTotal: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 80), // Space for bottom actions
                          ],
                        ),
                      ),
                    ),

                    // Bottom Action Buttons
                    if (_showActionButtons())
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            if (_canCancel())
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isActionLoading ? null : _showCancelConfirmation,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: _isActionLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                          ),
                                        )
                                      : const Text(
                                          'Batalkan Pesanan',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                ),
                              ),
                            // Info button untuk status pesanan
                            if (!_canCancel())
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Status Pesanan'),
                                        content: Text(_getStatusInfo(orderDetail!['status'])),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF88D8E9)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text(
                                    'Info Status',
                                    style: TextStyle(color: Color(0xFF88D8E9)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressInfo(Map<String, dynamic> address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          address['nama_penerima'] ?? '-',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(address['telepon'] ?? '-'),
        const SizedBox(height: 4),
        Text(address['alamat_lengkap'] ?? '-'),
        const SizedBox(height: 4),
        Text(
          '${address['kecamatan'] ?? '-'}, ${address['kota'] ?? '-'}, ${address['provinsi'] ?? '-'} ${address['kode_pos'] ?? '-'}',
        ),
      ],
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final product = item['product'] ?? item['produk'] ?? {};
    String imageUrl = '';
    
    if (product['gambar'] != null && product['gambar'].isNotEmpty) {
      if (product['gambar'] is List && product['gambar'].isNotEmpty) {
        imageUrl = ApiConfig.imageUrl(product['gambar'][0]);
      } else if (product['gambar'] is String) {
        imageUrl = ApiConfig.imageUrl(product['gambar']);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image),
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Harga: ${item['harga_formatted'] ?? 'Rp ${item['harga'] ?? 0}'}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Jumlah: ${item['jumlah'] ?? 0}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item['subtotal_formatted'] ?? 'Rp ${item['subtotal'] ?? 0}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
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
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusCardColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'dibayar':
        return Colors.blue;
      case 'diproses':
        return Colors.orange;
      case 'dikirim':
        return Colors.purple;
      case 'selesai':
        return Colors.green;
      case 'dibatalkan':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'menunggu':
        return Icons.pending;
      case 'dibayar':
        return Icons.payment;
      case 'diproses':
        return Icons.build;
      case 'dikirim':
        return Icons.local_shipping;
      case 'selesai':
        return Icons.check_circle;
      case 'dibatalkan':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  bool _showActionButtons() {
    // Selalu tampilkan button, entah untuk cancel atau info
    return true;
  }

  bool _canCancel() {
    final status = orderDetail?['status'];
    return status == 'menunggu' || status == 'diproses';
  }

  bool _canComplete() {
    // Tidak ada endpoint complete, jadi return false
    return false;
  }

  String _getStatusInfo(String? status) {
    switch (status?.toLowerCase()) {
      case 'menunggu':
        return 'Pesanan Anda sedang menunggu konfirmasi dari penjual. Anda masih bisa membatalkan pesanan.';
      case 'dibayar':
        return 'Pembayaran Anda telah diterima. Pesanan akan segera diproses oleh penjual.';
      case 'diproses':
        return 'Pesanan Anda sedang diproses oleh penjual. Anda masih bisa membatalkan pesanan.';
      case 'dikirim':
        return 'Pesanan Anda sudah dikirim. Silakan tunggu hingga pesanan tiba di alamat Anda.';
      case 'selesai':
        return 'Pesanan Anda telah selesai. Terima kasih telah berbelanja!';
      case 'dibatalkan':
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
      return '-';
    }
  }
}