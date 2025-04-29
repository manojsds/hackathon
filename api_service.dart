import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<bool> sendEmergencyMessage(String message) async {
    final url = Uri.parse('\$baseUrl/emergency');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to send emergency message: \${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Exception sending emergency message: \$e');
      return false;
    }
  }
}
