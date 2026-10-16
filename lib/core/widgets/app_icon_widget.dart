import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/native_bridge_service.dart';
import '../theme/jeda_colors.dart';
import '../theme/jeda_radii.dart';

/// Reusable widget to display the native application icon of an installed app.
/// Uses in-memory caching to ensure instant, flicker-free rendering once loaded.
class AppIconWidget extends ConsumerStatefulWidget {
  final String packageName;
  final double size;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? fallbackIconColor;

  const AppIconWidget({
    super.key,
    required this.packageName,
    this.size = 40,
    this.borderRadius,
    this.backgroundColor,
    this.fallbackIconColor,
  });

  /// In-memory cache across the application session.
  static final Map<String, Uint8List?> _cache = {};
  static final Map<String, Future<Uint8List?>> _pending = {};

  @override
  ConsumerState<AppIconWidget> createState() => _AppIconWidgetState();
}

class _AppIconWidgetState extends ConsumerState<AppIconWidget> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadIcon();
  }

  @override
  void didUpdateWidget(covariant AppIconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) {
      _loadIcon();
    }
  }

  void _loadIcon() {
    final pkg = widget.packageName.trim();
    if (pkg.isEmpty) {
      _bytes = null;
      return;
    }

    if (AppIconWidget._cache.containsKey(pkg)) {
      _bytes = AppIconWidget._cache[pkg];
      return;
    }

    final nativeBridge = ref.read(nativeBridgeServiceProvider);
    final future = AppIconWidget._pending.putIfAbsent(
      pkg,
      () => nativeBridge.getAppIcon(pkg).then((bytes) {
        AppIconWidget._cache[pkg] = bytes;
        AppIconWidget._pending.remove(pkg);
        return bytes;
      }),
    );

    future.then((bytes) {
      if (mounted) {
        setState(() {
          _bytes = bytes;
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _bytes = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? JedaRadii.borderR12;
    final bg = widget.backgroundColor ?? JedaColors.surfaceSecondary;
    final fallbackColor = widget.fallbackIconColor ?? JedaColors.textSecondary;

    if (_bytes != null && _bytes!.isNotEmpty) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: bg,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.memory(
          _bytes!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallback(radius, bg, fallbackColor);
          },
        ),
      );
    }

    return _buildFallback(radius, bg, fallbackColor);
  }

  Widget _buildFallback(BorderRadius radius, Color bg, Color iconColor) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
      ),
      child: Center(
        child: Icon(
          Icons.apps_outlined,
          size: widget.size * 0.5,
          color: iconColor,
        ),
      ),
    );
  }
}
