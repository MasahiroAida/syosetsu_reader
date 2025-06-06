class Review {
  final String id;
  final String novelTitle;
  final String summary;
  final double rating;
  final String reviewUrl;

  Review({
    required this.id,
    required this.novelTitle,
    required this.summary,
    required this.rating,
    required this.reviewUrl,
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] ?? '',
      novelTitle: map['novel_title'] ?? '',
      summary: map['summary'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      reviewUrl: map['review_url'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'novel_title': novelTitle,
      'summary': summary,
      'rating': rating,
      'review_url': reviewUrl,
    };
  }
}