import 'package:flutter/material.dart';

class BudgetProgress extends StatelessWidget {
  final String label;
  final double spent;
  final double limit;
  final double alertThreshold;
  final VoidCallback? onTap;
  final String? suggestion; // "Move ₹200 from Entertainment?"

  const BudgetProgress({
    super.key,
    required this.label,
    required this.spent,
    required this.limit,
    this.alertThreshold = 0.8,
    this.onTap,
    this.suggestion,
  });

  double get _remaining => limit - spent;
  double get _progress => limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
  double get _percentage => limit > 0 ? (spent / limit * 100) : 0;

  bool get _isOver => _remaining < 0;
  bool get _isWarning => !_isOver && _percentage >= alertThreshold * 100;

  Color get _primaryColor {
    if (_isOver) return Colors.orange; // Action needed, not failure
    if (_isWarning) return Colors.blue; // Watch it
    if (_percentage >= 50) return Colors.green; // Healthy
    return Colors.green; // Safe
  }

  Color get _barColor {
    if (_isOver) return Colors.orange;
    if (_isWarning) return Colors.blue;
    return Colors.green;
  }

  String get _primaryText {
    if (_isOver) {
      return '₹${(-_remaining).toStringAsFixed(0)} over';
    }
    return '₹${_remaining.toStringAsFixed(0)} left';
  }

  String get _secondaryText => 'of ₹${limit.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _primaryText,
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      _secondaryText,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(_barColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_percentage.toStringAsFixed(0)}% used',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                  ),
                ),
                if (suggestion != null)
                  ActionChip(
                    label: Text(
                      suggestion!,
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.orange.shade50,
                    side: BorderSide(color: Colors.orange.shade200),
                    onPressed: () {}, // Handled by parent
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}