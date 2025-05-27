import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fishflutter/screen/utils/api_config.dart';

class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  _AddressManagementScreenState createState() => _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  List<dynamic> addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAddresses();
  }

  Future<void> fetchAddresses() async {
    setState(() => _isLoading = true);
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
        setState(() {
          addresses = data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil alamat')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> createAddress(Map<String, String> addressData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.post(
        ApiConfig.uri('/api/addresses'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: addressData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alamat berhasil ditambahkan')),
        );
        fetchAddresses(); // Refresh list
        Navigator.pop(context); // Close dialog
      } else {
        final data = json.decode(response.body);
        String errorMsg = 'Gagal menambahkan alamat';
        if (data['errors'] != null) {
          data['errors'].forEach((key, value) {
            errorMsg += '\n${value[0]}';
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> setAsMainAddress(int addressId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.put(
        ApiConfig.uri('/api/addresses/$addressId/set-as-main'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alamat utama berhasil diubah')),
        );
        fetchAddresses(); // Refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengubah alamat utama')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> deleteAddress(int addressId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.delete(
        ApiConfig.uri('/api/addresses/$addressId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alamat berhasil dihapus')),
        );
        fetchAddresses(); // Refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus alamat')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showAddAddressDialog() {
    final _nameController = TextEditingController();
    final _phoneController = TextEditingController();
    final _addressController = TextEditingController();
    final _provinceController = TextEditingController();
    final _cityController = TextEditingController();
    final _districtController = TextEditingController();
    final _postalCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Alamat Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Penerima',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'No. Telepon',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat Lengkap',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _provinceController,
                decoration: const InputDecoration(
                  labelText: 'Provinsi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Kota',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _districtController,
                decoration: const InputDecoration(
                  labelText: 'Kecamatan',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _postalCodeController,
                decoration: const InputDecoration(
                  labelText: 'Kode Pos',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final addressData = {
                'nama_penerima': _nameController.text,
                'telepon': _phoneController.text,
                'alamat_lengkap': _addressController.text,
                'provinsi': _provinceController.text,
                'kota': _cityController.text,
                'kecamatan': _districtController.text,
                'kode_pos': _postalCodeController.text,
              };

              if (addressData.values.every((value) => value.isNotEmpty)) {
                createAddress(addressData);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mohon lengkapi semua field')),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int addressId, String addressName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Alamat'),
        content: Text('Apakah Anda yakin ingin menghapus alamat "$addressName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deleteAddress(addressId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
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
        title: const Text(
          'Kelola Alamat',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : addresses.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Belum ada alamat tersimpan',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tambahkan alamat untuk memudahkan pengiriman',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    return AddressCard(
                      address: address,
                      onSetAsMain: () => setAsMainAddress(address['id']),
                      onDelete: () => _showDeleteConfirmation(
                        address['id'],
                        address['nama_penerima'] ?? 'Alamat',
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAddressDialog,
        backgroundColor: const Color(0xFF88D8E9),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

class AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  final VoidCallback onSetAsMain;
  final VoidCallback onDelete;

  const AddressCard({
    super.key,
    required this.address,
    required this.onSetAsMain,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isMain = address['is_main'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    address['nama_penerima'] ?? 'Nama Penerima',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isMain)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Utama',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              address['telepon'] ?? '-',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              address['alamat_lengkap'] ?? '-',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '${address['kecamatan'] ?? '-'}, ${address['kota'] ?? '-'}, ${address['provinsi'] ?? '-'} ${address['kode_pos'] ?? '-'}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isMain)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSetAsMain,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF88D8E9)),
                      ),
                      child: const Text(
                        'Jadikan Utama',
                        style: TextStyle(color: Color(0xFF88D8E9)),
                      ),
                    ),
                  ),
                if (!isMain) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text(
                      'Hapus',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}