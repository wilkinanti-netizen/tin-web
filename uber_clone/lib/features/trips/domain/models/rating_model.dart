class Rating {
  final String id;
  final String tripId;
  final String raterId; // quien califica
  final String ratedId; // quien es calificado
  final int stars;
  final List<String> tags;
  final String? comment;
  final bool raterIsDriver; // true = conductor calificó al pasajero
  final DateTime createdAt;

  Rating({
    required this.id,
    required this.tripId,
    required this.raterId,
    required this.ratedId,
    required this.stars,
    required this.tags,
    this.comment,
    required this.raterIsDriver,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'rater_id': raterId,
    'rated_id': ratedId,
    'stars': stars,
    'tags': tags,
    'comment': comment,
    'rater_is_driver': raterIsDriver,
    'created_at': createdAt.toIso8601String(),
  };

  factory Rating.fromJson(Map<String, dynamic> json) => Rating(
    id: json['id'],
    tripId: json['trip_id'],
    raterId: json['rater_id'],
    ratedId: json['rated_id'],
    stars: json['stars'],
    tags: List<String>.from(json['tags'] ?? []),
    comment: json['comment'],
    raterIsDriver: json['rater_is_driver'] ?? false,
    createdAt: DateTime.parse(json['created_at']),
  );
}
