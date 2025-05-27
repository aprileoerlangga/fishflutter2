import 'package:flutter/material.dart';
import 'package:fishflutter/screen/chat_screen.dart';
import 'package:fishflutter/screen/fish_market_screen.dart';
import 'package:fishflutter/screen/profile_screen.dart';
import 'package:fishflutter/screen/appointment_screen.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const FishMarketScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AppointmentScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ChatScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        child: Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                activeIcon: Icons.home,
                label: 'Beranda',
                index: 0,
                context: context,
              ),
              _buildNavItem(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today,
                label: 'Janji Temu',
                index: 1,
                context: context,
              ),
              _buildNavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Pesan',
                index: 2,
                context: context,
              ),
              _buildNavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
                index: 3,
                context: context,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required BuildContext context,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(context, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Container dengan animasi
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.all(isSelected ? 8 : 4),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF1976D2),
                            Color(0xFF0D47A1),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1976D2).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: isSelected ? 26 : 24,
                  color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
                ),
              ),

              const SizedBox(height: 6),

              // Label dengan animasi
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: isSelected ? 12 : 11,
                  fontFamily: 'Inter',
                  color: isSelected ? const Color(0xFF0D47A1) : const Color(0xFF9E9E9E),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text(label),
              ),

              // Indicator dot
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isSelected ? 6 : 0,
                height: isSelected ? 6 : 0,
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}