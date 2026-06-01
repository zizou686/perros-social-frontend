import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/post.dart';
import 'services/post_service.dart';
import 'services/like_service.dart';
import 'services/comment_service.dart';
import 'services/image_upload_service.dart';
import 'services/auth_service.dart';
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
      theme: ThemeData(
        primarySwatch: Colors.brown,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: Brightness.light,
        ),
      ),
      home: isLoggedIn ? const FeedPage() : const LoginScreen(),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with WidgetsBindingObserver {
  final PostService _postService = PostService();
  final LikeService _likeService = LikeService();
  final CommentService _commentService = CommentService();
  final ImageUploadService _imageUploadService = ImageUploadService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  bool _isAdmin = false;
  int _currentUserId = 0;
  Timer? _autoRefreshTimer;

  final TextEditingController _contentController = TextEditingController();
  XFile? _selectedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _loadPosts();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    WidgetsBinding.instance.removeObserver(this);
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoRefresh();
      _loadPosts();
    } else {
      _stopAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _stopAutoRefresh();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      print('🔄 Recargando automáticamente cada 15 segundos...');
      _loadPosts(showLoading: false);
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final roles = prefs.getStringList('roles') ?? [];
    final userId = prefs.getInt('userId') ?? 0;
    print('🔍 Roles del usuario: $roles');
    print('🔍 Es admin? ${roles.contains('ROLE_ADMIN')}');
    setState(() {
      _isAdmin = roles.contains('ROLE_ADMIN');
      _currentUserId = userId;
    });
  }

  Future<void> _loadPosts({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isRefreshing = true;
      });
    }
    
    try {
      final posts = await _postService.getPosts();
      print('✅ Posts cargados: ${posts.length}');
      setState(() {
        _posts = posts;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      print('❌ Error al cargar posts: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _stopAutoRefresh();
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
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
    
    setState(() {
      _isUploading = true;
    });
    
    try {
      final bytes = await _selectedImage!.readAsBytes();
      final imageUrl = await _imageUploadService.uploadImageBytes(bytes, _selectedImage!.name);
      print('✅ URL de imagen subida: $imageUrl');
      setState(() {
        _uploadedImageUrl = imageUrl;
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🖼️ Imagen subida correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error al subir imagen: $e');
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty && _uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe algo o sube una imagen'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    print('📝 Creando post con imagen URL: $_uploadedImageUrl');

    try {
      final newPost = await _postService.createPost(
        _contentController.text.trim(),
        _uploadedImageUrl ?? '',
      );
      print('✅ Post creado con imageUrl: ${newPost.imageUrl}');
      setState(() {
        _posts.insert(0, newPost);
        _selectedImage = null;
        _uploadedImageUrl = null;
      });
      _contentController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📝 Publicación creada'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error al crear post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleLike(Post post) async {
    try {
      print('🔄 Dando like al post: ${post.id}');
      final result = await _likeService.toggleLike(post.id);
      print('✅ Resultado like: $result');
      
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
      print('❌ Error en toggleLike: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al dar like: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deletePost(Post post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar publicación'),
        content: Text('¿Estás seguro de que quieres eliminar esta publicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _postService.deletePost(post.id);
        print('✅ Post eliminado: ${post.id}');
        setState(() {
          _posts.removeWhere((p) => p.id == post.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Publicación eliminada'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        await _loadPosts(showLoading: false);
      } catch (e) {
        print('❌ Error al eliminar: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey.shade300,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            width: double.infinity,
            color: Colors.grey.shade300,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 40, color: Colors.red),
                  SizedBox(height: 8),
                  Text('No se pudo cargar la imagen', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        },
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
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.brown.shade50, Colors.orange.shade50],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit, color: Colors.brown, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Nueva Publicación',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _contentController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: '¿Qué está pasando con tu perro?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  if (_selectedImage != null) ...[
                    FutureBuilder<Uint8List>(
                      future: _selectedImage!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: MemoryImage(snapshot.data!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        }
                        return Container(
                          height: 150,
                          width: double.infinity,
                          color: Colors.grey.shade300,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedImage = null;
                                _uploadedImageUrl = null;
                                _isUploading = false;
                              });
                              setDialogState(() {});
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('Quitar imagen'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _pickImage();
                              setDialogState(() {});
                            },
                            icon: const Icon(Icons.image),
                            label: const Text('Seleccionar imagen'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  if (_isUploading) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 4),
                    const Text('Subiendo imagen a Cloudinary...', textAlign: TextAlign.center),
                  ] else if (_uploadedImageUrl != null && _selectedImage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '✓ Imagen subida correctamente',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedImage = null;
                              _uploadedImageUrl = null;
                              _isUploading = false;
                            });
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await _createPost();
                            Navigator.pop(context);
                            setState(() {
                              _selectedImage = null;
                              _uploadedImageUrl = null;
                              _isUploading = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send),
                              SizedBox(width: 8),
                              Text('Publicar'),
                            ],
                          ),
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          '🐕 Perros Social',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.brown, Colors.orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadPosts(),
            tooltip: 'Recargar',
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('👑 Eres administrador. Puedes eliminar cualquier publicación.'),
                    backgroundColor: Colors.brown,
                  ),
                );
              },
              tooltip: 'Admin',
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.brown),
                  SizedBox(height: 16),
                  Text('Cargando publicaciones...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadPosts(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown,
                        ),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pets, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No hay publicaciones',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '¡Sé el primero en publicar!',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadPosts(showLoading: false),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          final bool canDelete = _isAdmin || (post.user?['id'] == _currentUserId);
                          
                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white,
                                    Colors.orange.shade50,
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.all(12),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.brown.shade100,
                                      child: Icon(
                                        Icons.pets,
                                        color: Colors.brown.shade700,
                                      ),
                                    ),
                                    title: Text(
                                      post.user?['username'] ?? 'Usuario',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      post.createdAt.substring(0, 10),
                                      style: TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                    trailing: canDelete
                                        ? IconButton(
                                            icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                                            onPressed: () => _deletePost(post),
                                            tooltip: 'Eliminar',
                                          )
                                        : null,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      post.content,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                  if (post.imageUrl.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: _buildImage(post.imageUrl),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.favorite,
                                            color: post.likesCount > 0 ? Colors.red : Colors.grey,
                                          ),
                                          onPressed: () => _toggleLike(post),
                                        ),
                                        Text('${post.likesCount} Me gusta'),
                                        const SizedBox(width: 20),
                                        IconButton(
                                          icon: const Icon(Icons.comment),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => PostDetailScreen(post: post),
                                              ),
                                            );
                                          },
                                        ),
                                        Text('${post.commentsCount} Comentarios'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePostDialog,
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Publicación'),
        elevation: 4,
      ),
    );
  }
}
