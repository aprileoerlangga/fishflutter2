import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fishflutter/screen/utils/api_config.dart';
import '../widgets/bottom_nav_bar.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  _AppointmentScreenState createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  List<dynamic> appointments = [];
  List<dynamic> sellerLocations = [];
  bool _isLoading = true;
  bool _isCreatingAppointment = false;

  @override
  void initState() {
    super.initState();
    fetchAppointments();
    fetchSellerLocations();
  }

  Future<void> fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        ApiConfig.uri('/api/appointments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          appointments = data['data']['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil data janji temu')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> fetchSellerLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        ApiConfig.uri('/api/seller-locations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          sellerLocations = data['data'] ?? [];
        });
      }
    } catch (e) {
      print('Error fetching seller locations: $e');
    }
  }

  Future<void> createAppointment(int sellerId, int locationId, String date) async {
    setState(() => _isCreatingAppointment = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.post(
        ApiConfig.uri('/api/appointments'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'penjual_id': sellerId.toString(),
          'lokasi_penjual_id': locationId.toString(),
          'tanggal_janji': date,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Janji temu berhasil dibuat!')),
        );
        fetchAppointments(); // Refresh list
        Navigator.pop(context); // Close dialog
      } else {
        final data = json.decode(response.body);
        String errorMsg = 'Gagal membuat janji temu';
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
    } finally {
      setState(() => _isCreatingAppointment = false);
    }
  }

  void _showCreateAppointmentDialog() {
    final _dateController = TextEditingController();
    int? selectedSellerId;
    int? selectedLocationId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buat Janji Temu'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Pilih Lokasi Penjual',
                  border: OutlineInputBorder(),
                ),
                value: selectedLocationId,
                items: sellerLocations.map<DropdownMenuItem<int>>((location) {
                  return DropdownMenuItem<int>(
                    value: location['id'],
                    child: Text('${location['nama']} - ${location['alamat']}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedLocationId = value;
                    selectedSellerId = sellerLocations
                        .firstWhere((loc) => loc['id'] == value)['penjual_id'];
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Janji (YYYY-MM-DD HH:MM:SS)',
                  border: OutlineInputBorder(),
                  hintText: '2024-12-25 10:00:00',
                ),
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
            onPressed: _isCreatingAppointment
                ? null
                : () {
                    if (selectedSellerId != null &&
                        selectedLocationId != null &&
                        _dateController.text.isNotEmpty) {
                      createAppointment(
                        selectedSellerId!,
                        selectedLocationId!,
                        _dateController.text,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mohon lengkapi semua field')),
                      );
                    }
                  },
            child: _isCreatingAppointment
                ? const CircularProgressIndicator()
                : const Text('Buat'),
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
          'Janji Temu',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color(0xFF88D8E9),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : appointments.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Belum ada janji temu',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final appointment = appointments[index];
                    return AppointmentCard(appointment: appointment);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateAppointmentDialog,
        backgroundColor: const Color(0xFF88D8E9),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }
}

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const AppointmentCard({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
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
                Text(
                  'Janji Temu #${appointment['id']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(appointment['status']),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    appointment['status'] ?? 'pending',
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
            Text('Penjual: ${appointment['penjual']?['name'] ?? '-'}'),
            Text('Lokasi: ${appointment['lokasi_penjual']?['nama'] ?? '-'}'),
            Text('Alamat: ${appointment['lokasi_penjual']?['alamat'] ?? '-'}'),
            Text('Tanggal: ${appointment['tanggal_janji'] ?? '-'}'),
            if (appointment['catatan'] != null)
              Text('Catatan: ${appointment['catatan']}'),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }
}