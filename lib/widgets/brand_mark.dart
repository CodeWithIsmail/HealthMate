import 'package:flutter/material.dart';

/// The app icon on a white tile.
///
/// White in both themes on purpose: the logo is a dark-outlined illustration,
/// so it needs a light ground to read against, and a consistent chip is what
/// makes it look like a brand rather than a stray image. Used by the splash
/// and both auth screens, which are the run of screens a new user sees first.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
  }
}
