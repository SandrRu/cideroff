class BatchRecipeLink {
  final String batchId;
  final String recipeId;
  final int sequenceOrder;
  final String assignedAt;
  final String? notes;

  const BatchRecipeLink({
    required this.batchId,
    required this.recipeId,
    required this.sequenceOrder,
    required this.assignedAt,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'batch_id': batchId,
      'recipe_id': recipeId,
      'sequence_order': sequenceOrder,
      'assigned_at': assignedAt,
      'notes': notes,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory BatchRecipeLink.fromJson(Map<String, dynamic> json) {
    return BatchRecipeLink(
      batchId: json['batch_id'] as String,
      recipeId: json['recipe_id'] as String,
      sequenceOrder: json['sequence_order'] as int,
      assignedAt: json['assigned_at'] as String,
      notes: json['notes'] as String?,
    );
  }

  BatchRecipeLink copyWith({
    String? batchId,
    String? recipeId,
    int? sequenceOrder,
    String? assignedAt,
    String? notes,
  }) {
    return BatchRecipeLink(
      batchId: batchId ?? this.batchId,
      recipeId: recipeId ?? this.recipeId,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
      assignedAt: assignedAt ?? this.assignedAt,
      notes: notes ?? this.notes,
    );
  }
}
