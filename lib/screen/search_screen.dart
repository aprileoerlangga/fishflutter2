import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fishflutter/screen/utils/api_config.dart';
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> searchResults = [];
  bool _isSearching = false;
  List<String> recentSearches = [];

  @override
  void initState() {
    super.initState();
    loadRecentSearches();
  }

  Future<void> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList('recent_searches') ?? [];
    
    // Remove if already exists to avoid duplicates
    searches.remove(query);
    // Add to beginning
    searches.insert(0, query);
    // Keep only last 10 searches
    if (searches.length > 10) {
      searches = searches.take(10).toList();
    }
    
    await prefs.setStringList('recent_searches', searches);
    setState(() {
      recentSearches = searches;
    });
  }

  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    setState(() {
      recentSearches = [];
    });
  }

  Future<void> searchProducts(String keyword) async {
    if (keyword.trim().isEmpty) return;

    setState(() => _isSearching = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        ApiConfig.uri('/api/products/search/$keyword'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(data); // Untuk debug

        // Ambil list produk dari struktur API baru
        var results = [];
        if (data['data'] != null &&
            data['data']['products'] != null &&
            data['data']['products']['data'] != null) {
          results = data['data']['products']['data'];
        }

        // Setelah ambil results dari API
        results = results.where((product) =>
          (product['nama']?.toLowerCase() ?? '').contains(keyword.toLowerCase())
        ).toList();

        setState(() {
          searchResults = results;
          _isSearching = false;
        });
        // Save to recent searches
        await saveRecentSearch(keyword);
      } else {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mencari produk')),
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList('recent_searches') ?? [];
    searches.remove(query);
    await prefs.setStringList('recent_searches', searches);
    setState(() {
      recentSearches = searches;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 31, 24, 31),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEDEDED)),
                      color: Colors.white,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Text(
                    'Search',
                    style: TextStyle(
                      color: Color(0xFF101010),
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 19),
              
              // Search Input
              Container(
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEDEDED)),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.search, size: 20, color: Color(0xFF878787)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Cari ikan...',
                          hintStyle: TextStyle(
                            color: Color(0xFF878787),
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onSubmitted: (value) => searchProducts(value),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF878787)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            searchResults = [];
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFF88D8E9)),
                      onPressed: () => searchProducts(_searchController.text),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : searchResults.isNotEmpty
                        ? _buildSearchResults()
                        : _buildRecentSearches(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hasil Pencarian (${searchResults.length})',
          style: const TextStyle(
            color: Color(0xFF101010),
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final product = searchResults[index];
              String imageUrl = '';
              if (product['gambar'] != null && product['gambar'].isNotEmpty) {
                imageUrl = ApiConfig.imageUrl(product['gambar'][0]);
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(product: product),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: 70,
                                height: 65,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: 70,
                                  height: 65,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                ),
                              )
                            : Container(
                                width: 70,
                                height: 65,
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
                              product['nama'] ?? product['name'] ?? 'Produk',
                              style: const TextStyle(
                                color: Color(0xFF101010),
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product['seller']?['name'] ?? product['seller_name'] ?? '-',
                              style: const TextStyle(
                                color: Color(0xFF878787),
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rp ${product['harga'] ?? product['price'] ?? '0'}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  product['rating_rata']?.toString() ?? product['rating']?.toString() ?? '0.0',
                                  style: const TextStyle(
                                    color: Color(0xFF101010),
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
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
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recent searches header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pencarian terkini',
              style: TextStyle(
                color: Color(0xFF101010),
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (recentSearches.isNotEmpty)
              TextButton(
                onPressed: clearRecentSearches,
                child: const Text(
                  'Hapus Semua',
                  style: TextStyle(
                    color: Color(0xFF88D8E9),
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 11),
        
        // Recent searches list
        if (recentSearches.isNotEmpty)
          ...recentSearches.map((search) => RecentSearchItem(
                title: search,
                onTap: () {
                  _searchController.text = search;
                  searchProducts(search);
                },
                onRemove: () => removeRecentSearch(search),
              ))
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Belum ada pencarian terkini',
                style: TextStyle(
                  color: Color(0xFF878787),
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class RecentSearchItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const RecentSearchItem({
    super.key,
    required this.title,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 24, color: Color(0xFF878787)),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF101010),
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 20, color: Color(0xFF878787)),
            ),
          ],
        ),
      ),
    );
  }
}