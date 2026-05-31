import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LikeService {
  static final LikeService _instance = LikeService._internal();
  factory LikeService() => _instance;
  LikeService._internal();

  final String baseUrl = 'http://localhost:8080/api';

  // Obtener token almacenado
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // POST: Dar o quitar like a una publicación
  Future<Map<String, dynamic>> toggleLike(int postId) async {
    try {
      final token = await _getToken();
      print('🔄 Toggle like - Post ID: $postId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/likes/$postId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📥 Like response status: ${response.statusCode}');
      print('📥 Like response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('No autorizado. Por favor, inicia sesión nuevamente.');
      } else {
        throw Exception('Error al dar like: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en toggleLike: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
