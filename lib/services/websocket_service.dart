import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/post.dart';

/// Servicio que mantiene la conexión WebSocket con el backend Spring.
/// Cuando otro usuario publica, llama a [onNewPost] con el Post recibido.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  // 🔁 Cambia esta URL si tu backend cambia de host
  static const String _wsUrl =
      'https://perros-social-backend.onrender.com/ws/websocket';

  StompClient? _client;
  bool _connected = false;

  /// Callback que FeedPage asigna para recibir nuevas publicaciones
  void Function(Post post)? onNewPost;

  void connect(String token) {
    if (_connected) return;

    _client = StompClient(
      config: StompConfig(
        url: _wsUrl,
        onConnect: _onConnect,
        onDisconnect: (_) {
          _connected = false;
        },
        onWebSocketError: (error) {
          _connected = false;
        },
        // Enviamos el JWT en el header de conexión STOMP
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    _connected = true;

    // Nos suscribimos al topic que el backend publica en cada nuevo post
    _client!.subscribe(
      destination: '/topic/posts',
      callback: (frame) {
        if (frame.body == null) return;
        try {
          final Map<String, dynamic> json = jsonDecode(frame.body!);
          final post = Post.fromJson(json);
          onNewPost?.call(post);
        } catch (_) {}
      },
    );
  }

  void disconnect() {
    _client?.deactivate();
    _connected = false;
    onNewPost = null;
  }
}
