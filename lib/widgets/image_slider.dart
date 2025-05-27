import 'package:flutter/material.dart';

class ImageSlider extends StatelessWidget {
  const ImageSlider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 194,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [
          _buildSliderImage('https://cdn.builder.io/api/v1/image/assets/TEMP/36717d935f5735f6d5dfa42bd0fe033959fa9a37', 'Fish market'),
          const SizedBox(width: 20),
          _buildSliderImage('https://cdn.builder.io/api/v1/image/assets/TEMP/d9d23d7c58b5dd509f02d5edad16e6bb5830664d', 'Fresh fish'),
          const SizedBox(width: 20),
          _buildSliderImage('https://cdn.builder.io/api/v1/image/assets/TEMP/51a6595789d0e10383a436adffb0f42c706f2dd8', 'Seafood display'),
        ],
      ),
    );
  }

  Widget _buildSliderImage(String url, String alt) {
    return Container(
      width: 291,
      height: 194,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(url),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}