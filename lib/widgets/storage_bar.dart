import 'package:flutter/material.dart';
import 'package:swipewipe10/utils/theme.dart';

class StorageBar extends StatelessWidget {
  final String label;
  final double value; // A value between 0.0 and 1.0
  final Color barColor;
  final String? valueLabel;

  const StorageBar({
    super.key,
    required this.label,
    required this.value,
    this.barColor = kColorWhite,
    this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: textTheme.bodyMedium),
            if (valueLabel != null)
              Text(valueLabel!, style: textTheme.bodyMedium?.copyWith(color: kColorWhite)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value,
          backgroundColor: kColorGreyDark,
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
        ),
      ],
    );
  }
}