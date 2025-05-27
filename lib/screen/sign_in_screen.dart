import 'package:flutter/material.dart';
import 'package:fishflutter/screen/fish_market_screen.dart';
import 'package:fishflutter/screen/sign_up_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fishflutter/screen/utils/api_config.dart';
import 'dart:math' as Math;

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late AnimationController _animationController;
  late AnimationController _waveController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _waveAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_waveController);

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        ApiConfig.uri('/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['data']['access_token']);

        if (_rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('saved_email', _emailController.text);
        }

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const FishMarketScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        );
      } else {
        _showErrorSnackBar('Email atau password salah');
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan: $e');
    } finally {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF1565C0),
              Color(0xFF1976D2),
              Color(0xFF2196F3),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight;
              final isSmallScreen = availableHeight < 600;
              
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: availableHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Header dengan animasi gelombang - Responsive height
                        Container(
                          height: isSmallScreen ? availableHeight * 0.25 : availableHeight * 0.35,
                          child: Stack(
                            children: [
                              // Animated wave background
                              AnimatedBuilder(
                                animation: _waveAnimation,
                                builder: (context, child) {
                                  return CustomPaint(
                                    size: Size(MediaQuery.of(context).size.width, 200),
                                    painter: WavePainter(_waveAnimation.value),
                                  );
                                },
                              ),
                              // Logo dan welcome text
                              FadeTransition(
                                opacity: _fadeInAnimation,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.waves,
                                          size: isSmallScreen ? 40 : 50,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 12 : 16),
                                      Text(
                                        'IwakMart',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 24 : 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 4 : 8),
                                      Text(
                                        'Ikan Segar Langsung dari Nelayan',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 16,
                                          color: Colors.white.withOpacity(0.9),
                                          fontFamily: 'Inter',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Form login - Flexible content
                        Expanded(
                          child: FadeTransition(
                            opacity: _fadeInAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Container(
                                margin: EdgeInsets.all(isSmallScreen ? 16 : 20),
                                padding: EdgeInsets.all(isSmallScreen ? 20 : 30),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Text(
                                          'Masuk ke Akun Anda',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 20 : 24,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0D47A1),
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 4 : 8),
                                      Center(
                                        child: Text(
                                          'Silakan masuk untuk melanjutkan',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 14,
                                            color: Colors.grey[600],
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 24 : 32),

                                      // Email field
                                      _buildModernTextField(
                                        controller: _emailController,
                                        label: 'Email',
                                        icon: Icons.email_outlined,
                                        keyboardType: TextInputType.emailAddress,
                                        isSmallScreen: isSmallScreen,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Email harus diisi';
                                          }
                                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                            return 'Format email tidak valid';
                                          }
                                          return null;
                                        },
                                      ),

                                      SizedBox(height: isSmallScreen ? 16 : 20),

                                      // Password field
                                      _buildModernTextField(
                                        controller: _passwordController,
                                        label: 'Password',
                                        icon: Icons.lock_outline,
                                        obscureText: _obscurePassword,
                                        isSmallScreen: isSmallScreen,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                            color: const Color(0xFF1976D2),
                                          ),
                                          onPressed: () {
                                            setState(() => _obscurePassword = !_obscurePassword);
                                          },
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Password harus diisi';
                                          }
                                          if (value.length < 6) {
                                            return 'Password minimal 6 karakter';
                                          }
                                          return null;
                                        },
                                      ),

                                      SizedBox(height: isSmallScreen ? 12 : 16),

                                      // Remember me & Forgot password
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Row(
                                              children: [
                                                Checkbox(
                                                  value: _rememberMe,
                                                  onChanged: (value) {
                                                    setState(() => _rememberMe = value ?? false);
                                                  },
                                                  activeColor: const Color(0xFF1976D2),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                                Flexible(
                                                  child: Text(
                                                    'Ingat saya',
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen ? 12 : 14,
                                                      color: const Color(0xFF666666),
                                                      fontFamily: 'Inter',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Fitur lupa password segera hadir'),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              'Lupa Password?',
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 12 : 14,
                                                color: const Color(0xFF1976D2),
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: isSmallScreen ? 20 : 24),

                                      // Login button
                                      SizedBox(
                                        width: double.infinity,
                                        height: isSmallScreen ? 48 : 56,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _signIn,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1976D2),
                                            foregroundColor: Colors.white,
                                            elevation: 8,
                                            shadowColor: const Color(0xFF1976D2).withOpacity(0.4),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Text(
                                                  'MASUK',
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 14 : 16,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'Inter',
                                                  ),
                                                ),
                                        ),
                                      ),

                                      SizedBox(height: isSmallScreen ? 16 : 20),

                                      // Sign up link
                                      Center(
                                        child: Wrap(
                                          alignment: WrapAlignment.center,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              'Belum punya akun? ',
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 12 : 14,
                                                color: Colors.grey[600],
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  PageRouteBuilder(
                                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                                        const SignUpScreen(),
                                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                      return SlideTransition(
                                                        position: Tween<Offset>(
                                                          begin: const Offset(1.0, 0.0),
                                                          end: Offset.zero,
                                                        ).animate(animation),
                                                        child: child,
                                                      );
                                                    },
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                'Daftar Sekarang',
                                                style: TextStyle(
                                                  fontSize: isSmallScreen ? 12 : 14,
                                                  color: const Color(0xFF1976D2),
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    required bool isSmallScreen,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0D47A1),
            fontFamily: 'Inter',
          ),
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontFamily: 'Inter',
          ),
          decoration: InputDecoration(
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: isSmallScreen ? 18 : 20,
                color: const Color(0xFF1976D2),
              ),
            ),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF1976D2),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FBFF),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16, 
              vertical: isSmallScreen ? 12 : 16,
            ),
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontFamily: 'Inter',
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter untuk efek gelombang
class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = 20.0;
    final waveLength = size.width / 2;

    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height - 50 + 
          waveHeight * Math.sin((x / waveLength * 2 * Math.pi) + (animationValue * 2 * Math.pi));
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Second wave
    final paint2 = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height - 30 + 
          (waveHeight * 0.7) * Math.sin((x / waveLength * 2 * Math.pi) + (animationValue * 2 * Math.pi) + Math.pi);
      path2.lineTo(x, y);
    }

    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}