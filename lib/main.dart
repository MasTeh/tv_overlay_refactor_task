import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:media_kit_video/media_kit_video.dart';

import 'player/player_bloc.dart';
import 'tv_overlay/tv_overlay_old.dart';

const _deviceChannel = MethodChannel('tv_overlay_refactor_task/device');

void main() {
  MediaKit.ensureInitialized();
  runApp(const TvOverlayRefactorApp());
}

class TvOverlayRefactorApp extends StatelessWidget {
  const TvOverlayRefactorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TV Overlay Refactor Task',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: FutureBuilder<bool?>(
        future: _deviceChannel.invokeMethod<bool>('isTv'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const ColoredBox(color: Colors.black);
          }

          if (snapshot.data != true) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Text(
                  'This app requires Android TV',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            );
          }

          return BlocProvider(
            create: (_) => PlayerBloc()..add(const PlayerStarted()),
            child: const PlayerScreen(),
          );
        },
      ),
    );
  }
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocBuilder<PlayerBloc, PlayerState>(
        builder: (context, state) {
          if (state.value?.errorDescription != null) {
            return Center(child: Text(state.value!.errorDescription!));
          }

          if (state.value?.initialized != true) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: state.value!.aspectRatio,
                  child: Video(
                    controller: state.controller!.videoController,
                    controls: NoVideoControls,
                  ),
                ),
              ),
              const TvOverlayOld(),
            ],
          );
        },
      ),
    );
  }
}
