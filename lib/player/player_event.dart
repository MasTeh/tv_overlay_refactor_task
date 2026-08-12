part of 'player_bloc.dart';

sealed class PlayerEvent {
  const PlayerEvent();
}

final class PlayerStarted extends PlayerEvent {
  const PlayerStarted();
}

final class PlayerValueChanged extends PlayerEvent {
  const PlayerValueChanged();
}
