import 'package:flutter/material.dart';

class ProductCard extends StatefulWidget {
  final String fishType;
  final String name;
  final String seller;
  final double rating;
  final String price;
  final String poster;

  const ProductCard({
    super.key,
    required this.fishType,
    required this.name,
    required this.seller,
    required this.rating,
    required this.price,
    required this.poster,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _isPressed 
                        ? const Color(0xFF1976D2).withOpacity(0.2)
                        : Colors.black.withOpacity(0.08),
                    blurRadius: _isPressed ? 20 : 12,
                    offset: Offset(0, _isPressed ? 8 : 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Container gambar dengan overlay
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Gambar produk
                          widget.poster.isNotEmpty
                              ? Image.network(
                                  widget.poster,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFFE3F2FD),
                                          Color(0xFFBBDEFB),
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported_rounded,
                                        size: 40,
                                        color: Color(0xFF1976D2),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFE3F2FD),
                                        Color(0xFFBBDEFB),
                                      ],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_rounded,
                                      size: 40,
                                      color: Color(0xFF1976D2),
                                    ),
                                  ),
                                ),

                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.1),
                                ],
                              ),
                            ),
                          ),

                          // Badge jenis ikan
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1976D2).withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.fishType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ),

                          // Rating badge (jika ada)
                          if (widget.rating > 0)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      widget.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Tombol favorit
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.favorite_border_rounded,
                                size: 18,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Informasi produk
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nama produk
                          Text(
                            widget.name,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 8),

                          // Informasi penjual
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.store_rounded,
                                  size: 14,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.seller,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: Color(0xFF64B5F6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Harga dengan styling menarik
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE8F5E8),
                                  Color(0xFFC8E6C9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF4CAF50).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Rp ${widget.price}',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
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
      },
    );
  }
}