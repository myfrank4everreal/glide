import 'package:flutter/material.dart';
import 'package:glide/core/constants/app_constants.dart';

/// Full-width primary button sized for users who can't see the screen well.
/// The [label] is also what screen readers announce.
class LargeActionButton extends StatelessWidget {
  const LargeActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.hint,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Extra spoken description, e.g. what happens when the button is pressed.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    // MergeSemantics folds the hint into the button's own node, so the
    // screen reader announces one element that keeps its tap action.
    return MergeSemantics(
      child: Semantics(
        hint: hint,
        child: SizedBox(
          width: double.infinity,
          height: AppConstants.primaryButtonHeight,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 32),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}
