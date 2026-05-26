class Budget {
  String category;
  double limit;
  double alertThreshold; // 0.0 to 1.0, default 0.8
  int month;
  int year;

  Budget({
    required this.category,
    required this.limit,
    this.alertThreshold = 0.8,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'limit': limit,
      'alertThreshold': alertThreshold,
      'month': month,
      'year': year,
    };
  }

  static Budget fromJson(Map<String, dynamic> json) {
    return Budget(
      category: json['category'],
      limit: json['limit'],
      alertThreshold: json['alertThreshold'] ?? 0.8,
      month: json['month'],
      year: json['year'],
    );
  }
}