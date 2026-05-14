import 'package:flutter/material.dart';

class AppFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const AppFloatingButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8E24AA), // Яркий фиолетовый
            Color(0xFF5E35B1), // Deep Purple
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}