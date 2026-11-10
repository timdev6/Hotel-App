// -----------------------------------------------------------------------
// Filename: screen_login_validation.dart
// Original Author: Dan Grissom
// Updated: October 2026 - Riverpod 3 StreamProvider auth gate
// Keeps the same splash / auth / email verification / onboarding / home flow.
// -----------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/general/widget_scrollable_background.dart';
import '../../widgets/navigation/widget_primary_scaffold.dart';
import '../../widgets/general/widget_annotated_loading.dart';
import '../../providers/provider_user_profile.dart';
import '../../providers/provider_auth.dart';
import '../../models/user_profile.dart';
import 'screen_unverified_email.dart';
import 'screen_profile_setup.dart';
import 'screen_splash.dart';
import 'screen_auth.dart';

class ScreenLoginValidation extends ConsumerWidget {
  static const routeName = '/';
  const ScreenLoginValidation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authResult = ref.watch(authUserProvider);
    final authUi = ref.watch(providerAuth);
    // Read the profile notifier's state to keep its familiar getters and
    // setter methods available to the rest of the original application.
    final localProfile = ref.watch(providerUserProfile);
    Widget child;
    bool loggedIn = false;

    if (authResult.isLoading) {
      child = const ScreenSplash();
    } else if (authResult.hasError) {
      child = WidgetAnnotatedLoading(
        loadingText: 'Authentication unavailable',
        timeOutEnabled: true,
        timeOutTextPrefix: 'Authentication',
      );
    } else if (authResult.asData?.value == null) {
      child = const ScreenAuth();
    } else if (authUi.isSigningOut) {
      child = const WidgetAnnotatedLoading(loadingText: 'Signing Out...');
    } else {
      final user = authResult.asData!.value!;
      final profileResult = ref.watch(userProfileStreamProvider);
      final currentProfile = profileResult.asData?.value;
      final hasCurrentLocalProfile = localProfile.dataLoaded &&
          localProfile.profile.uid == user.uid;
      final profile = currentProfile ??
          (hasCurrentLocalProfile ? localProfile.profile : UserProfile.empty());
      final verified = user.emailVerified || authUi.emailVerified;

      // Permissions from Firestore are display hints only. Elevated operations
      // must also be authorized by server-side rules / custom claims.
      if (ENFORCE_EMAIL_VERIFICATION && !verified &&
          profile.permissionLevel != PermissionLevel.DEVELOPER) {
        child = const ScreenUnverifiedEmail();
      } else if (profileResult.hasError) {
        child = const WidgetAnnotatedLoading(
          loadingText: 'Unable to load profile',
          timeOutEnabled: true,
          timeOutTextPrefix: 'Loading profile',
        );
      } else if (profileResult.isLoading || currentProfile == null ||
                 !hasCurrentLocalProfile) {
        child = const WidgetAnnotatedLoading(
          loadingText: 'Loading Profile...',
          timeOutEnabled: true,
          timeOutTextPrefix: 'Loading profile',
        );
      } else if (profile.accountCreationStep ==
          AccountCreationStep.ACC_STEP_ONBOARDING_PROFILE_CONTACT_INFO) {
        child = const ScreenProfileSetup(isAuth: true);
      } else {
        loggedIn = true;
        child = const WidgetPrimaryScaffold();
      }
    }

    return Scaffold(
      body: ScrollableBackground(
        padding: loggedIn ? 0 : 20,
        child: child,
      ),
    );
  }
}
