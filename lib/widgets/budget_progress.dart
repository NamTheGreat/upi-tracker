import 'package:flutter/material.dart';

class BudgetProgress extends StatelessWidget {
  final String label;
  final double spent;
  final double limit;
  final double alertThreshold;
  final VoidCallback? onTap;

  const BudgetProgress({
    super.key,
    required this.label,
    required this.spent,
    required this.limit,
    this.alertThreshold = 0.8,
    this.onTap,
  });

  double get _progress => limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
  double get _percentage => limit > 0 ? (spent / limit * 100) : 0;

  Color get _progressColor {
    final ratio = limit > 0 ? spent / limit : 0;
    if (ratio >= 1.0) return Colors.red;
    if (ratio >= alertThreshold) return Colors.orange;
    if (ratio >= 0.5) return Colors.blue;
    return Colors.green;
  }

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
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                Text(
                  '₹${spent.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: _progressColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_percentage.toStringAsFixed(0)}% used',
              style: TextStyle(
                color: _progressColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}