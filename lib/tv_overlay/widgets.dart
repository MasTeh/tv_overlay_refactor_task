import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../player/player_controller.dart';

extension TvKeyEventX on KeyEvent {
  bool get up => logicalKey == LogicalKeyboardKey.arrowUp;
  bool get down => logicalKey == LogicalKeyboardKey.arrowDown;

  bool get hasSubmitIntent =>
      this is KeyDownEvent &&
      (logicalKey == LogicalKeyboardKey.enter ||
          logicalKey == LogicalKeyboardKey.select);
}

class ScrollViewFocusScopeNode extends FocusScopeNode {
  ScrollViewFocusScopeNode({
    required this.enableAnimation,
    required this.onReached,
    super.debugLabel,
  }) : super(
         onKeyEvent: (node, event) {
           if (event is! KeyDownEvent) {
             return KeyEventResult.ignored;
           }

           if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
             onReached(AxisDirection.up);
             return KeyEventResult.handled;
           }

           if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
             onReached(AxisDirection.down);
             return KeyEventResult.handled;
           }

           return KeyEventResult.ignored;
         },
       );

  final ValueNotifier<bool> enableAnimation;
  final ValueChanged<AxisDirection> onReached;
}

class FocusWrapper extends StatefulWidget {
  const FocusWrapper({
    required this.onTap,
    required this.builder,
    this.autofocus = false,
    this.debugLabel,
    super.key,
  });

  final VoidCallback onTap;
  final bool autofocus;
  final String? debugLabel;
  final Widget Function(BuildContext context, bool hasFocus, Widget? child)
  builder;

  @override
  State<FocusWrapper> createState() => _FocusWrapperState();
}

class _FocusWrapperState extends State<FocusWrapper> {
  late final FocusNode _node = FocusNode(debugLabel: widget.debugLabel)
    ..addListener(_rebuild);

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _node
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: (_, event) {
        if (event.hasSubmitIntent) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.builder(context, _node.hasFocus, null),
      ),
    );
  }
}

class PlayerFocusDecoration extends StatelessWidget {
  const PlayerFocusDecoration({
    required this.hasFocus,
    required this.child,
    super.key,
  });

  final bool hasFocus;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: hasFocus ? Colors.white : Colors.white12,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasFocus ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
      child: IconTheme(
        data: IconThemeData(color: hasFocus ? Colors.black : Colors.white),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: hasFocus ? Colors.black : Colors.white),
          child: child,
        ),
      ),
    );
  }
}

class PlayerButton extends StatefulWidget {
  const PlayerButton({
    required this.focusNode,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final FocusNode focusNode;
  final VoidCallback onPressed;
  final Widget child;

  @override
  State<PlayerButton> createState() => _PlayerButtonState();
}

class _PlayerButtonState extends State<PlayerButton> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(PlayerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    oldWidget.focusNode.removeListener(_rebuild);
    widget.focusNode.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: PlayerFocusDecoration(
          hasFocus: widget.focusNode.hasFocus,
          child: widget.child,
        ),
      ),
    );
  }
}

class DefaultPlayerButton extends StatelessWidget {
  const DefaultPlayerButton({
    required this.title,
    required this.icon,
    required this.onTap,
    this.node,
    super.key,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final FocusNode? node;

  @override
  Widget build(BuildContext context) {
    if (node != null) {
      return PlayerButton(
        focusNode: node!,
        onPressed: onTap,
        child: _content(),
      );
    }

    return FocusWrapper(
      onTap: onTap,
      builder: (_, hasFocus, _) =>
          PlayerFocusDecoration(hasFocus: hasFocus, child: _content()),
    );
  }

  Widget _content() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon), const SizedBox(width: 8), Text(title)],
      ),
    );
  }
}

class FramePlayerProgressBar extends StatelessWidget {
  const FramePlayerProgressBar({
    required this.controller,
    required this.node,
    this.color,
    super.key,
  });

  final PlayerController controller;
  final FocusScopeNode node;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: node,
      child: PlayerFocusDecoration(
        hasFocus: node.hasFocus,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: PlayerProgressBar(
            position: controller.value.position,
            duration: controller.value.duration ?? Duration.zero,
          ),
        ),
      ),
    );
  }
}

class PlayerProgressBar extends StatelessWidget {
  const PlayerProgressBar({
    required this.position,
    required this.duration,
    super.key,
  });

  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds.toDouble();
    final current = position.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();

    return Row(
      children: [
        Text(formatDuration(position)),
        const SizedBox(width: 16),
        Expanded(
          child: LinearProgressIndicator(
            minHeight: 6,
            value: max == 0 ? 0 : current / max,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
          ),
        ),
        const SizedBox(width: 16),
        Text(formatDuration(duration)),
      ],
    );
  }
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final value =
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';

  return hours == 0 ? value : '${hours.toString().padLeft(2, '0')}:$value';
}
