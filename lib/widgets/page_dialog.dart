import 'package:flutter/material.dart';

/// Show a page's content over the current screen so the user can look
/// something up and close straight back to where they were. Full screen on
/// phones, a large centered dialog on wider screens. [body] should scroll
/// on its own. It's built once the open animation finishes so a heavy page
/// doesn't make the animation stutter.
Future<T?> showPageDialog<T>(
  BuildContext context, {
  required String title,
  required Widget body,
  List<Widget> actions = const [],
}) {
  return showDialog<T>(
    context: context,
    builder: (context) {
      final size = MediaQuery.sizeOf(context);
      final page = Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: Text(title),
          actions: actions,
        ),
        body: _AfterOpen(child: body),
      );
      if (size.width < 600) return Dialog.fullscreen(child: page);
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: 900, maxHeight: size.height * 0.9),
          child: page,
        ),
      );
    },
  );
}

class _AfterOpen extends StatefulWidget {
  final Widget child;

  const _AfterOpen({required this.child});

  @override
  State<_AfterOpen> createState() => _AfterOpenState();
}

class _AfterOpenState extends State<_AfterOpen> {
  Animation<double>? _animation;
  bool _open = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animation != null) return;
    final a = ModalRoute.of(context)?.animation;
    if (a == null || a.isCompleted) {
      _open = true;
    } else {
      _animation = a..addStatusListener(_onStatus);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status.isCompleted && !_open) setState(() => _open = true);
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _open ? widget.child : const SizedBox.shrink();
}
