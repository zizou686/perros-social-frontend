import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dog.dart';

class DogService {
  static final DogService _instance = DogService._internal();
  factory DogService() => _instance;
  DogService._internal();

  final String baseUrl = 'http://localhost:8080/api/dogs';

  // GET: Obtener todos los perros
  Future<List<Dog>> getDogs() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => Dog.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar perros: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // POST: Crear un nuevo perro
  Future<Dog> createDog(Dog dog) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': dog.name,
          'breed': dog.breed,
          'age': dog.age,
          'description': dog.description,
        }),
      );

      if (response.statusCode == 200) {
        return Dog.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error al crear perro: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // DELETE: Eliminar un perro por ID
  Future<void> deleteDog(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar perro: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // PUT: Actualizar un perro existente
  Future<Dog> updateDog(Dog dog) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/${dog.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': dog.name,
          'breed': dog.breed,
          'age': dog.age,
          'description': dog.description,
        }),
      );

      if (response.statusCode == 200) {
        return Dog.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error al actualizar perro: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
