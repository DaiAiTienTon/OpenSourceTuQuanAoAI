class AiSuggestion {
  final String id;
  final String userId;
  final String? destination;
  final String? healthTag;
  final String? weatherSnapshot;
  final String suggestionText;
  final String source; // 'rag' | 'worker' | 'heuristic'
  final bool? isHelpful;
  final String? savedOutfitId;
  final DateTime createdAt;

  const AiSuggestion({
    required this.id,
    required this.userId,
    this.destination,
    this.healthTag,
    this.weatherSnapshot,
    required this.suggestionText,
    required this.source,
    this.isHelpful,
    this.savedOutfitId,
    required this.createdAt,
  });

  factory AiSuggestion.fromJson(Map<String, dynamic> json) => AiSuggestion(
    id:              json['id'] as String,
    userId:          json['userId'] as String,
    destination:     json['destination'] as String?,
    healthTag:       json['healthTag'] as String?,
    weatherSnapshot: json['weatherSnapshot'] as String?,
    suggestionText:  json['suggestionText'] as String,
    source:          json['source'] as String? ?? 'worker',
    isHelpful:       json['isHelpful'] as bool?,
    savedOutfitId:   json['savedOutfitId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id':              id,
    'userId':          userId,
    'destination':     destination,
    'healthTag':       healthTag,
    'weatherSnapshot': weatherSnapshot,
    'suggestionText':  suggestionText,
    'source':          source,
    'isHelpful':       isHelpful,
    'savedOutfitId':   savedOutfitId,
    'createdAt':       createdAt.toIso8601String(),
  };

  AiSuggestion copyWith({bool? isHelpful, String? savedOutfitId}) =>
      AiSuggestion(
        id:              id,
        userId:          userId,
        destination:     destination,
        healthTag:       healthTag,
        weatherSnapshot: weatherSnapshot,
        suggestionText:  suggestionText,
        source:          source,
        isHelpful:       isHelpful ?? this.isHelpful,
        savedOutfitId:   savedOutfitId ?? this.savedOutfitId,
        createdAt:       createdAt,
      );
}