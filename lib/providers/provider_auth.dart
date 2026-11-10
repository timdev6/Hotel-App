// -----------------------------------------------------------------------
// Filename: provider_auth.dart
// Original Author: Dan Grissom
// Updated: October 2026 - Riverpod 3 (no code generation)
// Authentication actions are retained. Firebase state is a StreamProvider;
// mutable UI flags are managed as immutable state through Notifier.
// -----------------------------------------------------------------------
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/message_display/popup_dialogue.dart';
import '../util/message_display/snackbar.dart';
import '../util/logging/app_logger.dart';
import 'provider_user_profile.dart';

const bool ENFORCE_EMAIL_VERIFICATION = true;
const int SIGNIN_TIMEOUT_SECS = 15;

enum AuthState { UNKNOWN, AUTHENTICATED, UN_AUTHENTICATED }

/// Firebase owns session state; Riverpod manages subscription/cancellation.
final authUserProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Small immutable state for UI-specific flags, *not* duplicated auth state.
class AuthUiState {
  final bool emailVerified;
  final bool isSigningIn;
  final bool isSigningOut;
  final bool isShowingSplash;

  const AuthUiState({
    this.emailVerified = false,
    this.isSigningIn = false,
    this.isSigningOut = false,
    this.isShowingSplash = false,
  });

  AuthUiState copyWith({
    bool? emailVerified,
    bool? isSigningIn,
    bool? isSigningOut,
    bool? isShowingSplash,
  }) => AuthUiState(
    emailVerified: emailVerified ?? this.emailVerified,
    isSigningIn: isSigningIn ?? this.isSigningIn,
    isSigningOut: isSigningOut ?? this.isSigningOut,
    isShowingSplash: isShowingSplash ?? this.isShowingSplash,
  );
}

final providerAuth = NotifierProvider<ProviderAuth, AuthUiState>(ProviderAuth.new);

/// Keeps the familiar method names for the screens and settings page.
class ProviderAuth extends Notifier<AuthUiState> {
  @override
  AuthUiState build() {
    // Reset per-session UI flags when Firebase authentication changes.
    ref.listen(authUserProvider, (previous, next) {
      if (!ref.mounted) return;
      final user = next.asData?.value;
      if (next.isLoading) return;
      state = AuthUiState(
        emailVerified: user?.emailVerified ?? false,
        isSigningIn: false,
        isSigningOut: false,
      );
    });
    return const AuthUiState();
  }

  ///////////////////////////////////////////////////////////////////
  // Makes sure the user is logged in and has a valid ID token (i.e.,
  // didn't change their password on another device). If they have
  // changed their password after this device was authed, log this
  // device out.
  ///////////////////////////////////////////////////////////////////
  ensurePasswordUpToDate() async {
    // Get the current user's ID token
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    IdTokenResult idTokenResult = await user.getIdTokenResult();
    // DateTime? lastPwChangeTime = _userProfileProvider.dateLastPasswordChange;
    DateTime? lastAuthTime = idTokenResult.authTime;

    // If either time is null, return for now
    if (lastAuthTime == null) return;

    // AppLogger.print("TOKEN - LAST PW CHANGE TIME: ${lastPwChangeTime.toString()}");

    AppLogger.print("TOKEN - LAST AUTH TIME: ${lastAuthTime.toString()}");

    // Whenver the user profile is updated from the DB, first check if the
    // user has authed this device since the last known password change
    // if (lastPwChangeTime.isAfter(lastAuthTime)) {
    //   Show a user-facing message from the widget if signout is required.
    //   await clearAuthedUserDetailsAndSignout();
    // }
  }

  ensureEmailInFirebaseMatchesProfile(userProfile) async {
    // if (authedUserEmail.isNotEmpty) {
    //   if (authedUserEmail != userProfile.email) {
    //     userProfile.email = authedUserEmail;
    //     await DBUserProfile.writeUserProfile(userProfile);
    //   }
    // }
  }

  Future<String> signinWithPassword(String email, String password) async {
    // Set message
    String errorMessage = "";

    // Re-authenticate the user
    try {
      // Attempt to sign in with email/password
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw FirebaseAuthException(code: "timeout");
            },
          );
    } catch (e) {
      if (e is FirebaseAuthException) {
        AppLogger.error("FirebaseAuthException: ${e.code}");
        // Check for specific error codes
        FirebaseAuthException fae = e;
        AppLogger.print("FirebaseAuthException: ${fae.code}");
        if (fae.code == "wrong-password" ||
            fae.code == "user-not-found" ||
            fae.code == "invalid-email" ||
            fae.code == "INVALID_LOGIN_CREDENTIALS" ||
            fae.code == "invalid-credential") {
          errorMessage = "Email/Password is incorrect - please check your credentials and try again";
        } else if (fae.code == "too-many-requests") {
          errorMessage = "Too many failed login attempts - please try again later";
        } else if (fae.code == "timeout") {
          errorMessage = "Login attempt took too long - please check internet connection and try again";
        } else if (fae.code == "network-request-failed") {
          errorMessage = "An network request error occurred - please check internet connection and try again";
        } else {
          errorMessage =
              "An unknown error occurred during authentication - please check internet connection and try again";
        }
      } else {
        errorMessage = "Unable to sign in. Please try again.";
        AppLogger.error("Unexpected sign-in failure: $e");
      }
    }

    // Return error message
    return errorMessage;
  }

  ///////////////////////////////////////////////////////////////////
  // Confirms user's current password (if one was passed in) and then
  // updates the user's password with the new password; returns an empty
  // string if successful and an error message if not.
  ///////////////////////////////////////////////////////////////////
  Future<String> updatePassword(String newPassword, {String? curPassword}) async {
    // Before trying anything with Firestore, do some basic validation
    String errorMessage = _validatePasssword(newPassword);
    if (errorMessage.isNotEmpty) {
      return errorMessage;
    }

    // Attempt to change password
    try {
      // Init variables
      late AuthCredential authCredential;
      User user = FirebaseAuth.instance.currentUser!;

      // If they passed an current password, then validate the current password
      // before trying to change it
      if (curPassword != null) {
        user = FirebaseAuth.instance.currentUser!;
        authCredential = EmailAuthProvider.credential(email: user.email!, password: curPassword);
        UserCredential? authResult = await user.reauthenticateWithCredential(authCredential);
        user = authResult.user!;
      }

      // If we made it here, the user is authenticated and we can update the password
      // Account password updated after reauthentication.
      await user.updatePassword(newPassword);

      // Re-auth with the new password (not completely necessary)
      authCredential = EmailAuthProvider.credential(email: user.email!, password: newPassword);
      await user.reauthenticateWithCredential(authCredential);

      // Password has been updated, we should now log the password change time in the user profile
      // so we can sign out any other instances that are logged in
      // _userProfileProvider.dateLastPasswordChange = dateLastPasswordChange;
    } catch (e) {
      if (e is FirebaseAuthException) {
        // Check for specific error codes
        FirebaseAuthException fae = e;
        if (fae.code == "wrong-password") {
          errorMessage = "Current password is incorrect";
        } else if (fae.code == "weak-password") {
          errorMessage = fae.message?.toString() ?? "Password is too weak";
        } else if (fae.code == "requires-recent-login") {
          errorMessage = "Please re-login to change your password";
        } else {
          errorMessage = "An error occurred checking current password - please try again";
        }
      }
    }

    // Return error message
    return errorMessage;
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Does a check on the password inputted in the Password form. [value] is the
  // value inputted by the user.
  //
  // For this form a valid password must do all of the following:
  // - Be 6 characters in length
  // - Contain 1 letter
  // - Contain 1 digit
  // - Contain 1 symbol
  //
  // Returns: Returns non-empty string if there was an error. Otherwise returns
  // empty String.
  ////////////////////////////////////////////////////////////////////////////////
  String _validatePasssword(String pwCandidate) {
    // The password response message. Error messages are added to the end of it.
    String passwordResponse = "Password must have: ";

    // Has the inputted password tripped an invalidation flag?
    bool invalidPassword = false;

    // How many invalidation flags have been tripped?
    int errorCount = 0;

    // Check if there was a password that was entered.
    if (pwCandidate.isEmpty) {
      return 'Enter a password.';
    } else {
      // Validate the password
      // Make sure the password is at least 6 characters
      if (pwCandidate.length < 6) {
        passwordResponse += "6 characters";
        invalidPassword = true;
        errorCount += 1;
      }

      // Make sure the password contains a letter.
      if (!(RegExp(r"(?=.*[a-z])").hasMatch(pwCandidate) || RegExp(r"(?=.*[A-Z])").hasMatch(pwCandidate))) {
        if (invalidPassword) {
          passwordResponse += ", letter";
        } else {
          passwordResponse += "letter";
          invalidPassword = true;
        }
        errorCount += 1;
      }

      // Make sure the password contains a number.
      if (!(RegExp(r"(?=.*\d)").hasMatch(pwCandidate))) {
        if (invalidPassword) {
          passwordResponse += ", digit";
        } else {
          passwordResponse += "digit";
          invalidPassword = true;
        }
        errorCount += 1;
      }

      // Make sure the password contains a special character.
      if (!(RegExp(r"(?=.*\W)").hasMatch(pwCandidate))) {
        if (invalidPassword) {
          passwordResponse += ", symbol";
        } else {
          passwordResponse += "symbol";
          invalidPassword = true;
        }
        errorCount += 1;
      }

      // Was the password marked as invalid?
      if (invalidPassword) {
        // Punctuate the end of the error with a period.
        passwordResponse += ".";

        // The comma checks to see if there was enough errors to add a comma
        // to the response. (This would be 3)
        if (passwordResponse.contains(", ")) {
          // Grab the index of the last occuring comma
          int lastIndex = passwordResponse.lastIndexOf(", ");

          /// Replace it with either "and" or ", and" for correct grammar
          String endingPhrase = (errorCount > 2) ? ", and" : " and";
          passwordResponse =
              passwordResponse.substring(0, lastIndex) +
              endingPhrase +
              passwordResponse.substring(lastIndex + 1, passwordResponse.length);
        }

        return passwordResponse;
      }

      // Password was good, return empty string
      return "";
    }
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Reauthenticates the user with the provided email and password.
  //
  // Parameters:
  // - email: The email of the user.
  // - password: The password of the user.
  //
  // Returns: A Future that completes with a boolean indicating the success status of the reauthentication.
  ////////////////////////////////////////////////////////////////////////////////
  Future<bool> reauthenticateUser(String password) async {
    try {
      User user = FirebaseAuth.instance.currentUser!;
      AuthCredential authCredential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(authCredential);
    } catch (e) {
      return false;
    }

    // Return true if we made it here
    return true;
  }

  ///////////////////////////////////////////////////////////////////
  // Confirms user's current password and then updates the user's
  // password with the new password; returns an empty string if
  // successful and an error message if not.
  ///////////////////////////////////////////////////////////////////
  Future<String> updateEmail(String newEmail, BuildContext context, {String? curPassword}) async {
    // Set message
    String errorMessage = "";

    // Re-authenticate the user
    try {
      // Init variables
      late AuthCredential authCredential;
      User user = FirebaseAuth.instance.currentUser!;

      // If they passed an current password, then validate the current password
      // before trying to change it
      if (curPassword != null) {
        user = FirebaseAuth.instance.currentUser!;
        authCredential = EmailAuthProvider.credential(email: user.email!, password: curPassword);
        UserCredential? authResult = await user.reauthenticateWithCredential(authCredential);
        user = authResult.user!;
      }

      // If we made it here, the user is authenticated and we can update the email
      await user.verifyBeforeUpdateEmail(newEmail);

      // Inform user that they need to check their e-mail to confirm the change
      Snackbar.show(SnackbarDisplayType.SB_INFO, "Check $newEmail to verify e-mail", context);
      await clearAuthedUserDetailsAndSignout();

      // DO NOT DO B/C of E-MAIL VALIDATION: Email has been updated, we should now write to DB
      //_userProfileProvider.email = newEmail;
      //_userProfileProvider.writeUserProfileToDb();
      //_userProfileProvider.syncProfileNameAndEmailToAcceptedShareRequests();
    } catch (e) {
      if (e is FirebaseAuthException) {
        // Check for specific error codes
        FirebaseAuthException fae = e;
        if (fae.code == "wrong-password") {
          errorMessage = "Current password is incorrect";
        } else if (fae.code == "invalid-email" || (fae.message?.contains("INVALID_NEW_EMAIL") ?? false)) {
          errorMessage = "$newEmail is not a valid e-mail address";
        } else if (fae.code == "email-already-in-use") {
          errorMessage = fae.message?.toString() ?? "$newEmail is already in use by another user";
        } else if (fae.code == "email-already-in-use") {
          errorMessage = fae.message?.toString() ?? "$newEmail is already in use by another user";
        } else {
          errorMessage = "An error occurred updating account - please try again";
          AppLogger.error(e.toString());
          AppLogger.error("fae.code = ${fae.code}");
        }
      } else {
        errorMessage = "An error occurred updating account - please try again";
        AppLogger.error(e.toString());
      }
    }

    // Return error message
    return errorMessage;
  }

  ///////////////////////////////////////////////////////////////////
  // Sign-out and the auth/profile data lifecycles.
  ///////////////////////////////////////////////////////////////////
  Future<void> promptAndClearAuthedUserDetailsAndSignout(BuildContext context) async {
    final confirmed = await PopupDialogue.showConfirm(
      "Are you sure you want to log out?", context,
    ) ?? false;
    if (confirmed) await clearAuthedUserDetailsAndSignout();
  }

  Future<void> clearAuthedUserDetailsAndSignout() async {
    isSigningOut = true;
    try {
      // Do not terminate Firestore or clearPersistence while snapshots are
      // active; the profile StreamProvider reacts to the auth state change.
      await FirebaseAuth.instance.signOut();
      if (ref.mounted) {
        await ref.read(providerUserProfile.notifier).wipeAndCancelDbStream();
      }
    } finally {
      if (ref.mounted) state = const AuthUiState();
    }
  }

  // Kept for existing callers; live profile updates now come from Riverpod.
  Future<void> loadAuthedUserDetailsUponSignin() async {
    final profile = ref.read(providerUserProfile.notifier);
    await profile.fetchUserProfileIfNeeded();
    if (ref.mounted) await profile.fetchUserProfileImageIfNeeded();
  }

  AuthState get authState {
    final asyncUser = ref.read(authUserProvider);
    if (asyncUser.isLoading || asyncUser.hasError) return AuthState.UNKNOWN;
    return asyncUser.asData?.value == null
        ? AuthState.UN_AUTHENTICATED : AuthState.AUTHENTICATED;
  }

  bool get justLoggedIn => authState == AuthState.AUTHENTICATED;
  bool get emailVerified => state.emailVerified;
  set emailVerified(bool value) => state = state.copyWith(emailVerified: value);
  bool get isSigningIn => state.isSigningIn;
  set isSigningIn(bool value) => state = state.copyWith(isSigningIn: value);
  bool get isSigningOut => state.isSigningOut;
  set isSigningOut(bool value) => state = state.copyWith(isSigningOut: value);
  bool get isShowingSplash => state.isShowingSplash;
  set isShowingSplash(bool value) => state = state.copyWith(isShowingSplash: value);
  String get authedUserEmail => FirebaseAuth.instance.currentUser?.email ?? "";
}
