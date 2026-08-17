import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'overlay_focus.dart';
import 'overlay_machine.dart';

abstract interface class OverlayTimer {
  void restart(Duration delay, void Function() onElapsed);

  void cancel();

  void dispose();
}

class DartOverlayTimer implements OverlayTimer {
  Timer? _timer;

  @override
  void restart(Duration delay, void Function() onElapsed) {
    _timer?.cancel();
    _timer = Timer(delay, onElapsed);
  }

  @override
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() => cancel();
}

abstract interface class OverlayPlaybackCommands {
  Future<void> play();

  Future<void> pause();

  Future<void> seekBy(Duration offset);

  Future<void> seekToPosition(Duration position);
}

typedef ShowOverlayDialog = Future<void> Function(OverlayDialog dialog);
typedef CloseOverlayRoute = Future<void> Function();

class OverlayCoordinator extends Cubit<OverlayState> {
  OverlayCoordinator({
    required OverlayState initialState,
    required OverlayTimer timer,
    required OverlayPlaybackCommands player,
    required OverlayFocusSink focus,
    required ShowOverlayDialog showDialog,
    required CloseOverlayRoute closeRoute,
  }) : _timer = timer,
       _player = player,
       _focus = focus,
       _showDialog = showDialog,
       _closeRoute = closeRoute,
       super(initialState);

  final OverlayTimer _timer;
  final OverlayPlaybackCommands _player;
  final OverlayFocusSink _focus;
  final ShowOverlayDialog _showDialog;
  final CloseOverlayRoute _closeRoute;

  Future<void> dispatch(OverlayEvent event) async {
    if (isClosed) return;

    final transition = reduce(state, event);
    if (transition.nextState != state) emit(transition.nextState);

    for (final effect in transition.effects) {
      if (isClosed) return;
      await _run(effect);
    }
  }

  Future<void> _run(OverlayEffect effect) async {
    switch (effect) {
      case RequestFocusEffect():
        _focus.requestFocus(effect.target);
      case RestartAutoHideTimerEffect():
        _timer.restart(
          effect.delay,
          () => unawaited(dispatch(const AutoHideElapsed())),
        );
      case CancelAutoHideTimerEffect():
        _timer.cancel();
      case PlayEffect():
        await _player.play();
      case PauseEffect():
        await _player.pause();
      case SeekByEffect():
        await _player.seekBy(effect.offset);
      case SeekToPositionEffect():
        await _player.seekToPosition(effect.position);
      case OpenDialogEffect():
        await _showDialog(effect.dialog);
        if (!isClosed) {
          final target = switch (effect.dialog) {
            OverlayDialog.audioSubtitles => OverlayFocusTarget.audioSubtitles,
            OverlayDialog.settings => OverlayFocusTarget.settings,
          };
          await dispatch(OverlayDialogClosed(target));
        }
      case CloseRouteEffect():
        await _closeRoute();
    }
  }

  @override
  Future<void> close() {
    _timer.dispose();
    return super.close();
  }
}
