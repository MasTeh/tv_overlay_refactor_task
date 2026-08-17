import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'player_controller.dart';

part 'player_event.dart';
part 'player_state.dart';

const sampleVideoUrl =
    // 'https://exprts.stork.ru/.well-known/acme-challenge/'
    'https://ya-1.kuzalex.com/.well-known/acme-challenge/'
    'data534gsf5109/data/movie_hls/master.m3u8';

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  PlayerBloc({required bool isEmulator})
    : controller = PlayerController(sampleVideoUrl, isEmulator: isEmulator),
      super(const PlayerState()) {
    on<PlayerStarted>(_onStarted);
    on<PlayerValueChanged>(_onValueChanged);
    controller.addListener(_notifyValueChanged);
  }

  final PlayerController controller;

  Future<void> _onStarted(
    PlayerStarted event,
    Emitter<PlayerState> emit,
  ) async {
    await controller.initialize();
    await controller.play();
    emit(state.copyWith(controller: controller, value: controller.value));
  }

  void _notifyValueChanged() => add(const PlayerValueChanged());

  void _onValueChanged(PlayerValueChanged event, Emitter<PlayerState> emit) {
    emit(state.copyWith(controller: controller, value: controller.value));
  }

  @override
  Future<void> close() async {
    controller.removeListener(_notifyValueChanged);
    controller.dispose();
    return super.close();
  }
}
