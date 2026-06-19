// lib/bloc/profile_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

// Events
sealed class ProfileEvent extends Equatable {
  @override
  List<Object?> get props => [];
}
class LoadProfiles extends ProfileEvent {}
class AddProfile extends ProfileEvent {
  final CredentialProfile profile;
  AddProfile(this.profile);
  @override List<Object?> get props => [profile];
}
class UpdateProfile extends ProfileEvent {
  final CredentialProfile profile;
  UpdateProfile(this.profile);
  @override List<Object?> get props => [profile];
}
class DeleteProfile extends ProfileEvent {
  final String id;
  DeleteProfile(this.id);
  @override List<Object?> get props => [id];
}

// States
sealed class ProfileState extends Equatable {
  @override List<Object?> get props => [];
}
class ProfileInitial extends ProfileState {}
class ProfilesLoaded extends ProfileState {
  final List<CredentialProfile> profiles;
  ProfilesLoaded(this.profiles);
  @override List<Object?> get props => [profiles];
}
class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
  @override List<Object?> get props => [message];
}

// BLoC
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _repo;
  ProfileBloc(this._repo) : super(ProfileInitial()) {
    on<LoadProfiles>((e, emit) async {
      emit(ProfilesLoaded(await _repo.getAll()));
    });
    on<AddProfile>((e, emit) async {
      await _repo.save(e.profile);
      emit(ProfilesLoaded(await _repo.getAll()));
    });
    on<UpdateProfile>((e, emit) async {
      await _repo.save(e.profile);
      emit(ProfilesLoaded(await _repo.getAll()));
    });
    on<DeleteProfile>((e, emit) async {
      await _repo.delete(e.id);
      emit(ProfilesLoaded(await _repo.getAll()));
    });
  }
}
