import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/meal_media_repository.dart';

/// Renders an image stored in the `meal-images` bucket given its raw storage
/// path (e.g. `<userId>/<uuid>.jpg`). Resolves the path to a short-lived
/// signed URL via [MealMediaRepository.resolveSignedUrl] before handing it to
/// [CachedNetworkImage]. Used anywhere a persisted meal/recipe image needs to
/// render — recipe list tiles, recipe detail hero, recipe editor preview.
class SignedPathImage extends ConsumerStatefulWidget {
  const SignedPathImage({
    super.key,
    required this.pathOrUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  /// Raw storage path or an already-signed URL. Passing null renders the
  /// [errorWidget] immediately (no resolution attempt).
  final String? pathOrUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  ConsumerState<SignedPathImage> createState() => _SignedPathImageState();
}

class _SignedPathImageState extends ConsumerState<SignedPathImage> {
  String? _resolvedUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SignedPathImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pathOrUrl != widget.pathOrUrl) _resolve();
  }

  Future<void> _resolve() async {
    if (widget.pathOrUrl == null || widget.pathOrUrl!.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final url = await ref
        .read(mealMediaRepositoryProvider)
        .resolveSignedUrl(widget.pathOrUrl);
    if (mounted) {
      setState(() {
        _resolvedUrl = url;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.placeholder ?? const SizedBox.shrink();
    }
    if (_resolvedUrl == null) {
      return widget.errorWidget ?? const SizedBox.shrink();
    }
    return CachedNetworkImage(
      imageUrl: _resolvedUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: widget.placeholder == null
          ? null
          : (_, _) => widget.placeholder!,
      errorWidget: widget.errorWidget == null
          ? null
          : (_, _, _) => widget.errorWidget!,
    );
  }
}
