import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../utils/app_logger.dart';

class AdminService {
  static final AdminService _instance = AdminService._();
  static AdminService get instance => _instance;

  AdminService._();

  String get _baseUrl => AppConfig.instance.apiBaseUrl;

  // In a real app, this would be injected via dart-define or fetched securely
  String get _adminKey => const String.fromEnvironment(
    'ADMIN_API_KEY',
    defaultValue: 'veil-admin-secret-2024',
  );

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Admin-Key': _adminKey,
  };

  Future<Map<String, dynamic>> getServerStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/stats'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Admin API Error: getServerStats', exception: e);
      rethrow;
    }
  }

  Future<List<dynamic>> listRooms() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/rooms'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to list rooms: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Admin API Error: listRooms', exception: e);
      rethrow;
    }
  }

  Future<void> closeRoom(String roomId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/rooms/close?id=$roomId'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to close room: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Admin API Error: closeRoom', exception: e);
      rethrow;
    }
  }
}
