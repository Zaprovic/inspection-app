class Inspection {
  int? id;
  String title;
  String description;
  DateTime date;
  List<double> location; // [latitude, longitude]

  Inspection({
    this.id, // optional
    required this.title,
    required this.description,
    required this.date,
    required this.location,
  });

  // Copy constructor for editing
  Inspection copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? date,
    List<double>? location,
  }) {
    return Inspection(
      id: id ?? this.id, // used when updating
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      location: location ?? List.from(this.location),
    );
  }
}
