import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/config/app_config.dart';

class AdminRepository {
  // Base URL from config
  String get _baseUrl {
    return AppConfig.instance.apiBaseUrl;
  }

  // Returns headers with Firebase ID Token
  Future<Map<String, String>> _getAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final token = await user.getIdToken();
    if (token == null) throw Exception('Failed to get ID token');

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<void> ping() async {
    final url = '$_baseUrl/admin/ping';
    debugPrint('🚀 [ADMIN] Pinging: $url');
    final start = DateTime.now();
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      final duration = DateTime.now().difference(start).inMilliseconds;
      debugPrint(
        '🚀 [ADMIN] Ping Response (${duration}ms): ${response.statusCode}',
      );
      if (response.statusCode != 200) {
        throw Exception('Ping failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🚀 [ADMIN] Ping Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    final headers = await _getAuthHeaders();
    final url = '$_baseUrl/admin/stats';
    debugPrint('🚀 [ADMIN] Fetching Stats... ($url)');
    final start = DateTime.now();
    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));

      final duration = DateTime.now().difference(start).inMilliseconds;
      debugPrint(
        '🚀 [ADMIN] Stats Response (${duration}ms): ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('🚀 [ADMIN] Stats Error Body: ${response.body}');
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🚀 [ADMIN] Stats Exception: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getRooms() async {
    final headers = await _getAuthHeaders();
    final url = '$_baseUrl/admin/rooms';
    debugPrint('🚀 [ADMIN] Fetching Rooms... ($url)');
    final start = DateTime.now();
    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));

      final duration = DateTime.now().difference(start).inMilliseconds;
      debugPrint(
        '🚀 [ADMIN] Rooms Response (${duration}ms): ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        debugPrint('🚀 [ADMIN] Rooms Error Body: ${response.body}');
        throw Exception('Failed to load rooms: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🚀 [ADMIN] Rooms Exception: $e');
      rethrow;
    }
  }

  Future<void> closeRoom(String roomId) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/rooms/close'),
      headers: headers,
      body: json.encode({'roomId': roomId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to close room: ${response.statusCode}');
    }
  }

  Future<void> broadcastMessage(String message) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/broadcast'),
      headers: headers,
      body: json.encode({'message': message}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to broadcast: ${response.statusCode}');
    }
  }

  Future<void> banUser(String userId) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/users/ban'),
      headers: headers,
      body: json.encode({'userId': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to ban user: ${response.statusCode}');
    }
  }
}
