class AiEvaluation {
  final String id;
  final String userId;
  final String topItemId;
  final String topItemName;
  final String bottomItemId;
  final String bottomItemName;
  final String? destination;
  final String? healthTag;
  final String? weatherSnapshot;
  final String evaluationText;
  final int? userRating; // 1–5
  final DateTime createdAt;

  const AiEvaluation({
    required this.id,
    required this.userId,
    required this.topItemId,
    required this.topItemName,
    required this.bottomItemId,
    required this.bottomItemName,
    this.destination,
    this.healthTag,
    this.weatherSnapshot,
    required this.evaluationText,
    this.userRating,
    required this.createdAt,
  });

  factory AiEvaluation.fromJson(Map<String, dynamic> json) => AiEvaluation(
    id:             json['id'] as String,
    userId:         json['userId'] as String,
    topItemId:      json['topItemId'] as String,
    topItemName:    json['topItemName'] as String,
    bottomItemId:   json['bottomItemId'] as String,
    bottomItemName: json['bottomItemName'] as String,
    destination:    json['destination'] as String?,
    healthTag:      json['healthTag'] as String?,
    weatherSnapshot:json['weatherSnapshot'] as String?,
    evaluationText: json['evaluationText'] as String,
    userRating:     json['userRating'] as int?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id':             id,
    'userId':         userId,
    'topItemId':      topItemId,
    'topItemName':    topItemName,
    'bottomItemId':   bottomItemId,
    'bottomItemName': bottomItemName,
    'destination':    destination,
    'healthTag':      healthTag,
    'weatherSnapshot':weatherSnapshot,
    'evaluationText': evaluationText,
    'userRating':     userRating,
    'createdAt':      createdAt.toIso8601String(),
  };

  AiEvaluation copyWith({int? userRating}) => AiEvaluation(
    id:             id,
    userId:         userId,
    topItemId:      topItemId,
    topItemName:    topItemName,
    bottomItemId:   bottomItemId,
    bottomItemName: bottomItemName,
    destination:    destination,
    healthTag:      healthTag,
    weatherSnapshot:weatherSnapshot,
    evaluationText: evaluationText,
    userRating:     userRating ?? this.userRating,
    createdAt:      createdAt,
  );
}