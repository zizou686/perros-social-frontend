import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/comment.dart';

class CommentService {
  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;
  CommentService._internal();

  final String baseUrl = 'https://perros-social-backend.onrender.com/api';

  // Obtener token almacenado
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // GET: Obtener comentarios de un post
  Future<List<Comment>> getCommentsByPost(int postId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/posts/$postId/comments'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('📥 GET Comments - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        if (data is List) {
          List<Comment> comments = [];
          for (var item in data) {
            comments.add(Comment.fromJson(item));
          }
          return comments;
        } else if (data is Map && data.containsKey('content')) {
          List<dynamic> list = data['content'];
          List<Comment> comments = [];
          for (var item in list) {
            comments.add(Comment.fromJson(item));
          }
          return comments;
        } else {
          return [];
        }
      } else if (response.statusCode == 401) {
        throw Exception('No autorizado. Por favor, inicia sesión nuevamente.');
      } else {
        throw Exception('Error al cargar comentarios: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getCommentsByPost: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // POST: Crear un comentario
  Future<Comment> createComment(int postId, String content) async {
    try {
      final token = await _getToken();
      print('📤 POST Comment - Post ID: $postId, Content: $content');
      
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'content': content}),
      );

      print('📥 POST Comment - Status: ${response.statusCode}');
      print('📥 POST Comment - Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Comment.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('No autorizado. Por favor, inicia sesión nuevamente.');
      } else {
        throw Exception('Error al crear comentario: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en createComment: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // DELETE: Eliminar un comentario
  Future<void> deleteComment(int commentId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/comments/$commentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('🗑️ DELETE Comment - Status: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('No autorizado. Por favor, inicia sesión nuevamente.');
      } else if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar comentario: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en deleteComment: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
