import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? trend;
  final bool trendUp;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor = const Color(0xFF4F6AFF),
    this.trend,
    this.trendUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trendUp ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 9,
                        color: trendUp ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend!,
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: trendUp ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D0D1A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 12,
              color: Color(0xFF6B6B8A),
            ),
          ),
        ],
      ),
    );
  }
}
