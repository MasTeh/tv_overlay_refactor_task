import 'dart:async';

import 'package:flutter/material.dart' hide OverlayState;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'overlay_coordinator.dart';
import 'overlay_focus_registry.dart';
import 'overlay_machine.dart';

class TvOverlayView extends StatelessWidget {
  const TvOverlayView({
    required this.coordinator,
    required this.focusRegistry,
    required this.title,
    required this.playPauseIcon,
    required this.progress,
    super.key,
  });

  final OverlayCoordinator coordinator;
  final OverlayFocusRegistry focusRegistry;
  final Widget title;
  final Widget playPauseIcon;
  final Widget progress;

  @override
  Widget build(BuildContext context) {
    return BlocListener<OverlayCoordinator, OverlayState>(
      bloc: coordinator,
      listenWhen: (previous, current) =>
          previous.visibility != current.visibility ||
          previous.skipIntroAvailable != current.skipIntroAvailable,
      listener: (_, state) => focusRegistry.configure(
        overlayVisible: state.visibility == OverlayVisibility.visible,
        skipIntroAvailable: state.skipIntroAvailable,
      ),
      child: BlocBuilder<OverlayCoordinator, OverlayState>(
        bloc: coordinator,
        buildWhen: (previous, current) =>
            previous.visibility != current.visibility ||
            previous.playbackPhase != current.playbackPhase ||
            previous.skipIntroAvailable != current.skipIntroAvailable,
        builder: (context, state) {
          final visible = state.visibility == OverlayVisibility.visible;
          return Focus(
            focusNode: focusRegistry.nodeFor(OverlayFocusTarget.surface),
            onKeyEvent: (_, event) => _handleKey(event, state),
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  ignoring: !visible,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: visible ? 1 : 0,
                    child: const ColoredBox(color: Color(0x66000000)),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  left: 32,
                  right: 32,
                  top: visible ? 32 : -80,
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: ExcludeSemantics(
                      excluding: !visible,
                      child: _TopBar(
                        coordinator: coordinator,
                        focusRegistry: focusRegistry,
                        title: title,
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  left: 32,
                  right: 32,
                  bottom: visible ? 24 : -140,
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: ExcludeSemantics(
                      excluding: !visible,
                      child: _BottomBar(
                        coordinator: coordinator,
                        focusRegistry: focusRegistry,
                        playPauseIcon: playPauseIcon,
                        progress: progress,
                      ),
                    ),
                  ),
                ),
                if (state.skipIntroAvailable)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: 32,
                    bottom: visible ? 140 : 50,
                    child: OverlayButton(
                      target: OverlayFocusTarget.skipIntro,
                      coordinator: coordinator,
                      focusRegistry: focusRegistry,
                      child: const _LabeledButtonContent(
                        title: 'Skip intro',
                        icon: Icons.skip_next,
                      ),
                    ),
                  ),
                if (state.playbackPhase == PlaybackPhase.loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          );
        },
      ),
    );
  }

  KeyEventResult _handleKey(KeyEvent event, OverlayState state) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final command = _remoteCommandFor(event.logicalKey);
    if (command == null) return KeyEventResult.ignored;

    if (event is KeyRepeatEvent) {
      final repeatableSeek =
          state.focusedTarget == OverlayFocusTarget.progress &&
          (command == TvRemoteCommand.left || command == TvRemoteCommand.right);
      if (!repeatableSeek) return KeyEventResult.handled;
    }

    unawaited(coordinator.dispatch(RemoteCommandReceived(command)));
    return KeyEventResult.handled;
  }

  TvRemoteCommand? _remoteCommandFor(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return TvRemoteCommand.up;
    if (key == LogicalKeyboardKey.arrowDown) return TvRemoteCommand.down;
    if (key == LogicalKeyboardKey.arrowLeft) return TvRemoteCommand.left;
    if (key == LogicalKeyboardKey.arrowRight) return TvRemoteCommand.right;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
      return TvRemoteCommand.select;
    }
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.escape) {
      return TvRemoteCommand.back;
    }
    return null;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.coordinator,
    required this.focusRegistry,
    required this.title,
  });

  final OverlayCoordinator coordinator;
  final OverlayFocusRegistry focusRegistry;
  final Widget title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OverlayButton(
          target: OverlayFocusTarget.back,
          coordinator: coordinator,
          focusRegistry: focusRegistry,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Icon(Icons.arrow_back),
          ),
        ),
        const SizedBox(width: 12),
        DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          child: title,
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.coordinator,
    required this.focusRegistry,
    required this.playPauseIcon,
    required this.progress,
  });

  final OverlayCoordinator coordinator;
  final OverlayFocusRegistry focusRegistry;
  final Widget playPauseIcon;
  final Widget progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            OverlayButton(
              target: OverlayFocusTarget.playPause,
              coordinator: coordinator,
              focusRegistry: focusRegistry,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: IconTheme(
                  data: const IconThemeData(size: 30),
                  child: playPauseIcon,
                ),
              ),
            ),
            const Spacer(),
            OverlayButton(
              target: OverlayFocusTarget.audioSubtitles,
              coordinator: coordinator,
              focusRegistry: focusRegistry,
              child: const _LabeledButtonContent(
                title: 'Audio and subtitles',
                icon: Icons.subtitles,
              ),
            ),
            const SizedBox(width: 16),
            OverlayButton(
              target: OverlayFocusTarget.settings,
              coordinator: coordinator,
              focusRegistry: focusRegistry,
              child: const _LabeledButtonContent(
                title: 'Settings',
                icon: Icons.settings,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OverlayButton(
          target: OverlayFocusTarget.progress,
          coordinator: coordinator,
          focusRegistry: focusRegistry,
          expand: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: progress,
          ),
        ),
      ],
    );
  }
}

class OverlayButton extends StatelessWidget {
  const OverlayButton({
    required this.target,
    required this.coordinator,
    required this.focusRegistry,
    required this.child,
    this.expand = false,
    super.key,
  });

  final OverlayFocusTarget target;
  final OverlayCoordinator coordinator;
  final OverlayFocusRegistry focusRegistry;
  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final control = Focus(
      focusNode: focusRegistry.nodeFor(target),
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          unawaited(coordinator.dispatch(OverlayFocusChanged(target)));
        }
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                unawaited(coordinator.dispatch(OverlayTargetActivated(target))),
            child: PlayerFocusDecoration(hasFocus: hasFocus, child: child),
          );
        },
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: control) : control;
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

class _LabeledButtonContent extends StatelessWidget {
  const _LabeledButtonContent({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon), const SizedBox(width: 8), Text(title)],
      ),
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
