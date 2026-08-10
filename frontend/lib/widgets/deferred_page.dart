import 'package:flutter/material.dart';

/// Defers building [child] until the route transition completes. Shows a
/// lightweight centered spinner for the duration of the push/pop animation so
/// heavy first-frame builds don't make page transitions feel janky.
class DeferredPage extends StatefulWidget {
  final Widget child;

  /// Optional custom loading UI. Defaults to a centered spinner.
  final Widget? loading;

  const DeferredPage({super.key, required this.child, this.loading});

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  bool _ready = false;

  // Cached so dispose() can remove the listener without looking up an
  // ancestor on a deactivated element (which throws).
  Animation<double>? _animation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animation = ModalRoute.of(context)?.animation;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
  }

  void _arm() {
    if (!mounted) return;
    final animation = _animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _setReady();
    } else {
      animation.addStatusListener(_onStatus);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _setReady();
  }

  void _setReady() {
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return widget.loading ??
          const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
    }
    return widget.child;
  }
}
