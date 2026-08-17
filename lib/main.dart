import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' show MediaKit;
import 'package:media_kit_video/media_kit_video.dart';

import 'player/player_bloc.dart';
import 'tv_overlay/tv_overlay.dart';

const _deviceChannel = MethodChannel('tv_overlay_refactor_task/device');

typedef DeviceInfo = ({bool isTv, bool isEmulator});

Future<DeviceInfo> _loadDeviceInfo() async {
  final result = await _deviceChannel.invokeMapMethod<String, bool>(
    'getDeviceInfo',
  );

  return (
    isTv: result?['isTv'] ?? false,
    isEmulator: result?['isEmulator'] ?? false,
  );
}

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
      home: FutureBuilder<DeviceInfo>(
        future: _loadDeviceInfo(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const ColoredBox(color: Colors.black);
          }

          if (snapshot.data?.isTv != true) {
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
            create: (_) =>
                PlayerBloc(isEmulator: snapshot.data!.isEmulator)
                  ..add(const PlayerStarted()),
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
        buildWhen: (previous, current) =>
            previous.value?.initialized != current.value?.initialized ||
            previous.value?.errorDescription !=
                current.value?.errorDescription ||
            previous.value?.aspectRatio != current.value?.aspectRatio ||
            previous.controller != current.controller,
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
              const TvOverlay(),
            ],
          );
        },
      ),
    );
  }
}
