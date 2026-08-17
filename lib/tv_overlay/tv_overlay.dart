import 'dart:async';

import 'package:flutter/material.dart' hide OverlayState;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../player/player_bloc.dart';
import '../player/player_controller.dart';
import 'overlay_coordinator.dart';
import 'overlay_focus_registry.dart';
import 'overlay_machine.dart';
import 'overlay_widgets.dart';

class TvOverlay extends StatefulWidget {
  const TvOverlay({super.key});

  @override
  State<TvOverlay> createState() => _TvOverlayState();
}

class _TvOverlayState extends State<TvOverlay> {
  late final PlayerBloc _playerBloc;
  late final OverlayFocusRegistry _focusRegistry;
  late final OverlayCoordinator _coordinator;
  bool _didInitialize = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) return;

    _playerBloc = context.read<PlayerBloc>();
    _focusRegistry = OverlayFocusRegistry();
    final value = _playerBloc.state.value ?? _playerBloc.controller.value;
    final initialState = OverlayState.initial(
      playbackPhase: _phaseFor(value),
      skipIntroAvailable: _skipIntroAvailable(value),
    );
    _focusRegistry.configure(
      overlayVisible: true,
      skipIntroAvailable: initialState.skipIntroAvailable,
    );
    _coordinator = OverlayCoordinator(
      initialState: initialState,
      timer: DartOverlayTimer(),
      player: _PlayerCommands(_playerBloc.controller),
      focus: _focusRegistry,
      showDialog: _showDialog,
      closeRoute: _closeRoute,
    );
    _didInitialize = true;
    unawaited(_coordinator.dispatch(const OverlayInitialized()));
  }

  @override
  void dispose() {
    unawaited(_coordinator.close());
    _focusRegistry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PlayerBloc, PlayerState>(
      listenWhen: (previous, current) {
        final previousValue = previous.value;
        final currentValue = current.value;
        return _phaseFor(previousValue) != _phaseFor(currentValue) ||
            _skipIntroAvailable(previousValue) !=
                _skipIntroAvailable(currentValue);
      },
      listener: (_, state) => unawaited(_syncPlayerState(state)),
      child: TvOverlayView(
        coordinator: _coordinator,
        focusRegistry: _focusRegistry,
        title: const _ContentTitle(),
        playPauseIcon: const _PlayPauseIcon(),
        progress: const _ProgressRow(),
      ),
    );
  }

  Future<void> _syncPlayerState(PlayerState state) async {
    if (_coordinator.isClosed) return;
    final value = state.value;
    final phase = _phaseFor(value);
    if (_coordinator.state.playbackPhase != phase) {
      await _coordinator.dispatch(PlaybackPhaseChanged(phase));
    }

    final skipAvailable = _skipIntroAvailable(value);
    if (_coordinator.state.skipIntroAvailable != skipAvailable) {
      await _coordinator.dispatch(SkipIntroAvailabilityChanged(skipAvailable));
    }
  }

  Future<void> _showDialog(OverlayDialog dialog) async {
    if (!mounted) return;
    final title = switch (dialog) {
      OverlayDialog.audioSubtitles => 'Audio and subtitles',
      OverlayDialog.settings => 'Settings',
    };

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('This action is intentionally left as a stub.'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeRoute() async {
    if (mounted) await Navigator.of(context).maybePop();
  }
}

class _PlayerCommands implements OverlayPlaybackCommands {
  const _PlayerCommands(this.controller);

  final PlayerController controller;

  @override
  Future<void> play() => controller.play();

  @override
  Future<void> pause() => controller.pause();

  @override
  Future<void> seekBy(Duration offset) => controller.seekBy(offset);

  @override
  Future<void> seekToPosition(Duration position) {
    return controller.seekToPosition(position);
  }
}

class _ContentTitle extends StatelessWidget {
  const _ContentTitle();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerBloc, PlayerState, String>(
      selector: (state) => state.contentName,
      builder: (_, contentName) => Text(contentName),
    );
  }
}

class _PlayPauseIcon extends StatelessWidget {
  const _PlayPauseIcon();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerBloc, PlayerState, bool>(
      selector: (state) => state.value?.isPlaying ?? false,
      builder: (_, isPlaying) =>
          Icon(isPlaying ? Icons.pause : Icons.play_arrow),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BlocSelector<PlayerBloc, PlayerState, Duration>(
          selector: (state) => state.value?.position ?? Duration.zero,
          builder: (_, position) => Text(
            formatDuration(position),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              BlocSelector<
                PlayerBloc,
                PlayerState,
                ({Duration position, Duration duration})
              >(
                selector: (state) => (
                  position: state.value?.position ?? Duration.zero,
                  duration: state.value?.duration ?? Duration.zero,
                ),
                builder: (_, progress) {
                  final max = progress.duration.inMilliseconds;
                  final current = progress.position.inMilliseconds.clamp(
                    0,
                    max,
                  );
                  return LinearProgressIndicator(
                    minHeight: 6,
                    value: max == 0 ? 0 : current / max,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.redAccent,
                    ),
                  );
                },
              ),
        ),
        const SizedBox(width: 16),
        BlocSelector<PlayerBloc, PlayerState, Duration>(
          selector: (state) => state.value?.duration ?? Duration.zero,
          builder: (_, duration) => Text(
            formatDuration(duration),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

PlaybackPhase _phaseFor(PlayerValue? value) {
  if (value?.errorDescription != null) return PlaybackPhase.failed;
  if (value == null || !value.initialized || value.isLoading) {
    return PlaybackPhase.loading;
  }
  return value.isPlaying ? PlaybackPhase.playing : PlaybackPhase.paused;
}

bool _skipIntroAvailable(PlayerValue? value) {
  return value != null &&
      isSkipIntroAvailable(
        initialized: value.initialized,
        position: value.position,
      );
}
