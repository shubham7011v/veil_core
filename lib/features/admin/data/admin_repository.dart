import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';

class AdminRepository {
  String? _adminKey;

  // For now, we assume standard HTTP since admin won't use WS generally
  // However, we need the baseURL.
  // We can grab it from AppConfig or Environment.
  // Ideally this would be injected, but for speed we'll use a dynamic getter.

  String get _baseUrl {
    return AppConfig.instance.apiBaseUrl;
  }

  void setKey(String key) {
    _adminKey = key;
  }

  bool get isAuthenticated => _adminKey != null && _adminKey!.isNotEmpty;

  Future<Map<String, dynamic>> getStats() async {
    if (!isAuthenticated) throw Exception('Not Authenticated');

    final response = await http.get(
      Uri.parse('$_baseUrl/admin/stats'),
      headers: {'X-Admin-Key': _adminKey!},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load stats: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getRooms() async {
    if (!isAuthenticated) throw Exception('Not Authenticated');

    final response = await http.get(
      Uri.parse('$_baseUrl/admin/rooms'),
      headers: {'X-Admin-Key': _adminKey!},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load rooms: ${response.statusCode}');
    }
  }

  Future<void> closeRoom(String roomId) async {
    if (!isAuthenticated) throw Exception('Not Authenticated');

    final response = await http.post(
      Uri.parse('$_baseUrl/admin/rooms/close'),
      headers: {'X-Admin-Key': _adminKey!, 'Content-Type': 'application/json'},
      body: json.encode({'roomId': roomId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to close room: ${response.statusCode}');
    }
  }
}
