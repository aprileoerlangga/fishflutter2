import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fishflutter/screen/utils/api_config.dart';
import '../widgets/bottom_nav_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchConversations();
  }

  Future<void> fetchConversations() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        ApiConfig.uri('/api/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          conversations = data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil percakapan')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formatTime(String? dateString) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Pesan',
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
          : conversations.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Belum ada percakapan',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Mulai chat dengan penjual untuk melihat percakapan di sini',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchConversations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return ChatItem(
                        conversation: conversation,
                        formatTime: _formatTime,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatDetailScreen(
                                conversation: conversation,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }
}

class ChatItem extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String Function(String?) formatTime;
  final VoidCallback onTap;

  const ChatItem({
    super.key,
    required this.conversation,
    required this.formatTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherUser = conversation['other_user'] ?? {};
    final lastMessage = conversation['last_message'] ?? {};
    final unreadCount = conversation['unread_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFB4ECF9),
          backgroundImage: otherUser['avatar'] != null 
              ? NetworkImage(ApiConfig.imageUrl(otherUser['avatar']))
              : null,
          child: otherUser['avatar'] == null
              ? const Icon(Icons.storefront, color: Colors.white)
              : null,
        ),
        title: Text(
          otherUser['name'] ?? 'Pengguna',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          lastMessage['isi'] ?? 'Belum ada pesan',
          style: TextStyle(
            fontFamily: 'Inter',
            color: unreadCount > 0 ? Colors.black87 : Colors.grey,
            fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatTime(lastMessage['created_at']),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> conversation;

  const ChatDetailScreen({super.key, required this.conversation});

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<dynamic> messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final otherUserId = widget.conversation['other_user']['id'];
      
      final response = await http.get(
        ApiConfig.uri('/api/messages/$otherUserId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          messages = data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final otherUserId = widget.conversation['other_user']['id'];
      
      final response = await http.post(
        ApiConfig.uri('/api/messages'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'penerima_id': otherUserId.toString(),
          'isi': _messageController.text,
          'jenis': 'text',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _messageController.clear();
        fetchMessages(); // Refresh messages
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim pesan')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherUser = widget.conversation['other_user'] ?? {};

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF88D8E9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFB4ECF9),
              backgroundImage: otherUser['avatar'] != null 
                  ? NetworkImage(ApiConfig.imageUrl(otherUser['avatar']))
                  : null,
              child: otherUser['avatar'] == null
                  ? const Icon(Icons.storefront, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              otherUser['name'] ?? 'Pengguna',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada pesan\nMulai percakapan dengan mengirim pesan',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return MessageBubble(message: message);
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF88D8E9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isSending ? null : sendMessage,
                    icon: _isSending
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Icon(Icons.send, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message['is_sent_by_me'] ?? false;
    final text = message['isi'] ?? '';
    final time = _formatMessageTime(message['created_at']);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF88D8E9) : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.black : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(String? dateString) {
    if (dateString == null) return '';
    
    try {
      final date = DateTime.parse(dateString);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}