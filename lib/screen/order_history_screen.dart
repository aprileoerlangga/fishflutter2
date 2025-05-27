import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fishflutter/screen/utils/api_config.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  OrderHistoryScreenState createState() => OrderHistoryScreenState();
}

class OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<dynamic> orders = [];
  bool _isLoading = true;
  int currentPage = 1;
  bool hasMoreData = true;
  String? selectedStatus;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    fetchOrders();
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
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showCancelConfirmation(int orderId, String orderNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: Text('Apakah Anda yakin ingin membatalkan pesanan $orderNumber?'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Status'),
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
      ),
    );
  }

  Widget _buildFilterOption(String label, String? value) {
    return RadioListTile<String?>(
      title: Text(label),
      value: value,
      groupValue: selectedStatus,
      onChanged: (newValue) {
        setState(() {
          selectedStatus = newValue;
        });
        Navigator.pop(context);
        fetchOrders(isRefresh: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Riwayat Pesanan',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter indicator
          if (selectedStatus != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              // Fix deprecated opacity
              color: const Color(0xFF88D8E9).withAlpha(25), // Changed from withOpacity(0.1)
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Color(0xFF88D8E9)),
                  const SizedBox(width: 8),
                  Text('Filter: ${_getStatusLabel(selectedStatus!)}'),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedStatus = null;
                      });
                      fetchOrders(isRefresh: true);
                    },
                    child: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: _isLoading && orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => fetchOrders(isRefresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: orders.length + (hasMoreData ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == orders.length) {
                              // Load more
                              if (!_isLoadingMore && hasMoreData) {
                                fetchOrders();
                              }
                              return _isLoadingMore
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            }
                            
                            final order = orders[index];
                            return OrderCard(
                              order: order,
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
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            selectedStatus != null 
                ? 'Belum ada pesanan dengan status ${_getStatusLabel(selectedStatus!)}'
                : 'Belum ada pesanan',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Mulai berbelanja untuk melihat riwayat pesanan',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/fish-market',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF88D8E9),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Mulai Belanja',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
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

class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onCancel;
  final VoidCallback onViewDetail;

  const OrderCard({
    super.key,
    required this.order,
    required this.onCancel,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'menunggu';
    final statusLabel = order['status_label'] ?? _getStatusText(status);
    final canCancel = status == 'menunggu' || status == 'diproses';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order['nomor_pesanan'] ?? 'Pesanan',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Order Info
            Text('Total: ${order['total_formatted'] ?? 'Rp ${order['total'] ?? 0}'}'),
            Text('Tanggal: ${_formatDate(order['tanggal_pesan'])}'),
            if (order['metode_pembayaran'] != null)
              Text('Pembayaran: ${order['metode_pembayaran']}'),
            
            // Items preview
            if (order['items_preview'] != null && order['items_preview'].isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Item:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              ...order['items_preview'].map<Widget>((item) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text(
                    '• ${item['nama_produk'] ?? 'Produk'} (${item['jumlah'] ?? 0}x)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              }),
              if (order['has_more_items'] == true)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: Text(
                    '• dan lainnya...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ] else if (order['items_count'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Total ${order['items_count']} item',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onViewDetail,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF88D8E9)),
                    ),
                    child: const Text(
                      'Lihat Detail',
                      style: TextStyle(color: Color(0xFF88D8E9)),
                    ),
                  ),
                ),
                if (canCancel) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text(
                        'Batalkan',
                        style: TextStyle(color: Colors.red),
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

// OrderDetailScreen - untuk melihat detail lengkap pesanan
class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  OrderDetailScreenState createState() => OrderDetailScreenState();
}

class OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? orderDetail;
  List<dynamic> orderItems = [];
  bool _isLoading = true;

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
      
      // Fetch order detail
      final response = await http.get(
        ApiConfig.uri('/api/orders/${widget.orderId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            orderDetail = data['data'];
          });
          
          // Fetch order items
          fetchOrderItems();
        } else {
          setState(() => _isLoading = false);
          if (mounted) {
            _showError(data['message'] ?? 'Gagal mengambil detail pesanan');
          }
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          _showError('Gagal mengambil detail pesanan');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showError('Terjadi kesalahan: $e');
      }
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
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
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

  // Add this method
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
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
                              _buildInfoRow('Status', orderDetail!['status_label'] ?? orderDetail!['status'] ?? '-'),
                              _buildInfoRow('Pembayaran', orderDetail!['metode_pembayaran'] ?? '-'),
                              _buildInfoRow('Pengiriman', orderDetail!['metode_pengiriman'] ?? '-'),
                              if (orderDetail!['catatan'] != null && orderDetail!['catatan'].toString().isNotEmpty)
                                _buildInfoRow('Catatan', orderDetail!['catatan']),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Address Info
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
                                Text(
                                  orderDetail!['address']['nama_penerima'] ?? '-',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(orderDetail!['address']['telepon'] ?? '-'),
                                Text(orderDetail!['address']['alamat_lengkap'] ?? '-'),
                                Text(
                                  '${orderDetail!['address']['kecamatan'] ?? '-'}, '
                                  '${orderDetail!['address']['kota'] ?? '-'}',
                                ),
                                Text(
                                  '${orderDetail!['address']['provinsi'] ?? '-'} '
                                  '${orderDetail!['address']['kode_pos'] ?? '-'}',
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Items Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Daftar Produk',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...orderItems.map((item) => _buildProductItem(item)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item['product']?['gambar'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item['product']['gambar'],
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product']?['nama'] ?? 'Produk',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${item['jumlah']}x @ Rp${_formatPrice(item['harga'])}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Subtotal: Rp${_formatPrice(item['subtotal'])}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    return price.toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.');
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
      case 'dibayar':
        return Icons.payment;
      case 'diproses':
        return Icons.local_shipping;
      case 'dikirim':
        return Icons.local_shipping;
      case 'selesai':
        return Icons.check_circle;
      case 'dibatalkan':
        return Icons.cancel;
      default:
        return Icons.watch_later;
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) return '-';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
    } catch (e) {
      return '-';
    }
  }
}