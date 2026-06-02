import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/post.dart';
import 'services/post_service.dart';
import 'services/like_service.dart';
import 'services/comment_service.dart';
import 'services/image_upload_service.dart';
import 'services/auth_service.dart';
import 'services/websocket_service.dart';
import 'screens/login_screen.dart';
import 'screens/post_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  runApp(MyApp(isLoggedIn: token != null && token.isNotEmpty));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Perros Social',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.brown),
      home: isLoggedIn ? const FeedPage() : const LoginScreen(),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final PostService _postService = PostService();
  final LikeService _likeService = LikeService();
  final CommentService _commentService = CommentService();
  final ImageUploadService _imageUploadService = ImageUploadService();
  final AuthService _authService = AuthService();
  final WebSocketService _wsService = WebSocketService();
  final ImagePicker _imagePicker = ImagePicker();

  List<Post> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAdmin = false;
  int _currentUserId = 0;

  Map<int, Map<String, dynamic>> _postReactions = {};

  final TextEditingController _contentController = TextEditingController();
  XFile? _selectedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPosts();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _contentController.dispose();
    super.dispose();
  }

  // ─── WebSocket ────────────────────────────────────────────────────────────

  Future<void> _connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    _wsService.onNewPost = (Post newPost) {
      // Solo insertamos si no es una publicación propia (ya la insertamos localmente)
      if (newPost.user?['id'] != _currentUserId) {
        if (mounted) {
          setState(() {
            // Evitar duplicados
            final exists = _posts.any((p) => p.id == newPost.id);
            if (!exists) {
              _posts.insert(0, newPost);
            }
          });
        }
      }
    };

    _wsService.connect(token);
  }

  // ─── Datos ────────────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final roles = prefs.getStringList('roles') ?? [];
    final userId = prefs.getInt('userId') ?? 0;
    setState(() {
      _isAdmin = roles.contains('ROLE_ADMIN');
      _currentUserId = userId;
    });
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final posts = await _postService.getPosts();
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cerrar Sesión')),
        ],
      ),
    );
    if (confirm == true) {
      _wsService.disconnect();
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  // ─── Imagen ───────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final XFile? image =
        await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _uploadedImageUrl = null;
        _isUploading = false;
      });
      await _uploadImageDirect();
    }
  }

  Future<void> _uploadImageDirect() async {
    if (_selectedImage == null) return;
    setState(() => _isUploading = true);
    try {
      final bytes = await _selectedImage!.readAsBytes();
      final imageUrl =
          await _imageUploadService.uploadImageBytes(bytes, _selectedImage!.name);
      setState(() {
        _uploadedImageUrl = imageUrl;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
    }
  }

  // ─── Publicación ──────────────────────────────────────────────────────────

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty && _uploadedImageUrl == null) return;

    try {
      final newPost = await _postService.createPost(
        _contentController.text.trim(),
        _uploadedImageUrl ?? '',
      );
      // Insertamos nuestra propia publicación localmente de inmediato
      setState(() {
        _posts.insert(0, newPost);
        _selectedImage = null;
        _uploadedImageUrl = null;
      });
      _contentController.clear();
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _toggleLike(Post post) async {
    try {
      final result = await _likeService.toggleLike(post.id);
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _posts[index] = Post(
            id: post.id,
            content: post.content,
            imageUrl: post.imageUrl,
            likesCount: result['likesCount'],
            commentsCount: post.commentsCount,
            createdAt: post.createdAt,
            user: post.user,
          );
        }
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _deletePost(Post post) async {
    try {
      await _postService.deletePost(post.id);
      setState(() {
        _posts.removeWhere((p) => p.id == post.id);
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  // ─── Reacciones ───────────────────────────────────────────────────────────

  void _showReactionSelector(Post post) async {
    try {
      final result = await _likeService.toggleLike(post.id);
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          _posts[index] = Post(
            id: post.id,
            content: post.content,
            imageUrl: post.imageUrl,
            likesCount: result['likesCount'],
            commentsCount: post.commentsCount,
            createdAt: post.createdAt,
            user: post.user,
          );
        }
      });
    } catch (e) {
      print('Error: $e');
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Reacciona a esta publicación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _reactionButton(post, '❤️'),
                  _reactionButton(post, '😂'),
                  _reactionButton(post, '😍'),
                  _reactionButton(post, '😲'),
                  _reactionButton(post, '😢'),
                  _reactionButton(post, '😡'),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
            ],
          ),
        );
      },
    );
  }

  Widget _reactionButton(Post post, String emoji) {
    final isSelected =
        _postReactions[post.id] != null &&
        _postReactions[post.id]!['reaction'] == emoji;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _postReactions.remove(post.id);
          } else {
            _postReactions[post.id] = {'reaction': emoji, 'liked': true};
          }
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(40),
          border: isSelected ? Border.all(color: Colors.blue) : null,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }

  // ─── UI helpers ───────────────────────────────────────────────────────────

  Widget _buildImage(String imageUrl) {
    return Center(
      child: SizedBox(
        width: 280,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            height: 400,
            width: 280,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 400,
              width: 280,
              color: Colors.grey.shade300,
              child: const Center(
                  child: Icon(Icons.broken_image, size: 40, color: Colors.red)),
            ),
          ),
        ),
      ),
    );
  }

  void _showCreatePostDialog() {
    setState(() {
      _selectedImage = null;
      _uploadedImageUrl = null;
      _isUploading = false;
    });
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.brown.shade50, Colors.orange.shade50]),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Nueva Publicación',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown)),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _contentController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                          hintText: '¿Qué pasa con tu perro?')),
                  const SizedBox(height: 12),
                  if (_selectedImage != null)
                    FutureBuilder<Uint8List>(
                      future: _selectedImage!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Container(
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                  image: MemoryImage(snapshot.data!),
                                  fit: BoxFit.cover),
                            ),
                          );
                        }
                        return const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()));
                      },
                    )
                  else
                    ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: const Text('Seleccionar imagen')),
                  if (_isUploading) const LinearProgressIndicator(),
                  if (_uploadedImageUrl != null)
                    const Text('✓ Imagen lista',
                        style: TextStyle(color: Colors.green)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: ElevatedButton(
                              onPressed: () async {
                                await _createPost();
                                Navigator.pop(context);
                              },
                              child: const Text('Publicar'))),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('🐕 Perros Social',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          // ✅ Botón de refresh eliminado — se reemplazó por WebSocket
          if (_isAdmin)
            IconButton(
                icon: const Icon(Icons.admin_panel_settings), onPressed: () {}),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPosts, // pull-to-refresh manual sigue disponible
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  final canDelete =
                      _isAdmin || (post.user?['id'] == _currentUserId);
                  final reaction = _postReactions[post.id];
                  final reactionEmoji =
                      reaction != null ? reaction['reaction'] as String? : null;

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                              child: Icon(Icons.pets,
                                  color: Colors.brown.shade700)),
                          title: Text(post.user?['username'] ?? 'Usuario',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(post.createdAt.length >= 10
                              ? post.createdAt.substring(0, 10)
                              : post.createdAt),
                          trailing: canDelete
                              ? IconButton(
                                  icon: Icon(Icons.delete,
                                      color: Colors.red.shade300),
                                  onPressed: () => _deletePost(post))
                              : null,
                        ),
                        Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(post.content)),
                        if (post.imageUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildImage(post.imageUrl)
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                    post.likesCount > 0
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 28),
                                onPressed: () => _showReactionSelector(post),
                              ),
                              Text('${post.likesCount}'),
                              if (reactionEmoji != null) ...[
                                const SizedBox(width: 12),
                                Text(reactionEmoji,
                                    style: const TextStyle(fontSize: 18))
                              ],
                              const SizedBox(width: 20),
                              IconButton(
                                icon: const Icon(Icons.comment),
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            PostDetailScreen(post: post))),
                              ),
                              Text('${post.commentsCount}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostDialog,
        backgroundColor: Colors.brown,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Publicación'),
      ),
    );
  }
}
