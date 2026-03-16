class CartItem {
  final int id;
  final int? collectionId;
  final String? recipeTitle;
  final String ingredientName;
  final String? amount;
  final String? unit;
  final String category;
  final bool isChecked;

  const CartItem({
    required this.id,
    this.collectionId,
    this.recipeTitle,
    required this.ingredientName,
    this.amount,
    this.unit,
    required this.category,
    required this.isChecked,
  });

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        id: j['id'] as int,
        collectionId: j['collection_id'] as int?,
        recipeTitle: j['recipe_title'] as String?,
        ingredientName: j['ingredient_name'] as String,
        amount: j['amount'] as String?,
        unit: j['unit'] as String?,
        category: j['category'] as String? ?? '',
        isChecked: j['is_checked'] as bool? ?? false,
      );

  CartItem copyWith({bool? isChecked}) => CartItem(
        id: id,
        collectionId: collectionId,
        recipeTitle: recipeTitle,
        ingredientName: ingredientName,
        amount: amount,
        unit: unit,
        category: category,
        isChecked: isChecked ?? this.isChecked,
      );

  String get displayAmount {
    if (amount != null && unit != null) return '$amount $unit';
    if (amount != null) return amount!;
    return '';
  }
}

class CartGroup {
  final int? collectionId;
  final String? recipeTitle;
  final List<CartItem> items;

  const CartGroup({this.collectionId, this.recipeTitle, required this.items});

  factory CartGroup.fromJson(Map<String, dynamic> j) => CartGroup(
        collectionId: j['collection_id'] as int?,
        recipeTitle: j['recipe_title'] as String?,
        items: (j['items'] as List)
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
