// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../player/player_bloc.dart';
import '../player/player_controller.dart';
import 'tv_bottom_overlay.dart';
import 'widgets.dart';

class TvOverlayOld extends StatefulWidget {
  const TvOverlayOld({super.key});

  @override
  State<TvOverlayOld> createState() => _TvOverlayOldState();
}

class _TvOverlayOldState extends State<TvOverlayOld> {
  late PlayerBloc bloc = context.read<PlayerBloc>();
  Duration? _lastPositionUpdate;
  DateTime? _lastKeyEvent;

  static const _positionUpdateThrottle = Duration(seconds: 1);
  static const _keyEventDebounce = Duration(milliseconds: 50);

  bool _lastOverlayState = false;
  bool _lastPlayingState = false;
  bool _lastInitializedState = false;
  bool _lastLoadingState = false;

  PlayerValue get _value => bloc.state.value!;
  PlayerController get _controller => bloc.state.controller!;

  late final _skipFocusNode = FocusNode(
    debugLabel: 'skip_focus_scope_node',
    onKeyEvent: _skipEvent,
  );

  KeyEventResult _skipEvent(FocusNode node, KeyEvent key) {
    if (key.up) {
      _backButtonFocusNode.requestFocus();
      setState(() {});
    }
    return KeyEventResult.ignored;
  }

  late final _backButtonFocusNode = FocusNode(
    debugLabel: 'back_focus_scope_node',
    onKeyEvent: (node, key) {
      setState(() {});
      if (!_value.showOverlay && _value.isPlaying) {
        return KeyEventResult.ignored;
      }
      if (key.down) {
        _showSkipIntro ? _skipFocusNode.requestFocus() : _focusPlayPause();
        return KeyEventResult.handled;
      }
      if (key.hasSubmitIntent) {
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    },
  );

  late final _actionsFocusNode = ScrollViewFocusScopeNode(
    enableAnimation: ValueNotifier(false),
    debugLabel: 'actions_focus_scope_node',
    onReached: _actionListener,
  );

  void _focusPlayPause() {
    _actionsFocusNode.children
        .where((node) => node.debugLabel == 'action')
        .firstOrNull
        ?.requestFocus();
  }

  void _actionListener(AxisDirection axis) {
    if (axis == AxisDirection.up) {
      _showSkipIntro
          ? _skipFocusNode.requestFocus()
          : _backButtonFocusNode.requestFocus();
    }
    if (axis == AxisDirection.down) {
      _progressFocusNode.requestFocus();
    }
    setState(() {});
  }

  late final _progressFocusNode = FocusScopeNode(
    debugLabel: 'progress_focus_scope_node',
    onKeyEvent: (node, event) {
      if (event is KeyUpEvent || event is KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _controller.resetTimer();
        _value.position.inSeconds < 15
            ? _controller.seekTo(0)
            : _controller.seekBy(-15);
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _controller.resetTimer();
        _controller.seekBy(15);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _focusPlayPause();
        setState(() {});
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );

  bool _shouldUpdatePosition(Duration? currentPosition) {
    if (currentPosition == null) return true;
    if (_lastPositionUpdate == null) {
      _lastPositionUpdate = currentPosition;
      return true;
    }
    final shouldUpdate =
        currentPosition.inMilliseconds - _lastPositionUpdate!.inMilliseconds >=
        _positionUpdateThrottle.inMilliseconds;
    if (shouldUpdate) _lastPositionUpdate = currentPosition;
    return shouldUpdate;
  }

  bool _shouldProcessKeyEvent() {
    final now = DateTime.now();
    if (_lastKeyEvent == null) {
      _lastKeyEvent = now;
      return true;
    }
    final shouldProcess = now.difference(_lastKeyEvent!) >= _keyEventDebounce;
    if (shouldProcess) _lastKeyEvent = now;
    return shouldProcess;
  }

  bool _shouldRebuildOverlay(PlayerState previous, PlayerState current) {
    final overlay = current.value?.showOverlay ?? false;
    final playing = current.value?.isPlaying ?? false;
    if (_lastOverlayState != overlay || _lastPlayingState != playing) {
      _lastOverlayState = overlay;
      _lastPlayingState = playing;
      return true;
    }
    return false;
  }

  bool _shouldRebuildLoading(PlayerState previous, PlayerState current) {
    final initialized = current.value?.initialized ?? false;
    final loading = current.value?.isLoading ?? false;
    if (_lastInitializedState != initialized || _lastLoadingState != loading) {
      _lastInitializedState = initialized;
      _lastLoadingState = loading;
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _controller.toggleOverlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusPlayPause();
    });
  }

  @override
  void dispose() {
    _skipFocusNode.dispose();
    _backButtonFocusNode.dispose();
    _actionsFocusNode.dispose();
    _progressFocusNode.dispose();
    super.dispose();
  }

  void _onOverlayHided() {
    if (_value.isPlaying && _showSkipIntro) {
      _skipFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlayerBloc, PlayerState>(
      listenWhen: (previous, current) =>
          previous.value?.position != current.value?.position &&
          _shouldUpdatePosition(current.value?.position),
      listener: (context, state) {
        if (_showSkipIntro &&
            state.value!.isPlaying &&
            !state.value!.showOverlay) {
          _skipFocusNode.requestFocus();
        }
      },
      child: FocusScope(
        onKeyEvent: (node, event) {
          if (!_shouldProcessKeyEvent()) {
            return KeyEventResult.ignored;
          }

          if (_controller.overlayTimer?.isActive != true) {
            _controller.resetTimer();
          }

          if ((_actionsFocusNode.children
                      .where((node) => node.debugLabel == 'action')
                      .firstOrNull
                      ?.hasFocus ??
                  false) &&
              event.hasSubmitIntent &&
              !_value.isLoading) {
            if (!_showSkipIntro) {
              _value.isPlaying ? _controller.pause() : _controller.play();
            }
          }

          _controller.value.showOverlay
              ? _controller.resetTimer()
              : _controller.toggleOverlay();
          _controller.onOverlayHided ??= _onOverlayHided;
          return KeyEventResult.ignored;
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            BlocBuilder<PlayerBloc, PlayerState>(
              buildWhen: (previous, current) =>
                  previous.value?.showOverlay != current.value?.showOverlay ||
                  previous.value?.isPlaying != current.value?.isPlaying,
              builder: (context, state) => Visibility(
                visible: state.value!.showOverlay || !state.value!.isPlaying,
                child: const ColoredBox(color: Color(0x66000000)),
              ),
            ),
            BlocBuilder<PlayerBloc, PlayerState>(
              builder: (context, state) => AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: 32,
                right: 32,
                top: state.value!.showOverlay || !state.value!.isPlaying
                    ? 32
                    : -80,
                child: Row(
                  children: [
                    PlayerButton(
                      focusNode: _backButtonFocusNode,
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(Icons.arrow_back),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      state.contentName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            BlocBuilder<PlayerBloc, PlayerState>(
              buildWhen: _shouldRebuildOverlay,
              builder: (context, state) => AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: 32,
                right: 32,
                bottom: state.value!.showOverlay || !state.value!.isPlaying
                    ? 24
                    : -140,
                child: TvBottomOverlay(
                  nodes: [_actionsFocusNode, _progressFocusNode],
                ),
              ),
            ),
            BlocBuilder<PlayerBloc, PlayerState>(
              buildWhen: (previous, current) =>
                  previous.value?.position != current.value?.position ||
                  previous.value?.showOverlay != current.value?.showOverlay,
              builder: (context, state) => Visibility(
                visible: _showSkipIntro,
                child: Positioned(
                  left: 32,
                  bottom: state.value!.showOverlay ? 140 : 50,
                  child: DefaultPlayerButton(
                    node: _skipFocusNode,
                    title: 'Skip intro',
                    icon: Icons.skip_next,
                    onTap: () =>
                        _controller.seekTo(20 / _value.duration!.inSeconds),
                  ),
                ),
              ),
            ),
            BlocBuilder<PlayerBloc, PlayerState>(
              buildWhen: _shouldRebuildLoading,
              builder: (context, state) => Visibility(
                visible: !state.value!.initialized || state.value!.isLoading,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _showSkipIntro =>
      _value.position.inSeconds >= 10 &&
      _value.position.inSeconds < 20 &&
      _value.sliderValue != 0 &&
      _value.initialized;
}
