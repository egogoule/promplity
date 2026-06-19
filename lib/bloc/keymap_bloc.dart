// lib/bloc/keymap_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

// Events
sealed class KeymapEvent extends Equatable {
  @override List<Object?> get props => [];
}
class LoadKeybindings extends KeymapEvent {}
class SaveKeybinding extends KeymapEvent {
  final KeymapBinding binding;
  SaveKeybinding(this.binding);
  @override List<Object?> get props => [binding];
}
class DeleteKeybinding extends KeymapEvent {
  final String id;
  DeleteKeybinding(this.id);
  @override List<Object?> get props => [id];
}
class ResetDefaultKeybindings extends KeymapEvent {}

// States
sealed class KeymapState extends Equatable {
  @override List<Object?> get props => [];
}
class KeymapInitial extends KeymapState {}
class KeymapLoaded extends KeymapState {
  final List<KeymapBinding> bindings;
  KeymapLoaded(this.bindings);
  @override List<Object?> get props => [bindings];
}

// BLoC
class KeymapBloc extends Bloc<KeymapEvent, KeymapState> {
  final KeymapRepository _repo;
  KeymapBloc(this._repo) : super(KeymapInitial()) {
    on<LoadKeybindings>((e, emit) async {
      emit(KeymapLoaded(await _repo.getAll()));
    });
    on<SaveKeybinding>((e, emit) async {
      await _repo.save(e.binding);
      emit(KeymapLoaded(await _repo.getAll()));
    });
    on<DeleteKeybinding>((e, emit) async {
      await _repo.delete(e.id);
      emit(KeymapLoaded(await _repo.getAll()));
    });
    on<ResetDefaultKeybindings>((e, emit) async {
      await _repo.resetDefaults();
      emit(KeymapLoaded(await _repo.getAll()));
    });
  }
}
