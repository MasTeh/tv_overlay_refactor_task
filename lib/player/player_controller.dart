import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

Duration clampSeekPosition(Duration position, Duration? duration) {
  if (position.isNegative) return Duration.zero;
  if (duration != null && position > duration) return duration;
  return position;
}

class PlayerValue extends Equatable {
  const PlayerValue({
    this.position = Duration.zero,
    this.duration,
    this.isPlaying = false,
    this.isLoading = true,
    this.initialized = false,
    this.errorDescription,
    this.aspectRatio = 16 / 9,
  });

  final Duration position;
  final Duration? duration;
  final bool isPlaying;
  final bool isLoading;
  final bool initialized;
  final String? errorDescription;
  final double aspectRatio;

  PlayerValue copyWith({
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isLoading,
    bool? initialized,
    String? errorDescription,
    double? aspectRatio,
  }) {
    return PlayerValue(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      initialized: initialized ?? this.initialized,
      errorDescription: errorDescription ?? this.errorDescription,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }

  @override
  List<Object?> get props => [
    position,
    duration,
    isPlaying,
    isLoading,
    initialized,
    errorDescription,
    aspectRatio,
  ];
}

class PlayerController extends ValueNotifier<PlayerValue> {
  PlayerController(this.url, {required bool isEmulator})
    : player = Player(),
      super(const PlayerValue()) {
    videoController = VideoController(
      player,
      configuration: isEmulator
          ? const VideoControllerConfiguration(
              vo: 'mediacodec_embed',
              hwdec: 'mediacodec',
            )
          : const VideoControllerConfiguration(),
    );
    _subscriptions.addAll([
      player.stream.position.listen((position) {
        _update(position: position);
      }),
      player.stream.duration.listen((duration) {
        _update(duration: duration);
      }),
      player.stream.playing.listen((playing) {
        value = value.copyWith(isPlaying: playing);
      }),
      player.stream.buffering.listen((buffering) {
        value = value.copyWith(isLoading: buffering);
      }),
      player.stream.width.listen((width) {
        _width = width;
        _updateAspectRatio();
      }),
      player.stream.height.listen((height) {
        _height = height;
        _updateAspectRatio();
      }),
      player.stream.error.listen((error) {
        value = value.copyWith(errorDescription: error);
      }),
    ]);
  }

  final String url;
  final Player player;
  late final VideoController videoController;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  int? _width;
  int? _height;

  Future<void> initialize() async {
    await player.open(Media(url), play: false);
    value = value.copyWith(initialized: true, isLoading: false);
  }

  Future<void> play() => player.play();

  Future<void> pause() => player.pause();

  Future<void> seekBy(Duration offset) {
    return seekToPosition(value.position + offset);
  }

  Future<void> seekToPosition(Duration position) {
    return player.seek(clampSeekPosition(position, value.duration));
  }

  void _update({Duration? position, Duration? duration}) {
    final nextPosition = position ?? value.position;
    final nextDuration = duration ?? value.duration;

    value = value.copyWith(position: nextPosition, duration: nextDuration);
  }

  void _updateAspectRatio() {
    if (_width == null || _height == null || _height == 0) return;
    value = value.copyWith(aspectRatio: _width! / _height!);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    player.dispose();
    super.dispose();
  }
}
