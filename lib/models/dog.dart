class Dog {
  final int id;
  final String name;
  final String breed;
  final int age;
  final String description;

  Dog({
    required this.id,
    required this.name,
    required this.breed,
    required this.age,
    required this.description,
  });

  // Convertir JSON a Dog
  factory Dog.fromJson(Map<String, dynamic> json) {
    return Dog(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      breed: json['breed'] ?? '',
      age: json['age'] ?? 0,
      description: json['description'] ?? '',
    );
  }

  // Convertir Dog a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'breed': breed,
      'age': age,
      'description': description,
    };
  }

  @override
  String toString() => 'Dog(id: $id, name: $name, breed: $breed, age: $age)';
}
