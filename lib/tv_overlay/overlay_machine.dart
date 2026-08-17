import 'package:equatable/equatable.dart';

import 'overlay_focus.dart';
import 'overlay_types.dart';

export 'overlay_types.dart';

const overlayAutoHideDelay = Duration(seconds: 5);
const skipIntroStart = Duration(seconds: 10);
const skipIntroEnd = Duration(seconds: 20);

class OverlayState extends Equatable {
  const OverlayState({
    required this.visibility,
    required this.playbackPhase,
    required this.focusedTarget,
    required this.skipIntroAvailable,
  });

  const OverlayState.initial({
    this.playbackPhase = PlaybackPhase.loading,
    this.skipIntroAvailable = false,
  }) : visibility = OverlayVisibility.visible,
       focusedTarget = OverlayFocusTarget.playPause;

  final OverlayVisibility visibility;
  final PlaybackPhase playbackPhase;
  final OverlayFocusTarget focusedTarget;
  final bool skipIntroAvailable;

  OverlayState copyWith({
    OverlayVisibility? visibility,
    PlaybackPhase? playbackPhase,
    OverlayFocusTarget? focusedTarget,
    bool? skipIntroAvailable,
  }) {
    return OverlayState(
      visibility: visibility ?? this.visibility,
      playbackPhase: playbackPhase ?? this.playbackPhase,
      focusedTarget: focusedTarget ?? this.focusedTarget,
      skipIntroAvailable: skipIntroAvailable ?? this.skipIntroAvailable,
    );
  }

  @override
  List<Object> get props => [
    visibility,
    playbackPhase,
    focusedTarget,
    skipIntroAvailable,
  ];
}

sealed class OverlayEvent extends Equatable {
  const OverlayEvent();

  @override
  bool get stringify => true;
}

final class OverlayInitialized extends OverlayEvent {
  const OverlayInitialized();

  @override
  List<Object?> get props => const [];
}

final class RemoteCommandReceived extends OverlayEvent {
  const RemoteCommandReceived(this.command);

  final TvRemoteCommand command;

  @override
  List<Object?> get props => [command];
}

final class PlaybackPhaseChanged extends OverlayEvent {
  const PlaybackPhaseChanged(this.phase);

  final PlaybackPhase phase;

  @override
  List<Object?> get props => [phase];
}

final class SkipIntroAvailabilityChanged extends OverlayEvent {
  const SkipIntroAvailabilityChanged(this.available);

  final bool available;

  @override
  List<Object?> get props => [available];
}

final class AutoHideElapsed extends OverlayEvent {
  const AutoHideElapsed();

  @override
  List<Object?> get props => const [];
}

final class OverlayDialogClosed extends OverlayEvent {
  const OverlayDialogClosed(this.target);

  final OverlayFocusTarget target;

  @override
  List<Object?> get props => [target];
}

final class OverlayTargetActivated extends OverlayEvent {
  const OverlayTargetActivated(this.target);

  final OverlayFocusTarget target;

  @override
  List<Object?> get props => [target];
}

final class OverlayFocusChanged extends OverlayEvent {
  const OverlayFocusChanged(this.target);

  final OverlayFocusTarget target;

  @override
  List<Object?> get props => [target];
}

sealed class OverlayEffect extends Equatable {
  const OverlayEffect();

  @override
  bool get stringify => true;
}

final class RequestFocusEffect extends OverlayEffect {
  const RequestFocusEffect(this.target);

  final OverlayFocusTarget target;

  @override
  List<Object?> get props => [target];
}

final class RestartAutoHideTimerEffect extends OverlayEffect {
  const RestartAutoHideTimerEffect({this.delay = overlayAutoHideDelay});

  final Duration delay;

  @override
  List<Object?> get props => [delay];
}

final class CancelAutoHideTimerEffect extends OverlayEffect {
  const CancelAutoHideTimerEffect();

  @override
  List<Object?> get props => const [];
}

final class PlayEffect extends OverlayEffect {
  const PlayEffect();

  @override
  List<Object?> get props => const [];
}

final class PauseEffect extends OverlayEffect {
  const PauseEffect();

  @override
  List<Object?> get props => const [];
}

final class SeekByEffect extends OverlayEffect {
  const SeekByEffect(this.offset);

  final Duration offset;

  @override
  List<Object?> get props => [offset];
}

final class SeekToPositionEffect extends OverlayEffect {
  const SeekToPositionEffect(this.position);

  final Duration position;

  @override
  List<Object?> get props => [position];
}

final class OpenDialogEffect extends OverlayEffect {
  const OpenDialogEffect(this.dialog);

  final OverlayDialog dialog;

  @override
  List<Object?> get props => [dialog];
}

final class CloseRouteEffect extends OverlayEffect {
  const CloseRouteEffect();

  @override
  List<Object?> get props => const [];
}

class OverlayTransition extends Equatable {
  OverlayTransition(this.nextState, [List<OverlayEffect> effects = const []])
    : effects = List.unmodifiable(effects);

  final OverlayState nextState;
  final List<OverlayEffect> effects;

  @override
  List<Object?> get props => [nextState, effects];
}

const _focusGraph = OverlayFocusGraph();

OverlayTransition reduce(OverlayState state, OverlayEvent event) {
  return switch (event) {
    OverlayInitialized() => _initialize(state),
    RemoteCommandReceived() => _handleRemoteCommand(state, event.command),
    PlaybackPhaseChanged() => _changePlaybackPhase(state, event.phase),
    SkipIntroAvailabilityChanged() => _changeSkipAvailability(
      state,
      event.available,
    ),
    AutoHideElapsed() => _handleAutoHide(state),
    OverlayDialogClosed() => _restoreAfterDialog(state, event.target),
    OverlayTargetActivated() => _activateTarget(state, event.target),
    OverlayFocusChanged() => _confirmFocus(state, event.target),
  };
}

OverlayTransition _initialize(OverlayState state) {
  final nextState = state.copyWith(
    visibility: OverlayVisibility.visible,
    focusedTarget: OverlayFocusTarget.playPause,
  );
  return OverlayTransition(nextState, [
    const RequestFocusEffect(OverlayFocusTarget.playPause),
    if (nextState.playbackPhase == PlaybackPhase.playing)
      const RestartAutoHideTimerEffect()
    else
      const CancelAutoHideTimerEffect(),
  ]);
}

OverlayTransition _handleRemoteCommand(
  OverlayState state,
  TvRemoteCommand command,
) {
  if (command == TvRemoteCommand.back) {
    return OverlayTransition(state, const [CloseRouteEffect()]);
  }

  var nextState = state.copyWith(visibility: OverlayVisibility.visible);
  final effects = <OverlayEffect>[
    if (state.playbackPhase == PlaybackPhase.playing)
      const RestartAutoHideTimerEffect(),
  ];

  final direction = switch (command) {
    TvRemoteCommand.up => TvDirection.up,
    TvRemoteCommand.down => TvDirection.down,
    TvRemoteCommand.left => TvDirection.left,
    TvRemoteCommand.right => TvDirection.right,
    TvRemoteCommand.select || TvRemoteCommand.back => null,
  };

  if (direction != null) {
    if (state.focusedTarget == OverlayFocusTarget.progress &&
        (direction == TvDirection.left || direction == TvDirection.right)) {
      effects.add(
        SeekByEffect(
          direction == TvDirection.left
              ? const Duration(seconds: -15)
              : const Duration(seconds: 15),
        ),
      );
      return OverlayTransition(nextState, effects);
    }

    final target = _focusGraph.next(
      current: state.focusedTarget,
      direction: direction,
      skipIntroAvailable: state.skipIntroAvailable,
    );
    if (target != null) {
      nextState = nextState.copyWith(focusedTarget: target);
      effects.add(RequestFocusEffect(target));
    }
    return OverlayTransition(nextState, effects);
  }

  if (state.focusedTarget == OverlayFocusTarget.surface) {
    nextState = nextState.copyWith(focusedTarget: OverlayFocusTarget.playPause);
    effects.add(const RequestFocusEffect(OverlayFocusTarget.playPause));
    return OverlayTransition(nextState, effects);
  }

  _appendActivationEffect(effects, state, state.focusedTarget);
  return OverlayTransition(nextState, effects);
}

OverlayTransition _activateTarget(
  OverlayState state,
  OverlayFocusTarget target,
) {
  if (target == OverlayFocusTarget.skipIntro && !state.skipIntroAvailable) {
    return OverlayTransition(state);
  }

  var nextState = state.copyWith(visibility: OverlayVisibility.visible);
  final effects = <OverlayEffect>[
    if (state.playbackPhase == PlaybackPhase.playing)
      const RestartAutoHideTimerEffect(),
  ];

  if (target == OverlayFocusTarget.surface) {
    nextState = nextState.copyWith(focusedTarget: OverlayFocusTarget.playPause);
    effects.add(const RequestFocusEffect(OverlayFocusTarget.playPause));
    return OverlayTransition(nextState, effects);
  }

  nextState = nextState.copyWith(focusedTarget: target);
  if (target != OverlayFocusTarget.back) {
    effects.add(RequestFocusEffect(target));
  }
  _appendActivationEffect(effects, state, target);
  return OverlayTransition(nextState, effects);
}

void _appendActivationEffect(
  List<OverlayEffect> effects,
  OverlayState state,
  OverlayFocusTarget target,
) {
  switch (target) {
    case OverlayFocusTarget.back:
      effects.add(const CloseRouteEffect());
    case OverlayFocusTarget.playPause:
      if (state.playbackPhase == PlaybackPhase.playing) {
        effects.add(const PauseEffect());
      } else if (state.playbackPhase == PlaybackPhase.paused) {
        effects.add(const PlayEffect());
      }
    case OverlayFocusTarget.audioSubtitles:
      effects.add(const OpenDialogEffect(OverlayDialog.audioSubtitles));
    case OverlayFocusTarget.settings:
      effects.add(const OpenDialogEffect(OverlayDialog.settings));
    case OverlayFocusTarget.skipIntro:
      if (state.skipIntroAvailable) {
        effects.add(const SeekToPositionEffect(skipIntroEnd));
      }
    case OverlayFocusTarget.progress || OverlayFocusTarget.surface:
      break;
  }
}

OverlayTransition _changePlaybackPhase(
  OverlayState state,
  PlaybackPhase phase,
) {
  if (phase == PlaybackPhase.playing) {
    final nextState = state.copyWith(playbackPhase: phase);
    return OverlayTransition(nextState, [
      if (nextState.visibility == OverlayVisibility.visible)
        const RestartAutoHideTimerEffect(),
    ]);
  }

  var nextState = state.copyWith(
    playbackPhase: phase,
    visibility: OverlayVisibility.visible,
  );
  final effects = <OverlayEffect>[const CancelAutoHideTimerEffect()];
  if (state.focusedTarget == OverlayFocusTarget.surface) {
    nextState = nextState.copyWith(focusedTarget: OverlayFocusTarget.playPause);
    effects.add(const RequestFocusEffect(OverlayFocusTarget.playPause));
  }
  return OverlayTransition(nextState, effects);
}

OverlayTransition _changeSkipAvailability(OverlayState state, bool available) {
  if (state.skipIntroAvailable == available) {
    return OverlayTransition(state);
  }

  var nextState = state.copyWith(skipIntroAvailable: available);
  if (available && state.visibility == OverlayVisibility.hidden) {
    nextState = nextState.copyWith(focusedTarget: OverlayFocusTarget.skipIntro);
    return OverlayTransition(nextState, const [
      RequestFocusEffect(OverlayFocusTarget.skipIntro),
    ]);
  }
  if (available || state.focusedTarget != OverlayFocusTarget.skipIntro) {
    return OverlayTransition(nextState);
  }

  nextState = nextState.copyWith(
    visibility: OverlayVisibility.visible,
    focusedTarget: OverlayFocusTarget.playPause,
  );
  return OverlayTransition(nextState, [
    if (state.playbackPhase == PlaybackPhase.playing)
      const RestartAutoHideTimerEffect()
    else
      const CancelAutoHideTimerEffect(),
    const RequestFocusEffect(OverlayFocusTarget.playPause),
  ]);
}

OverlayTransition _handleAutoHide(OverlayState state) {
  if (state.playbackPhase != PlaybackPhase.playing) {
    return OverlayTransition(state);
  }

  final target = state.skipIntroAvailable
      ? OverlayFocusTarget.skipIntro
      : OverlayFocusTarget.surface;
  final nextState = state.copyWith(
    visibility: OverlayVisibility.hidden,
    focusedTarget: target,
  );
  return OverlayTransition(nextState, [
    const CancelAutoHideTimerEffect(),
    RequestFocusEffect(target),
  ]);
}

OverlayTransition _restoreAfterDialog(
  OverlayState state,
  OverlayFocusTarget target,
) {
  final nextState = state.copyWith(
    visibility: OverlayVisibility.visible,
    focusedTarget: target,
  );
  return OverlayTransition(nextState, [
    if (state.playbackPhase == PlaybackPhase.playing)
      const RestartAutoHideTimerEffect()
    else
      const CancelAutoHideTimerEffect(),
    RequestFocusEffect(target),
  ]);
}

OverlayTransition _confirmFocus(OverlayState state, OverlayFocusTarget target) {
  final isValid = switch (target) {
    OverlayFocusTarget.surface => true,
    OverlayFocusTarget.skipIntro => state.skipIntroAvailable,
    _ => state.visibility == OverlayVisibility.visible,
  };
  return OverlayTransition(
    isValid ? state.copyWith(focusedTarget: target) : state,
  );
}

bool isSkipIntroAvailable({
  required bool initialized,
  required Duration position,
}) {
  return initialized &&
      position.compareTo(skipIntroStart) >= 0 &&
      position.compareTo(skipIntroEnd) < 0;
}
