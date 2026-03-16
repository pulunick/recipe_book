class RecipePublicItem {
  final int id;
  final String title;
  final String? summary;
  final String? category;
  final String? cookingTime;
  final String? difficulty;
  final String? servings;
  final String? videoId;
  final String? channelName;
  final String createdAt;
  final int? myCollectionId;
  final String? source; // 'youtube' | 'text'
  final int? calories;
  final int? cookingTimeMinutes;

  const RecipePublicItem({
    required this.id,
    required this.title,
    this.summary,
    this.category,
    this.cookingTime,
    this.difficulty,
    this.servings,
    this.videoId,
    this.channelName,
    required this.createdAt,
    this.myCollectionId,
    this.source,
    this.calories,
    this.cookingTimeMinutes,
  });

  factory RecipePublicItem.fromJson(Map<String, dynamic> json) {
    return RecipePublicItem(
      id: json['id'] as int,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      category: json['category'] as String?,
      cookingTime: json['cooking_time'] as String?,
      difficulty: json['difficulty'] as String?,
      servings: json['servings'] as String?,
      videoId: json['video_id'] as String?,
      channelName: json['channel_name'] as String?,
      createdAt: json['created_at'] as String,
      myCollectionId: json['my_collection_id'] as int?,
      source: json['source'] as String?,
      calories: json['calories'] as int?,
      cookingTimeMinutes: json['cooking_time_minutes'] as int?,
    );
  }

  // 유튜브 썸네일 URL
  String? get thumbnailUrl => videoId != null
      ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg'
      : null;

  bool get isCollected => myCollectionId != null;
  bool get isYoutube => source == 'youtube';

  RecipePublicItem copyWith({int? Function()? myCollectionId}) {
    return RecipePublicItem(
      id: id,
      title: title,
      summary: summary,
      category: category,
      cookingTime: cookingTime,
      difficulty: difficulty,
      servings: servings,
      videoId: videoId,
      channelName: channelName,
      createdAt: createdAt,
      myCollectionId: myCollectionId != null ? myCollectionId() : this.myCollectionId,
      source: source,
      calories: calories,
      cookingTimeMinutes: cookingTimeMinutes,
    );
  }
}
