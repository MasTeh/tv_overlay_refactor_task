import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerValue extends Equatable {
  const PlayerValue({
    this.position = Duration.zero,
    this.duration,
    this.isPlaying = false,
    this.isLoading = true,
    this.initialized = false,
    this.showOverlay = false,
    this.sliderValue = 0,
    this.errorDescription,
    this.aspectRatio = 16 / 9,
  });

  final Duration position;
  final Duration? duration;
  final bool isPlaying;
  final bool isLoading;
  final bool initialized;
  final bool showOverlay;
  final double sliderValue;
  final String? errorDescription;
  final double aspectRatio;

  PlayerValue copyWith({
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isLoading,
    bool? initialized,
    bool? showOverlay,
    double? sliderValue,
    String? errorDescription,
    double? aspectRatio,
  }) {
    return PlayerValue(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      initialized: initialized ?? this.initialized,
      showOverlay: showOverlay ?? this.showOverlay,
      sliderValue: sliderValue ?? this.sliderValue,
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
    showOverlay,
    sliderValue,
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

  Timer? overlayTimer;
  VoidCallback? onOverlayHided;

  Future<void> initialize() async {
    await player.open(Media(url), play: false);
    value = value.copyWith(initialized: true, isLoading: false);
  }

  Future<void> play() => player.play();

  Future<void> pause() => player.pause();

  Future<void> seekBy(double seconds) {
    return player.seek(
      value.position + Duration(milliseconds: (seconds * 1000).round()),
    );
  }

  Future<void> seekTo(double relativePosition) {
    final duration = value.duration;
    if (duration == null) return Future.value();

    return player.seek(
      Duration(
        milliseconds: (duration.inMilliseconds * relativePosition.clamp(0, 1))
            .round(),
      ),
    );
  }

  void toggleOverlay() {
    value = value.copyWith(showOverlay: !value.showOverlay);
    value.showOverlay ? resetTimer() : overlayTimer?.cancel();
  }

  void resetTimer() {
    overlayTimer?.cancel();
    if (!value.showOverlay) {
      value = value.copyWith(showOverlay: true);
    }

    overlayTimer = Timer(const Duration(seconds: 5), () {
      if (!value.isPlaying) return;
      value = value.copyWith(showOverlay: false);
      onOverlayHided?.call();
    });
  }

  void _update({Duration? position, Duration? duration}) {
    final nextPosition = position ?? value.position;
    final nextDuration = duration ?? value.duration;

    value = value.copyWith(
      position: nextPosition,
      duration: nextDuration,
      sliderValue: nextDuration == null || nextDuration.inMilliseconds == 0
          ? 0
          : nextPosition.inMilliseconds / nextDuration.inMilliseconds,
    );
  }

  void _updateAspectRatio() {
    if (_width == null || _height == null || _height == 0) return;
    value = value.copyWith(aspectRatio: _width! / _height!);
  }

  @override
  void dispose() {
    overlayTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    player.dispose();
    super.dispose();
  }
}
