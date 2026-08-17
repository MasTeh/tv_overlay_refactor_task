import 'package:flutter/widgets.dart';

import 'overlay_focus.dart';
import 'overlay_types.dart';

class OverlayFocusRegistry implements OverlayFocusSink {
  OverlayFocusRegistry()
    : _nodes = {
        for (final target in OverlayFocusTarget.values) target: FocusNode(),
      };

  final Map<OverlayFocusTarget, FocusNode> _nodes;
  bool _disposed = false;

  FocusNode nodeFor(OverlayFocusTarget target) => _nodes[target]!;

  void configure({
    required bool overlayVisible,
    required bool skipIntroAvailable,
  }) {
    if (_disposed) return;

    for (final entry in _nodes.entries) {
      entry.value.canRequestFocus = switch (entry.key) {
        OverlayFocusTarget.surface => true,
        OverlayFocusTarget.skipIntro => skipIntroAvailable,
        _ => overlayVisible,
      };
    }
  }

  @override
  void requestFocus(OverlayFocusTarget target) {
    if (_disposed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final node = _nodes[target]!;
      if (node.canRequestFocus) node.requestFocus();
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final node in _nodes.values) {
      node.dispose();
    }
  }
}
