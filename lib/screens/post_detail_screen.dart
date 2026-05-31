import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/comment_service.dart';
import '../services/like_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final CommentService _commentService = CommentService();
  final LikeService _likeService = LikeService();
  
  late Post _post;
  List<Comment> _comments = [];
  bool _isLoading = true;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _commentService.getCommentsByPost(_post.id);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final newComment = await _commentService.createComment(
        _post.id,
        _commentController.text.trim(),
      );
      setState(() {
        _comments.insert(0, newComment);
        _post = Post(
          id: _post.id,
          content: _post.content,
          imageUrl: _post.imageUrl,
          likesCount: _post.likesCount,
          commentsCount: _post.commentsCount + 1,
          createdAt: _post.createdAt,
          user: _post.user,
        );
      });
      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleLike() async {
    try {
      final result = await _likeService.toggleLike(_post.id);
      setState(() {
        _post = Post(
          id: _post.id,
          content: _post.content,
          imageUrl: _post.imageUrl,
          likesCount: result['likesCount'],
          commentsCount: _post.commentsCount,
          createdAt: _post.createdAt,
          user: _post.user,
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicación'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Tarjeta del Post
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: _post.user != null && _post.user!['avatarUrl'] != null
                            ? NetworkImage(_post.user!['avatarUrl'])
                            : null,
                        child: const Icon(Icons.person),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _post.user?['username'] ?? 'Usuario',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _post.createdAt.substring(0, 10),
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_post.content),
                  if (_post.imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Image.network(_post.imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.favorite, color: _post.likesCount > 0 ? Colors.red : Colors.grey),
                        onPressed: _toggleLike,
                      ),
                      Text('${_post.likesCount}'),
                      const SizedBox(width: 20),
                      const Icon(Icons.comment),
                      const SizedBox(width: 5),
                      Text('${_comments.length}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Lista de Comentarios
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('No hay comentarios. Sé el primero en comentar.'))
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              radius: 15,
                              child: Icon(Icons.person, size: 15),
                            ),
                            title: Text(comment.user?['username'] ?? 'Usuario'),
                            subtitle: Text(comment.content),
                            trailing: Text(
                              comment.createdAt.substring(0, 10),
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          );
                        },
                      ),
          ),
          
          // Campo para escribir comentario
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.brown,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _addComment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
