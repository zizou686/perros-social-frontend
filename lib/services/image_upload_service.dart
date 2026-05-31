import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final String cloudName = 'dwhh2yudk';
  final String uploadPreset = 'dogs_app_preset';
  final String folder = 'dogs_app';

  Future<String> uploadImageBytes(Uint8List bytes, String filename) async {
    try {
      print('📤 Subiendo imagen a Cloudinary...');
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      );

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var responseString = String.fromCharCodes(responseData);
      var jsonResponse = json.decode(responseString);

      print('📥 Cloudinary response status: ${response.statusCode}');
      print('📥 Cloudinary response body: $responseString');

      if (response.statusCode == 200) {
        final String url = jsonResponse['secure_url'];
        print('✅ Imagen subida: $url');
        return url;
      } else {
        throw Exception('Error: ${response.statusCode} - $responseString');
      }
    } catch (e) {
      print('❌ Error en uploadImageBytes: $e');
      throw Exception('Error de conexión: $e');
    }
  }
}
