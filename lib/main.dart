import 'package:flutter/material.dart';
import 'package:fishflutter/screen/sign_in_screen.dart';
import 'package:fishflutter/screen/fish_market_screen.dart';
import 'package:fishflutter/screen/search_screen.dart';
import 'package:fishflutter/screen/notification_screen.dart';
import 'package:fishflutter/screen/cart_screen.dart';
import 'package:fishflutter/screen/appointment_screen.dart';
import 'package:fishflutter/screen/address_management_screen.dart';
import 'package:fishflutter/screen/order_history_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SignInScreen(),
        '/market': (context) => const FishMarketScreen(),
        '/search': (context) => const SearchScreen(),
        '/fish-market': (context) => const FishMarketScreen(),
        '/notification': (context) => const NotificationScreen(),
        '/cart': (context) => const CartScreen(),
        '/appointment': (context) => const AppointmentScreen(),
        '/address-management': (context) => const AddressManagementScreen(),
        '/order-history': (context) => const OrderHistoryScreen(),
      },
    );
  }
}