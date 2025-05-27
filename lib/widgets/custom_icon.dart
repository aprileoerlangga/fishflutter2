import 'package:flutter/material.dart';

class UserIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Path path = Path();
    path.moveTo(size.width * 0.4877, 0);
    path.cubicTo(size.width * 0.5527, 0, size.width * 0.6148, size.height * 0.0255,
        size.width * 0.6605, size.height * 0.0709);
    // Add the rest of the user icon path here

    Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class EmailIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Path path = Path();
    path.moveTo(size.width * 0.9167, size.height * 0.25);
    // Add the rest of the email icon path here

    Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class PasswordIcon extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Path path = Path();
    path.moveTo(size.width * 0.0833, size.height * 0.7917);
    // Add the rest of the password icon path here

    Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}