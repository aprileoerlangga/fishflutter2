class ApiConfig {
  // Ubah ke IP lokal kamu + port Laravel serve
  // static const String baseUrl = 'http://192.168.108.6:8000';
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  static String imageUrl(String path) => '$baseUrl/storage/$path';
}
