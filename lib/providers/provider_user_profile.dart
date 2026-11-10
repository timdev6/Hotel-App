// -----------------------------------------------------------------------
// Filename: provider_user_profile.dart
// Original Author: Dan Grissom
// Updated: October 2026 - Riverpod 3 (no code generation)
// -----------------------------------------------------------------------
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db_helpers/db_user_profile.dart';
import '../db_helpers/firestore_keys.dart';
import '../models/user_profile.dart';
import 'provider_auth.dart';

/// Firestore owns the persisted user profile. Subscription is managed by Riverpod.
/// This emits null when the profile document doesn't exist yet.
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final auth = ref.watch(authUserProvider);
  final user = auth.asData?.value;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance.collection(FS_COL_IC_USER_PROFILES).doc(user.uid).snapshots().map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data['email'] = user.email ?? '';
    return UserProfile.defFromJsonDbObject(data, user.uid);
  });
});

// Sentinel: copyWith(image: null) clears the image, whereas an absent value
// preserves it. No code generation required.
const _unchanged = Object();

class UserProfileState {
  final UserProfile profile;
  final ImageProvider? image;
  final bool dataLoaded;
  final bool imageLoaded;
  final bool internetIssues;
  final bool userChangeInProgress;

  UserProfileState({
    required this.profile,
    this.image,
    this.dataLoaded = false,
    this.imageLoaded = false,
    this.internetIssues = false,
    this.userChangeInProgress = false,
  });

  factory UserProfileState.empty() => UserProfileState(profile: UserProfile.empty());

  UserProfileState copyWith({
    UserProfile? profile,
    Object? image = _unchanged,
    bool? dataLoaded,
    bool? imageLoaded,
    bool? internetIssues,
    bool? userChangeInProgress,
  }) => UserProfileState(
    profile: profile ?? this.profile,
    image: identical(image, _unchanged) ? this.image : image as ImageProvider?,
    dataLoaded: dataLoaded ?? this.dataLoaded,
    imageLoaded: imageLoaded ?? this.imageLoaded,
    internetIssues: internetIssues ?? this.internetIssues,
    userChangeInProgress: userChangeInProgress ?? this.userChangeInProgress,
  );
}

final providerUserProfile = NotifierProvider<ProviderUserProfile, UserProfileState>(ProviderUserProfile.new);

class ProviderUserProfile extends Notifier<UserProfileState> {
  String? _lastUid;
  String? _imageFetchInProgressForUid;

  @override
  UserProfileState build() {
    ref.listen(authUserProvider, (previous, next) {
      if (!ref.mounted || next.isLoading) return;
      final uid = next.asData?.value?.uid;
      if (_lastUid != uid) {
        _lastUid = uid;
        _imageFetchInProgressForUid = null;
        state = UserProfileState.empty();
      }
    });

    // Firestore drives server-to-client updates; no manual subscription.
    ref.listen(userProfileStreamProvider, (previous, next) {
      if (!ref.mounted) return;
      next.whenData((profile) {
        if (profile != null && ref.mounted) {
          updateUserProfile(profile);
        }
      });
    });
    return UserProfileState.empty();
  }

  /// Clone before edits, so listeners always receive a *new* state object.
  UserProfile _editedProfile(void Function(UserProfile) edit) {
    final previous = state.profile;
    final copy = UserProfile(
      previous.uid,
      previous.firstName,
      previous.lastName,
      previous.email,
      previous.permissionLevel,
      previous.accountCreationTime,
      previous.dateLastPasswordChange,
      previous.accountCreationStep,
      isDarkMode: previous.isDarkMode,
    );
    edit(copy);
    return copy;
  }

  void _edit(void Function(UserProfile) edit) {
    state = state.copyWith(profile: _editedProfile(edit));
  }

  bool get dataLoaded => state.dataLoaded;
  PermissionLevel get permissionLevel => state.profile.permissionLevel;
  String get uid => state.profile.uid;
  set uid(String value) => _edit((p) => p.uid = value);
  String get firstName => state.profile.firstName;
  set firstName(String value) => _edit((p) => p.firstName = value);
  String get lastName => state.profile.lastName;
  set lastName(String value) => _edit((p) => p.lastName = value);
  String get wholeName => '$firstName $lastName';
  String get email => state.profile.email;
  set email(String value) => _edit((p) => p.email = value);
  int get accountCreationTime => state.profile.accountCreationTime;
  set accountCreation(int value) => _edit((p) => p.accountCreationTime = value);
  ImageProvider? get userImage => state.image;
  set userImage(ImageProvider? value) => state = state.copyWith(image: value);
  bool get userChangeInProgress => state.userChangeInProgress;
  set userChangeInProgress(bool value) => state = state.copyWith(userChangeInProgress: value);
  DateTime get dateLastPasswordChange => state.profile.dateLastPasswordChange;
  set dateLastPasswordChange(DateTime value) {
    _edit((p) => p.dateLastPasswordChange = value);
    writeUserProfileToDb();
  }

  bool get internetIssues => state.internetIssues;
  set internetIssues(bool value) => state = state.copyWith(internetIssues: value);
  AccountCreationStep get accountCreationStep => state.profile.accountCreationStep;
  set accountCreationStep(AccountCreationStep value) => _edit((p) => p.accountCreationStep = value);
  Future<bool> setDarkMode(bool value) async {
    if (state.profile.isDarkMode == value) return true;
    _edit((profile) => profile.isDarkMode = value);
    return DBUserProfile.writeDarkModePreference(uid, value);
  }

  bool isDeveloper() => permissionLevel == PermissionLevel.DEVELOPER;

  // Kept under its familiar name for screens that call it during logout.
  Future<void> wipeAndCancelDbStream({bool? deletingAccount}) async {
    _imageFetchInProgressForUid = null;
    state = UserProfileState.empty();
    // The Riverpod-owned Firestore stream follows authUserProvider automatically.
  }

  Future<void> updateUserProfile(UserProfile userProfile) async {
    // Prevent a stale stream event from a previous signed-in user.
    if (FirebaseAuth.instance.currentUser?.uid != userProfile.uid) return;
    // Firestore snapshots are the source of truth for profile data. Avoid
    // network token checks here: they can stall or fail while offline.
    // ProviderAuth.ensurePasswordUpToDate remains available if needed for a
    // separate, explicit session validation step.
    if (!ref.mounted || FirebaseAuth.instance.currentUser?.uid != userProfile.uid) return;
    final uidChanged = state.profile.uid != userProfile.uid;
    state = state.copyWith(
      profile: userProfile,
      dataLoaded: true,
      internetIssues: false,
      image: uidChanged ? null : state.image,
      imageLoaded: uidChanged ? false : state.imageLoaded,
    );
    await fetchUserProfileImageIfNeeded();
  }

  Future<bool> fetchUserProfileImageIfNeeded() async {
    final currentUid = uid;
    if (!dataLoaded || currentUid.isEmpty) return false;
    if (state.imageLoaded) return true;
    if (_imageFetchInProgressForUid == currentUid) return false;
    _imageFetchInProgressForUid = currentUid;
    try {
      final image = await DBUserProfile.fetchUserProfileImageFromUid(currentUid, true);
      if (ref.mounted && uid == currentUid && FirebaseAuth.instance.currentUser?.uid == currentUid) {
        state = state.copyWith(image: image, imageLoaded: true);
      }
      // Missing image is normal for a new profile, not a network failure.
      return true;
    } finally {
      if (_imageFetchInProgressForUid == currentUid) {
        _imageFetchInProgressForUid = null;
      }
    }
  }

  Future<void> uploadAndSetNewUserProfileImage(File imageFile) async {
    userImage = FileImage(imageFile);
    await DBUserProfile.uploadNewUserProfileImage(imageFile, this);
    if (ref.mounted) state = state.copyWith(imageLoaded: true);
  }

  Future<void> removeUserProfileImage() async {
    userImage = null;
    await DBUserProfile.deleteUserProfileImage(this);
    if (ref.mounted) state = state.copyWith(imageLoaded: true);
  }

  /// Loads the first snapshot if needed; later changes arrive automatically.
  Future<bool> fetchUserProfileIfNeeded() async {
    if (dataLoaded && uid == FirebaseAuth.instance.currentUser?.uid) return true;
    if (FirebaseAuth.instance.currentUser == null) return false;
    try {
      final profile = await ref.read(userProfileStreamProvider.future);
      if (profile == null || !ref.mounted) return false;
      await updateUserProfile(profile);
      return dataLoaded;
    } catch (_) {
      if (ref.mounted) internetIssues = true;
      return false;
    }
  }

  Future<bool> writeUserProfileToDb({bool merge = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    // The signed-in UID, not a client-supplied value, owns this document.
    final toWrite = _editedProfile((p) {
      p.uid = user.uid;
      p.email = user.email ?? p.email;
    });
    final success = await DBUserProfile.writeUserProfile(toWrite, merge: merge);
    if (success && ref.mounted) {
      state = state.copyWith(profile: toWrite, dataLoaded: true);
    }
    return success;
  }

  Future<void> deleteAccountData() => DBUserProfile.deleteAccountData();
}
