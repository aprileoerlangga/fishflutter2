import 'package:flutter/material.dart';

class CustomInputField extends StatelessWidget {
  final String placeholder;
  final bool isPassword;
  final Widget icon;

  const CustomInputField({
    super.key,
    required this.placeholder,
    this.isPassword = false,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 67,
      decoration: BoxDecoration(
        color: const Color(0xFFD9FBFF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 13),
            child: SizedBox(
              width: 27,
              height: 27,
              child: icon,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 25),
              child: TextField(
                obscureText: isPassword,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: placeholder,
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Inter',
                    color: Colors.black,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Inter',
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}