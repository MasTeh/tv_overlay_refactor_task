import 'overlay_types.dart';

class OverlayFocusGraph {
  const OverlayFocusGraph();

  OverlayFocusTarget? next({
    required OverlayFocusTarget current,
    required TvDirection direction,
    required bool skipIntroAvailable,
  }) {
    final topTarget = skipIntroAvailable
        ? OverlayFocusTarget.skipIntro
        : OverlayFocusTarget.back;

    return switch ((current, direction)) {
      (OverlayFocusTarget.surface, TvDirection.up) => OverlayFocusTarget.back,
      (OverlayFocusTarget.surface, _) => OverlayFocusTarget.playPause,
      (OverlayFocusTarget.back, TvDirection.down) =>
        topTarget == OverlayFocusTarget.skipIntro
            ? OverlayFocusTarget.skipIntro
            : OverlayFocusTarget.playPause,
      (OverlayFocusTarget.skipIntro, TvDirection.up) => OverlayFocusTarget.back,
      (OverlayFocusTarget.skipIntro, TvDirection.down) =>
        OverlayFocusTarget.playPause,
      (OverlayFocusTarget.playPause, TvDirection.up) => topTarget,
      (OverlayFocusTarget.playPause, TvDirection.right) =>
        OverlayFocusTarget.audioSubtitles,
      (OverlayFocusTarget.playPause, TvDirection.down) =>
        OverlayFocusTarget.progress,
      (OverlayFocusTarget.audioSubtitles, TvDirection.left) =>
        OverlayFocusTarget.playPause,
      (OverlayFocusTarget.audioSubtitles, TvDirection.right) =>
        OverlayFocusTarget.settings,
      (OverlayFocusTarget.audioSubtitles, TvDirection.up) => topTarget,
      (OverlayFocusTarget.audioSubtitles, TvDirection.down) =>
        OverlayFocusTarget.progress,
      (OverlayFocusTarget.settings, TvDirection.left) =>
        OverlayFocusTarget.audioSubtitles,
      (OverlayFocusTarget.settings, TvDirection.up) => topTarget,
      (OverlayFocusTarget.settings, TvDirection.down) =>
        OverlayFocusTarget.progress,
      (OverlayFocusTarget.progress, TvDirection.up) =>
        OverlayFocusTarget.playPause,
      _ => null,
    };
  }
}

abstract interface class OverlayFocusSink {
  void requestFocus(OverlayFocusTarget target);
}
