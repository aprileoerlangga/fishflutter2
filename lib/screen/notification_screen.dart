import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fishflutter/screen/utils/api_config.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with TickerProviderStateMixin {
  List<dynamic> notifications = [];
  bool _isLoading = true;
  int unreadCount = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    fetchNotifications();
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

  Future<void> fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        ApiConfig.uri('/api/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          notifications = data['data']['notifications']['data'] ?? [];
          unreadCount = data['data']['unread_count'] ?? 0;
          _isLoading = false;
        });
        _animationController.forward();
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Gagal mengambil notifikasi');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.put(
        ApiConfig.uri('/api/notifications/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          final index = notifications.indexWhere((n) => n['id'] == notificationId);
          if (index != -1) {
            notifications[index]['is_read'] = true;
            notifications[index]['dibaca_pada'] = DateTime.now().toIso8601String();
            if (unreadCount > 0) unreadCount--;
          }
        });
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.put(
        ApiConfig.uri('/api/notifications/mark-all-as-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          for (var notification in notifications) {
            notification['is_read'] = true;
            notification['dibaca_pada'] = DateTime.now().toIso8601String();
          }
          unreadCount = 0;
        });
        _showSuccessSnackBar('Semua notifikasi telah dibaca');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
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

  String _formatTimeAgo(String? dateString) {
    if (dateString == null) return '';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        if (difference.inDays == 1) {
          return 'Kemarin';
        } else if (difference.inDays < 7) {
          return '${difference.inDays} hari';
        } else {
          return '${date.day}/${date.month}/${date.year}';
        }
      } else if (difference.inHours > 0) {
        return '${difference.inHours}j';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'Sekarang';
      }
    } catch (e) {
      return '';
    }
  }

  List<dynamic> get todayNotifications {
    final today = DateTime.now();
    return notifications.where((notification) {
      try {
        final createdAt = DateTime.parse(notification['created_at']);
        return createdAt.day == today.day &&
               createdAt.month == today.month &&
               createdAt.year == today.year;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  List<dynamic> get yesterdayNotifications {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return notifications.where((notification) {
      try {
        final createdAt = DateTime.parse(notification['created_at']);
        return createdAt.day == yesterday.day &&
               createdAt.month == yesterday.month &&
               createdAt.year == yesterday.year;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  List<dynamic> get olderNotifications {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    return notifications.where((notification) {
      try {
        final createdAt = DateTime.parse(notification['created_at']);
        return createdAt.isBefore(twoDaysAgo);
      } catch (e) {
        return false;
      }
    }).toList();
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
                    blurRadius: 8,
                    offset: Offset(0, 2),
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
                    
                    // Notification Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.notifications,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Title and Badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Notifikasi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                  fontSize: isTablet ? 20 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5722),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF5722).withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${notifications.length} total notifikasi',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontFamily: 'Inter',
                              fontSize: isTablet ? 14 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Mark all as read button
                    if (unreadCount > 0)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.done_all, color: Colors.white),
                          onPressed: markAllAsRead,
                          tooltip: 'Tandai semua sudah dibaca',
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
                  : notifications.isEmpty
                      ? _buildEmptyState(isTablet)
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: RefreshIndicator(
                              onRefresh: fetchNotifications,
                              color: const Color(0xFF1976D2),
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Column(
                                  children: [
                                    // Hari Ini
                                    if (todayNotifications.isNotEmpty)
                                      _buildNotificationSection(
                                        'Hari ini', 
                                        todayNotifications, 
                                        isTablet
                                      ),

                                    // Kemarin
                                    if (yesterdayNotifications.isNotEmpty)
                                      _buildNotificationSection(
                                        'Kemarin', 
                                        yesterdayNotifications, 
                                        isTablet
                                      ),

                                    // Lebih Lama
                                    if (olderNotifications.isNotEmpty)
                                      _buildNotificationSection(
                                        'Lebih Lama', 
                                        olderNotifications, 
                                        isTablet
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
                Icons.notifications_none,
                size: isTablet ? 80 : 64,
                color: const Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum ada notifikasi',
              style: TextStyle(
                fontSize: isTablet ? 20 : 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D47A1),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Notifikasi Anda akan muncul di sini\nketika ada update terbaru',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey[600],
                fontFamily: 'Inter',
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection(String title, List<dynamic> sectionNotifications, bool isTablet) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFF0D47A1),
                    fontFamily: 'Inter',
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...sectionNotifications.map((notification) => 
                ModernNotificationItem(
                  notification: notification,
                  onTap: () => markAsRead(notification['id']),
                  formatTimeAgo: _formatTimeAgo,
                  isTablet: isTablet,
                ),
              ),
            ],
          ),
        ),
        if (title != 'Lebih Lama')
          Container(
            height: 8,
            color: const Color(0xFFE3F2FD),
          ),
      ],
    );
  }
}

class ModernNotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final String Function(String?) formatTimeAgo;
  final bool isTablet;

  const ModernNotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
    required this.formatTimeAgo,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] ?? false;
    final timeAgo = notification['time_ago'] ?? formatTimeAgo(notification['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead 
              ? Colors.grey.withOpacity(0.2) 
              : const Color(0xFF1976D2).withOpacity(0.3),
          width: isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notification Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification['jenis']),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _getNotificationColor(notification['jenis']).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getNotificationIcon(notification['jenis']),
                    color: Colors.white,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['judul'] ?? 'Notifikasi',
                              style: TextStyle(
                                color: const Color(0xFF0D47A1),
                                fontFamily: 'Inter',
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1976D2),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification['isi'] ?? '',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontFamily: 'Inter',
                          fontSize: isTablet ? 14 : 13,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              notification['type_text'] ?? 'Notifikasi',
                              style: TextStyle(
                                color: const Color(0xFF1976D2),
                                fontFamily: 'Inter',
                                fontSize: isTablet ? 12 : 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.access_time,
                            size: isTablet ? 14 : 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontFamily: 'Inter',
                              fontSize: isTablet ? 12 : 11,
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
        ),
      ),
    );
  }

  Color _getNotificationColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'pesanan':
        return const Color(0xFF4CAF50);
      case 'pembayaran':
        return const Color(0xFF2196F3);
      case 'pengiriman':
        return const Color(0xFFFF9800);
      case 'janji_temu':
        return const Color(0xFF9C27B0);
      case 'promo':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF1976D2);
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'pesanan':
        return Icons.shopping_bag;
      case 'pembayaran':
        return Icons.payment;
      case 'pengiriman':
        return Icons.local_shipping;
      case 'janji_temu':
        return Icons.calendar_today;
      case 'promo':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }
}