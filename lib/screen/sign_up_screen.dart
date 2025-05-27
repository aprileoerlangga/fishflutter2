import 'package:flutter/material.dart';
import 'package:fishflutter/screen/sign_in_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fishflutter/screen/utils/api_config.dart';
import 'dart:math' as Math;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  Map<String, String> _errors = {};

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
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_agreeToTerms) {
      _showErrorSnackBar('Anda harus menyetujui syarat dan ketentuan');
      return;
    }

    setState(() {
      _errors = {};
      _isLoading = true;
    });

    try {
      final response = await http.post(
        ApiConfig.uri('/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': _usernameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'password_confirmation': _confirmPasswordController.text,
          if (_phoneController.text.trim().isNotEmpty)
            'phone': _phoneController.text.trim(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        _showSuccessSnackBar('Registrasi berhasil! Silakan login.');

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const SignInScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        );
      } else if (response.statusCode == 422) {
        final responseData = json.decode(response.body);
        if (responseData['errors'] != null) {
          setState(() {
            (responseData['errors'] as Map<String, dynamic>).forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                _errors[key] = value.first.toString();
              }
            });
          });
        }
      } else {
        final responseData = json.decode(response.body);
        throw Exception(responseData['message'] ?? 'Registrasi gagal');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  @override
  Widget build(BuildContext context) {
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
              final isSmallScreen = availableHeight < 700;
              
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: availableHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // Header dengan animasi gelombang
                        Container(
                          height: isSmallScreen ? availableHeight * 0.2 : availableHeight * 0.25,
                          child: Stack(
                            children: [
                              // Animated wave background
                              AnimatedBuilder(
                                animation: _waveAnimation,
                                builder: (context, child) {
                                  return CustomPaint(
                                    size: Size(MediaQuery.of(context).size.width, 150),
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
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.person_add,
                                          size: isSmallScreen ? 32 : 40,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 8 : 12),
                                      Text(
                                        'Daftar Akun Baru',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 20 : 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 2 : 4),
                                      Text(
                                        'Bergabunglah dengan IwakMart',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 14,
                                          color: Colors.white.withOpacity(0.9),
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Form registrasi
                        Expanded(
                          child: FadeTransition(
                            opacity: _fadeInAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Container(
                                margin: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
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
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Buat Akun Baru',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 18 : 22,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF0D47A1),
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 4 : 8),
                                      Text(
                                        'Lengkapi data di bawah ini',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 14,
                                          color: Colors.grey[600],
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 20 : 24),

                                      // Username field
                                      _buildModernTextField(
                                        controller: _usernameController,
                                        label: 'Nama Lengkap',
                                        icon: Icons.person_outline,
                                        isSmallScreen: isSmallScreen,
                                        errorText: _errors['name'],
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Nama harus diisi';
                                          }
                                          if (value.length < 2) {
                                            return 'Nama minimal 2 karakter';
                                          }
                                          return null;
                                        },
                                      ),

                                      SizedBox(height: isSmallScreen ? 12 : 16),

                                      // Email field
                                      _buildModernTextField(
                                        controller: _emailController,
                                        label: 'Email',
                                        icon: Icons.email_outlined,
                                        keyboardType: TextInputType.emailAddress,
                                        isSmallScreen: isSmallScreen,
                                        errorText: _errors['email'],
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

                                      SizedBox(height: isSmallScreen ? 12 : 16),

                                      // Phone field
                                      _buildModernTextField(
                                        controller: _phoneController,
                                        label: 'No. Telepon (Opsional)',
                                        icon: Icons.phone_outlined,
                                        keyboardType: TextInputType.phone,
                                        isSmallScreen: isSmallScreen,
                                        errorText: _errors['phone'],
                                        validator: (value) {
                                          if (value != null && value.isNotEmpty) {
                                            if (value.length < 10) {
                                              return 'Nomor telepon minimal 10 digit';
                                            }
                                          }
                                          return null;
                                        },
                                      ),

                                      SizedBox(height: isSmallScreen ? 12 : 16),

                                      // Password field
                                      _buildModernTextField(
                                        controller: _passwordController,
                                        label: 'Password',
                                        icon: Icons.lock_outline,
                                        obscureText: _obscurePassword,
                                        isSmallScreen: isSmallScreen,
                                        errorText: _errors['password'],
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

                                      // Confirm Password field
                                      _buildModernTextField(
                                        controller: _confirmPasswordController,
                                        label: 'Konfirmasi Password',
                                        icon: Icons.lock_outline,
                                        obscureText: _obscureConfirmPassword,
                                        isSmallScreen: isSmallScreen,
                                        errorText: _errors['password_confirmation'],
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                            color: const Color(0xFF1976D2),
                                          ),
                                          onPressed: () {
                                            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                          },
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Konfirmasi password harus diisi';
                                          }
                                          if (value != _passwordController.text) {
                                            return 'Konfirmasi password tidak cocok';
                                          }
                                          return null;
                                        },
                                      ),

                                      SizedBox(height: isSmallScreen ? 12 : 16),

                                      // Terms agreement
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Checkbox(
                                            value: _agreeToTerms,
                                            onChanged: (value) {
                                              setState(() => _agreeToTerms = value ?? false);
                                            },
                                            activeColor: const Color(0xFF1976D2),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() => _agreeToTerms = !_agreeToTerms);
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.only(top: 12),
                                                child: RichText(
                                                  text: TextSpan(
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen ? 11 : 12,
                                                      color: Colors.grey[600],
                                                      fontFamily: 'Inter',
                                                    ),
                                                    children: [
                                                      const TextSpan(text: 'Saya menyetujui '),
                                                      TextSpan(
                                                        text: 'Syarat dan Ketentuan',
                                                        style: TextStyle(
                                                          color: const Color(0xFF1976D2),
                                                          fontWeight: FontWeight.w600,
                                                          decoration: TextDecoration.underline,
                                                        ),
                                                      ),
                                                      const TextSpan(text: ' serta '),
                                                      TextSpan(
                                                        text: 'Kebijakan Privasi',
                                                        style: TextStyle(
                                                          color: const Color(0xFF1976D2),
                                                          fontWeight: FontWeight.w600,
                                                          decoration: TextDecoration.underline,
                                                        ),
                                                      ),
                                                      const TextSpan(text: ' IwakMart'),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: isSmallScreen ? 16 : 20),

                                      // Register button
                                      SizedBox(
                                        width: double.infinity,
                                        height: isSmallScreen ? 45 : 52,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _signUp,
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
                                                  'DAFTAR SEKARANG',
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 14 : 16,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'Inter',
                                                  ),
                                                ),
                                        ),
                                      ),

                                      SizedBox(height: isSmallScreen ? 12 : 16),

                                      // Sign in link
                                      Center(
                                        child: Wrap(
                                          alignment: WrapAlignment.center,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              'Sudah punya akun? ',
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 12 : 14,
                                                color: Colors.grey[600],
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pushReplacement(
                                                  context,
                                                  PageRouteBuilder(
                                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                                        const SignInScreen(),
                                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                      return SlideTransition(
                                                        position: Tween<Offset>(
                                                          begin: const Offset(-1.0, 0.0),
                                                          end: Offset.zero,
                                                        ).animate(animation),
                                                        child: child,
                                                      );
                                                    },
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                'Masuk',
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
    String? errorText,
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
                color: errorText != null ? Colors.red : Colors.grey.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: errorText != null ? Colors.red : Colors.grey.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: errorText != null ? Colors.red : const Color(0xFF1976D2),
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
            errorText: errorText,
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
    final waveHeight = 15.0;
    final waveLength = size.width / 2;

    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height - 40 + 
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
      final y = size.height - 25 + 
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