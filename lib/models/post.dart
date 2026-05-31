class Post {
  final int id;
  final String content;
  final String imageUrl;
  final int likesCount;
  final int commentsCount;
  final String createdAt;
  final Map<String, dynamic>? user;

  Post({
    required this.id,
    required this.content,
    required this.imageUrl,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    this.user,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      user: json['user'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'imageUrl': imageUrl,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'createdAt': createdAt,
      'user': user,
    };
  }
}
