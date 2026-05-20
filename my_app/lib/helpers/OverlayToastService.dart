import 'package:flutter/material.dart';

class OverlayToastService {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String message,
    bool isError = true,
    Duration duration = const Duration(seconds: 3),
  }) {
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isError ? Colors.redAccent : Colors.orangeAccent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.warning_amber_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    _currentEntry = overlayEntry;
    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      if (overlayEntry == _currentEntry) {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
        _currentEntry = null;
      }
    });
  }
}
