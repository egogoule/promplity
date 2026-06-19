// lib/bloc/server_bloc.dart
// Manages server list and connection lifecycle

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../services/ssh_service.dart';

// ── Events ────────────────────────────────────────────────────────────────

sealed class ServerEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadServers extends ServerEvent {}

class AddServer extends ServerEvent {
  final Server server;
  AddServer(this.server);
  @override
  List<Object?> get props => [server];
}

class UpdateServer extends ServerEvent {
  final Server server;
  UpdateServer(this.server);
  @override
  List<Object?> get props => [server];
}

class DeleteServer extends ServerEvent {
  final String serverId;
  DeleteServer(this.serverId);
  @override
  List<Object?> get props => [serverId];
}

class ConnectToServer extends ServerEvent {
  final Server server;
  ConnectToServer(this.server);
  @override
  List<Object?> get props => [server];
}

class DisconnectFromServer extends ServerEvent {
  final String serverId;
  DisconnectFromServer(this.serverId);
  @override
  List<Object?> get props => [serverId];
}

// ── States ────────────────────────────────────────────────────────────────

sealed class ServerState extends Equatable {
  final List<Server> servers;
  final Map<String, SshConnectionState> connectionStates;

  const ServerState({
    this.servers = const [],
    this.connectionStates = const {},
  });

  @override
  List<Object?> get props => [servers, connectionStates];
}

class ServerInitial extends ServerState {
  const ServerInitial();
}

class ServersLoaded extends ServerState {
  const ServersLoaded({
    required super.servers,
    super.connectionStates,
  });
}

class ServerConnecting extends ServerState {
  final String serverId;
  const ServerConnecting({
    required this.serverId,
    required super.servers,
    super.connectionStates,
  });
  @override
  List<Object?> get props => [serverId, ...super.props];
}

class ServerConnected extends ServerState {
  final String serverId;
  final SshSession session;
  const ServerConnected({
    required this.serverId,
    required this.session,
    required super.servers,
    super.connectionStates,
  });
  @override
  List<Object?> get props => [serverId, ...super.props];
}

class ServerError extends ServerState {
  final String message;
  const ServerError({
    required this.message,
    required super.servers,
    super.connectionStates,
  });
  @override
  List<Object?> get props => [message, ...super.props];
}

// ── BLoC ──────────────────────────────────────────────────────────────────

class ServerBloc extends Bloc<ServerEvent, ServerState> {
  final ServerRepository _repo;
  final SshService _ssh;

  ServerBloc({required ServerRepository repo, required SshService ssh})
      : _repo = repo,
        _ssh = ssh,
        super(const ServerInitial()) {
    on<LoadServers>(_onLoad);
    on<AddServer>(_onAdd);
    on<UpdateServer>(_onUpdate);
    on<DeleteServer>(_onDelete);
    on<ConnectToServer>(_onConnect);
    on<DisconnectFromServer>(_onDisconnect);
  }

  List<Server> get _currentServers =>
      state.servers;
  Map<String, SshConnectionState> get _currentStates =>
      Map.of(state.connectionStates);

  Future<void> _onLoad(LoadServers event, Emitter<ServerState> emit) async {
    final servers = await _repo.getAll();
    emit(ServersLoaded(servers: servers));
  }

  Future<void> _onAdd(AddServer event, Emitter<ServerState> emit) async {
    await _repo.save(event.server);
    final servers = await _repo.getAll();
    emit(ServersLoaded(
      servers: servers,
      connectionStates: _currentStates,
    ));
  }

  Future<void> _onUpdate(UpdateServer event, Emitter<ServerState> emit) async {
    await _repo.save(event.server);
    final servers = await _repo.getAll();
    emit(ServersLoaded(
      servers: servers,
      connectionStates: _currentStates,
    ));
  }

  Future<void> _onDelete(DeleteServer event, Emitter<ServerState> emit) async {
    await _ssh.disconnect(event.serverId);
    await _repo.delete(event.serverId);
    final states = _currentStates..remove(event.serverId);
    final servers = await _repo.getAll();
    emit(ServersLoaded(servers: servers, connectionStates: states));
  }

  Future<void> _onConnect(ConnectToServer event, Emitter<ServerState> emit) async {
    final states = _currentStates
      ..[event.server.id] = SshConnectionState.connecting;
    emit(ServerConnecting(
      serverId: event.server.id,
      servers: _currentServers,
      connectionStates: states,
    ));

    try {
      final session = await _ssh.connect(event.server);
      await _repo.touch(event.server.id);
      final updatedStates = _currentStates
        ..[event.server.id] = SshConnectionState.connected;
      emit(ServerConnected(
        serverId: event.server.id,
        session: session,
        servers: _currentServers,
        connectionStates: updatedStates,
      ));
    } catch (e) {
      final updatedStates = _currentStates
        ..[event.server.id] = SshConnectionState.error;
      emit(ServerError(
        message: e.toString(),
        servers: _currentServers,
        connectionStates: updatedStates,
      ));
    }
  }

  Future<void> _onDisconnect(
      DisconnectFromServer event, Emitter<ServerState> emit) async {
    await _ssh.disconnect(event.serverId);
    final states = _currentStates
      ..[event.serverId] = SshConnectionState.disconnected;
    emit(ServersLoaded(servers: _currentServers, connectionStates: states));
  }
}
