import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post.dart';

class PostService {
  static final PostService _instance = PostService._internal();
  factory PostService() => _instance;
  PostService._internal();

  final String baseUrl = 'http://localhost:8080/api';

  // Obtener token almacenado
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // GET: Obtener todas las publicaciones
  Future<List<Post>> getPosts() async {
    try {
      final token = await _getToken();
      print('📤 GET Posts - Token: ${token != null ? "Token presente" : "No token"}');
      
      final response = await http.get(
        Uri.parse('$baseUrl/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📥 GET Posts - Status: ${response.statusCode}');
      print('📥 GET Posts - Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        
        if (jsonResponse.containsKey('content')) {
          List<dynamic> data = jsonResponse['content'];
          List<Post> posts = [];
          for (var item in data) {
            posts.add(Post.fromJson(item));
          }
          return posts;
        } else {
          return [];
        }
      } else if (response.statusCode == 401) {
        throw Exception('No autorizado. Por favor, inicia sesión nuevamente.');
      } else {
        throw Exception('Error al cargar publicaciones: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getPosts: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // POST: Crear una nueva publicación
  Future<Post> createPost(String content, String imageUrl) async {
    try {
      final token = await _getToken();
      print('📤 POST Post - Token: ${token != null ? "Token presente" : "No token"}');
      print('📤 POST Post - Content: $content');
      print('📤 POST Post - ImageUrl: $imageUrl');
      
      final response = await http.post(
        Uri.parse('$baseUrl/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'content': content,
          'imageUrl': imageUrl,
        }),
      );

      print('📥 POST Post - Status: ${response.statusCode}');
      print('📥 POST Post - Body: ${response.body}');

      if (response.statusCode == 200) {
        return Post.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('No autorizado. Por favor, inicia sesión nuevamente.');
      } else {
        throw Exception('Error al crear publicación: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en createPost: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // DELETE: Eliminar una publicación
  Future<void> deletePost(int id) async {
    try {
      final token = await _getToken();
      print('🗑️ DELETE Post - ID: $id');
      print('🗑️ DELETE Post - Token: ${token != null ? "Token presente" : "No token"}');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('📥 DELETE Post - Status: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('No autorizado. Por favor, inicia sesión nuevamente.');
      } else if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar publicación: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en deletePost: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
