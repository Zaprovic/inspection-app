class Inspection {
  int? id;
  String title;
  String description;
  DateTime date;
  List<double> location; // [latitude, longitude]
  String status; // "Pendiente de sincronización" or "Sincronizada"

  Inspection({
    this.id, // optional
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    this.status = "Pendiente de sincronización", // Default status
  });

  // Copy constructor for editing
  Inspection copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? date,
    List<double>? location,
    String? status,
  }) {
    return Inspection(
      id: id ?? this.id, // used when updating
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      location: location ?? List.from(this.location),
      status: status ?? this.status,
    );
  }
}
