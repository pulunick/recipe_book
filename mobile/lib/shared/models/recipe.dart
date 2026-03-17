class Ingredient {
  final String name;
  final String? amount;
  final String? unit;
  final String category;

  const Ingredient({required this.name, this.amount, this.unit, required this.category});

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        name: j['name'] as String,
        amount: j['amount'] as String?,
        unit: j['unit'] as String?,
        category: j['category'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (amount != null) 'amount': amount,
        if (unit != null) 'unit': unit,
        'category': category,
      };
}

class RecipeStep {
  final int stepNumber;
  final String description;
  final String? timer;

  const RecipeStep({required this.stepNumber, required this.description, this.timer});

  factory RecipeStep.fromJson(Map<String, dynamic> j) => RecipeStep(
        stepNumber: j['step_number'] as int,
        description: j['description'] as String,
        timer: j['timer'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'step_number': stepNumber,
        'description': description,
        if (timer != null) 'timer': timer,
      };
}

class FlavorProfile {
  final double saltiness;
  final double sweetness;
  final double spiciness;
  final double sourness;
  final double oiliness;

  const FlavorProfile({
    required this.saltiness,
    required this.sweetness,
    required this.spiciness,
    required this.sourness,
    required this.oiliness,
  });

  factory FlavorProfile.fromJson(Map<String, dynamic> j) => FlavorProfile(
        saltiness: (j['saltiness'] as num).toDouble(),
        sweetness: (j['sweetness'] as num).toDouble(),
        spiciness: (j['spiciness'] as num).toDouble(),
        sourness: (j['sourness'] as num).toDouble(),
        oiliness: (j['oiliness'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'saltiness': saltiness,
        'sweetness': sweetness,
        'spiciness': spiciness,
        'sourness': sourness,
        'oiliness': oiliness,
      };
}

class Recipe {
  final int? id;
  final String title;
  final String? summary;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final FlavorProfile? flavor;
  final String? tip;
  final String? category;
  final String? videoId;
  final String? videoTitle;
  final String? channelName;
  final String? servings;
  final String? cookingTime;
  final String? difficulty;
  final String? source;
  final bool? isPublic;
  final int? calories;
  final int? cookingTimeMinutes;

  const Recipe({
    this.id,
    required this.title,
    this.summary,
    required this.ingredients,
    required this.steps,
    this.flavor,
    this.tip,
    this.category,
    this.videoId,
    this.videoTitle,
    this.channelName,
    this.servings,
    this.cookingTime,
    this.difficulty,
    this.source,
    this.isPublic,
    this.calories,
    this.cookingTimeMinutes,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as int?,
        title: j['title'] as String,
        summary: j['summary'] as String?,
        ingredients: (j['ingredients'] as List? ?? [])
            .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        steps: (j['steps'] as List? ?? [])
            .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        flavor: j['flavor'] != null
            ? FlavorProfile.fromJson(j['flavor'] as Map<String, dynamic>)
            : null,
        tip: j['tip'] as String?,
        category: j['category'] as String?,
        videoId: j['video_id'] as String?,
        videoTitle: j['video_title'] as String?,
        channelName: j['channel_name'] as String?,
        servings: j['servings'] as String?,
        cookingTime: j['cooking_time'] as String?,
        difficulty: j['difficulty'] as String?,
        source: j['source'] as String?,
        isPublic: j['is_public'] as bool?,
        calories: j['calories'] as int?,
        cookingTimeMinutes: j['cooking_time_minutes'] as int?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'title': title,
        if (summary != null) 'summary': summary,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        if (flavor != null) 'flavor': flavor!.toJson(),
        if (tip != null) 'tip': tip,
        if (category != null) 'category': category,
        if (videoId != null) 'video_id': videoId,
        if (videoTitle != null) 'video_title': videoTitle,
        if (channelName != null) 'channel_name': channelName,
        if (servings != null) 'servings': servings,
        if (cookingTime != null) 'cooking_time': cookingTime,
        if (difficulty != null) 'difficulty': difficulty,
        if (source != null) 'source': source,
        if (isPublic != null) 'is_public': isPublic,
        if (calories != null) 'calories': calories,
        if (cookingTimeMinutes != null) 'cooking_time_minutes': cookingTimeMinutes,
      };

  String? get thumbnailUrl =>
      videoId != null ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg' : null;

  bool get isYoutube => source == 'youtube';
}
