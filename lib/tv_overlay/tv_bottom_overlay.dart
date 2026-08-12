import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../player/player_bloc.dart';
import 'widgets.dart';

class TvBottomOverlay extends StatelessWidget {
  const TvBottomOverlay({required this.nodes, super.key});

  final List<FocusScopeNode> nodes;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusScope(
          node: nodes[0],
          child: Row(
            children: [
              BlocBuilder<PlayerBloc, PlayerState>(
                buildWhen: (previous, current) =>
                    previous.value?.isPlaying != current.value?.isPlaying,
                builder: (context, state) {
                  return FocusWrapper(
                    debugLabel: 'action',
                    autofocus: true,
                    onTap: () {
                      state.value!.isPlaying
                          ? state.controller?.pause()
                          : state.controller?.play();
                    },
                    builder: (context, hasFocus, child) =>
                        PlayerFocusDecoration(
                          hasFocus: hasFocus,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Icon(
                              state.value!.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 30,
                            ),
                          ),
                        ),
                  );
                },
              ),
              const Spacer(),
              DefaultPlayerButton(
                title: 'Audio and subtitles',
                icon: Icons.subtitles,
                onTap: () => _showDialog(context, 'Audio and subtitles'),
              ),
              const SizedBox(width: 16),
              DefaultPlayerButton(
                title: 'Settings',
                icon: Icons.settings,
                onTap: () => _showDialog(context, 'Settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            BlocBuilder<PlayerBloc, PlayerState>(
              buildWhen: (previous, current) =>
                  previous.value?.position != current.value?.position,
              builder: (context, state) {
                return Text(
                  formatDuration(state.value?.position ?? Duration.zero),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            BlocBuilder<PlayerBloc, PlayerState>(
              buildWhen: (previous, current) =>
                  previous.value?.position != current.value?.position ||
                  previous.value?.duration != current.value?.duration,
              builder: (context, state) {
                return Expanded(
                  child: FramePlayerProgressBar(
                    controller: state.controller!,
                    color: nodes[1].hasFocus ? null : Colors.white,
                    node: nodes[1],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            BlocBuilder<PlayerBloc, PlayerState>(
              buildWhen: (previous, current) =>
                  previous.value?.duration != current.value?.duration,
              builder: (context, state) {
                return Text(
                  formatDuration(state.value?.duration ?? Duration.zero),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showDialog(BuildContext context, String title) async {
    final bloc = context.read<PlayerBloc>();

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

    bloc.state.controller?.toggleOverlay();
  }
}
