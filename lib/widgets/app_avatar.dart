import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.imageUrl, this.size = 40});

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: colorScheme.primaryContainer, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials(name),
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.36,
        ),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
