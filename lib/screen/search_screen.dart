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

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> searchResults = [];
  bool _isSearching = false;
  List<String> recentSearches = [];
  String _currentQuery = '';

  late AnimationController _animationController;
  late AnimationController _floatingController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    loadRecentSearches();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _floatingAnimation = Tween<double>(begin: -15, end: 15).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _floatingController.dispose();
    super.dispose();
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
    
    searches.remove(query);
    searches.insert(0, query);
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

    setState(() {
      _isSearching = true;
      _currentQuery = keyword;
    });
    
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
        print('Search API Response: $data'); // Debug log

        var results = <dynamic>[];
        
        // Handle different possible API response structures
        if (data is Map) {
          if (data.containsKey('data')) {
            var dataSection = data['data'];
            if (dataSection is Map && dataSection.containsKey('products')) {
              var productsSection = dataSection['products'];
              if (productsSection is Map && productsSection.containsKey('data')) {
                results = List<dynamic>.from(productsSection['data'] ?? []);
              } else if (productsSection is List) {
                results = List<dynamic>.from(productsSection);
              }
            } else if (dataSection is List) {
              results = List<dynamic>.from(dataSection);
            }
          } else if (data.containsKey('products')) {
            var productsSection = data['products'];
            if (productsSection is List) {
              results = List<dynamic>.from(productsSection);
            }
          }
        }

        // Safe filtering with null checks
        results = results.where((product) {
          if (product == null || product is! Map<String, dynamic>) return false;
          
          final productName = product['nama']?.toString()?.toLowerCase() ?? '';
          final searchKeyword = keyword.toLowerCase();
          
          return productName.contains(searchKeyword);
        }).toList();

        setState(() {
          searchResults = results;
          _isSearching = false;
        });
        
        await saveRecentSearch(keyword);
      } else {
        setState(() => _isSearching = false);
        _showErrorSnackBar('Gagal mencari produk (${response.statusCode})');
      }
    } catch (e) {
      print('Search error: $e'); // Debug log
      setState(() => _isSearching = false);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Ocean-themed Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D47A1), // Navy Blue
                    Color(0xFF1565C0), // Blue
                    Color(0xFF1976D2), // Light Blue
                    Color(0xFF2196F3), // Ocean Blue
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Animated floating elements
                  AnimatedBuilder(
                    animation: _floatingAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 20 + _floatingAnimation.value,
                        right: -30,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _floatingAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 60 - _floatingAnimation.value,
                        left: -20,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.03),
                          ),
                        ),
                      );
                    },
                  ),

                  // Header content
                  Padding(
                    padding: EdgeInsets.all(isTablet ? 32 : 24),
                    child: Column(
                      children: [
                        // Top row with back button and title
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),

                            const SizedBox(width: 20),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pencarian',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Inter',
                                      fontSize: isTablet ? 28 : 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Temukan ikan segar impian Anda',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontFamily: 'Inter',
                                      fontSize: isTablet ? 14 : 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Search stats
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    color: Colors.white,
                                    size: isTablet ? 24 : 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${searchResults.length}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Inter',
                                      fontSize: isTablet ? 14 : 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Modern search bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: isTablet ? 16 : 14,
                              color: const Color(0xFF0D47A1),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Cari ikan segar, kategori, atau penjual...',
                              hintStyle: TextStyle(
                                color: Colors.grey[500],
                                fontFamily: 'Inter',
                                fontSize: isTablet ? 16 : 14,
                              ),
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.search_rounded,
                                  color: Colors.white,
                                  size: isTablet ? 20 : 18,
                                ),
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_searchController.text.isNotEmpty)
                                    IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color: Colors.grey[500],
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          searchResults = [];
                                          _currentQuery = '';
                                        });
                                      },
                                    ),
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => searchProducts(_searchController.text),
                                    ),
                                  ),
                                ],
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: isTablet ? 20 : 16,
                              ),
                            ),
                            onSubmitted: (value) => searchProducts(value),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content area
            Expanded(
              child: _isSearching
                  ? _buildLoadingState(isTablet)
                  : searchResults.isNotEmpty
                      ? _buildSearchResults(isTablet)
                      : _buildRecentSearches(isTablet),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isTablet ? 80 : 64,
            height: isTablet ? 80 : 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Mencari "$_currentQuery"...',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              color: const Color(0xFF0D47A1),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sedang mencari produk terbaik untuk Anda',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              color: Colors.grey[600],
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Results header
            Container(
              margin: EdgeInsets.all(isTablet ? 24 : 20),
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF1976D2).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hasil Pencarian',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0D47A1),
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          '${searchResults.length} produk ditemukan untuk "$_currentQuery"',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: const Color(0xFF1976D2),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Results list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 16,
                  vertical: 8,
                ),
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final product = searchResults[index];
                  String imageUrl = '';
                  if (product['gambar'] != null && product['gambar'].isNotEmpty) {
                    imageUrl = ApiConfig.imageUrl(product['gambar'][0]);
                  }

                  return ModernSearchResultItem(
                    product: product,
                    imageUrl: imageUrl,
                    isTablet: isTablet,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailScreen(product: product),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearches(bool isTablet) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recent searches header
              Container(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: Colors.white,
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Pencarian Terkini',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D47A1),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    if (recentSearches.isNotEmpty)
                      TextButton.icon(
                        onPressed: clearRecentSearches,
                        icon: const Icon(
                          Icons.clear_all_rounded,
                          size: 18,
                          color: Color(0xFFD32F2F),
                        ),
                        label: Text(
                          'Hapus Semua',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: const Color(0xFFD32F2F),
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Recent searches list or empty state
              if (recentSearches.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: recentSearches.length,
                    itemBuilder: (context, index) {
                      final search = recentSearches[index];
                      return ModernRecentSearchItem(
                        title: search,
                        isTablet: isTablet,
                        onTap: () {
                          _searchController.text = search;
                          searchProducts(search);
                        },
                        onRemove: () => removeRecentSearch(search),
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated floating search icon
                        AnimatedBuilder(
                          animation: _floatingAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _floatingAnimation.value * 0.3),
                              child: Container(
                                width: isTablet ? 100 : 80,
                                height: isTablet ? 100 : 80,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                                  ),
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1976D2).withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.search_outlined,
                                  size: isTablet ? 40 : 35,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Belum ada pencarian terkini',
                          style: TextStyle(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0D47A1),
                            fontFamily: 'Inter',
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Mulai mencari ikan segar favorit Anda\ndi kolom pencarian di atas',
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModernSearchResultItem extends StatelessWidget {
  final Map<String, dynamic> product;
  final String imageUrl;
  final bool isTablet;
  final VoidCallback onTap;

  const ModernSearchResultItem({
    super.key,
    required this.product,
    required this.imageUrl,
    required this.isTablet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Safe null checks for all product properties
    final productName = product['nama']?.toString() ?? product['name']?.toString() ?? 'Produk';
    final fishType = product['jenis_ikan']?.toString() ?? 'Ikan';
    final sellerName = _getSafeSellerName();
    final price = _getSafePrice();
    final rating = _getSafeRating();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                // Product image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: isTablet ? 80 : 70,
                    height: isTablet ? 80 : 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.image_not_supported_rounded,
                              color: const Color(0xFF1976D2),
                              size: isTablet ? 32 : 28,
                            ),
                          )
                        : Icon(
                            Icons.image_rounded,
                            color: const Color(0xFF1976D2),
                            size: isTablet ? 32 : 28,
                          ),
                  ),
                ),

                const SizedBox(width: 16),

                // Product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product category badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          fishType,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Product name
                      Text(
                        productName,
                        style: TextStyle(
                          color: const Color(0xFF0D47A1),
                          fontFamily: 'Inter',
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 6),

                      // Seller info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.store_rounded,
                              size: isTablet ? 14 : 12,
                              color: const Color(0xFF1976D2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              sellerName,
                              style: TextStyle(
                                color: const Color(0xFF1976D2),
                                fontFamily: 'Inter',
                                fontSize: isTablet ? 14 : 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Price and rating row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Rp $price',
                              style: TextStyle(
                                color: const Color(0xFF2E7D32),
                                fontFamily: 'Inter',
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (rating > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: isTablet ? 16 : 14,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: Colors.amber[800],
                                      fontFamily: 'Inter',
                                      fontSize: isTablet ? 12 : 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: const Color(0xFF1976D2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getSafeSellerName() {
    try {
      if (product['seller'] != null) {
        if (product['seller'] is Map) {
          return product['seller']['name']?.toString() ?? 'Penjual';
        } else {
          return product['seller'].toString();
        }
      }
      
      if (product['seller_name'] != null) {
        return product['seller_name'].toString();
      }
      
      return 'Penjual';
    } catch (e) {
      return 'Penjual';
    }
  }

  String _getSafePrice() {
    try {
      final harga = product['harga'] ?? product['price'] ?? 0;
      if (harga == null) return '0';
      
      final priceString = harga.toString();
      final priceNumber = int.tryParse(priceString) ?? 0;
      
      return priceNumber.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
        (Match m) => '${m[1]}.'
      );
    } catch (e) {
      return '0';
    }
  }

  double _getSafeRating() {
    try {
      final ratingRata = product['rating_rata'] ?? product['rating'] ?? 0;
      if (ratingRata == null) return 0.0;
      
      if (ratingRata is double) return ratingRata;
      if (ratingRata is int) return ratingRata.toDouble();
      
      return double.tryParse(ratingRata.toString()) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }
}

class ModernRecentSearchItem extends StatelessWidget {
  final String title;
  final bool isTablet;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const ModernRecentSearchItem({
    super.key,
    required this.title,
    required this.isTablet,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1976D2).withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    size: isTablet ? 20 : 18,
                    color: const Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: const Color(0xFF0D47A1),
                      fontFamily: 'Inter',
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: isTablet ? 20 : 18,
                      color: Colors.grey[600],
                    ),
                    onPressed: onRemove,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
                