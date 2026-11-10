// -----------------------------------------------------------------------
// Filename: db_user_profile.dart
// Original Author: Dan Grissom
// Creation Date: 5/22/2024
// Copyright: (c) 2024 CSC322
// Description: This file contains the database helper functions for user
//              profiles.

////////////////////////////////////////////////////////////////////////////////////////////
// Imports
////////////////////////////////////////////////////////////////////////////////////////////
// Dart imports
import 'dart:async';
import 'dart:io';

// Flutter external package imports
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

// App relative file imports
import '../providers/provider_user_profile.dart';
import '../util/logging/app_logger.dart';
import '../models/user_profile.dart';
import 'firestore_keys.dart';

////////////////////////////////////////////////////////////////////////////////////////////
// Class definition for DB Helper
////////////////////////////////////////////////////////////////////////////////////////////
class DBUserProfile {
  // Static variables
  static StreamSubscription? _profileUpdateStream;

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Legacy helper API retained for callers; streams are now owned by Riverpod.
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<void> cancelProfileUpdateStream() async {}

  static Future<bool> fetchUserProfileAndSyncProvider(ProviderUserProfile providerUserProfile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final doc = await FirebaseFirestore.instance.collection(FS_COL_IC_USER_PROFILES).doc(user.uid).get();
      if (!doc.exists || doc.data() == null) return false;
      final data = Map<String, dynamic>.from(doc.data()!);
      data['email'] = user.email ?? '';
      await providerUserProfile.updateUserProfile(UserProfile.defFromJsonDbObject(data, user.uid));
      return providerUserProfile.dataLoaded;
    } catch (e) {
      AppLogger.error('Encountered problem loading user profile from firestore: $e');
      return false;
    }
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Writes the provided user profile to the database
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<bool> writeUserProfile(UserProfile userProfile, {merge = true}) async {
    // Initialize success variable
    bool success = false;

    // Get Firebase instance
    var db = FirebaseFirestore.instance;
    if (FirebaseAuth.instance.currentUser != null) {
      // Get the authenticated firebase user
      final FirebaseAuth auth = FirebaseAuth.instance;
      final User? user = auth.currentUser;

      // If no user logged in, return; otherwise continue
      if (user == null) {
        return false;
      }
      String uid = user.uid;

      // Try to get the user's data from firestore
      try {
        // Attempt to write data
        await db.collection(FS_COL_IC_USER_PROFILES).doc(uid).set(userProfile.toJsonForDb(), SetOptions(merge: merge));
        success = true;
      } catch (e) {
        AppLogger.error("Encountered problem writing user profile to firestore.$e");

        success = false;
      }
    }

    // Return status
    return success;
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Writes the dark mode preference for the specified user to the database
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<bool> writeDarkModePreference(String uid, bool isDarkMode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != uid) return false;

    try {
      await FirebaseFirestore.instance.collection(FS_COL_IC_USER_PROFILES).doc(uid).set({
        FS_KEY_DARK_MODE: isDarkMode,
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      AppLogger.error('Encountered problem writing dark mode preference to Firestore: $e');
      return false;
    }
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Pulls the Firebase user's user profile image from Cloud Storage and uses the passed in
  // provider to update displays througout the app.
  //
  // Returns true if image data was fetched and set in provider; false otherwise
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<bool> fetchUserProfileImageAndSyncProvider(ProviderUserProfile providerUserProfile) async {
    // Initialize success variable
    bool success = false;

    // Get a Google Storage reference to the profile picture
    final ref = FirebaseStorage.instance.ref().child(
      'users/${providerUserProfile.uid}/profile_picture/userProfilePicture.jpg',
    );

    // Try to download the image
    try {
      Uint8List? imageData = await ref.getData();
      if (imageData == null) {
        providerUserProfile.userImage = null;
      } else {
        providerUserProfile.userImage = MemoryImage(imageData);
      }
      //var url = await ref.getDownloadURL();
      //userProfileProvider.userImage = NetworkImage(url);
      success = true;
    } catch (e) {
      // If ref is bad/incomplete, set to local image
      providerUserProfile.userImage = null;
    }

    // Return status
    return success;
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Attempts to pull a profile picture from Cloud Storage using a UID that is passed in. Only
  // attempts fetch if the attemptFetch parameter is true; otherwise, returns default icon.
  //
  // Returns an image (MIC logo if no image retreived)
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<ImageProvider?> fetchUserProfileImageFromUid(String uid, bool attemptFetch) async {
    if (attemptFetch) {
      // Get a Google Storage reference to the profile picture
      final ref = FirebaseStorage.instance.ref().child('users/$uid/profile_picture/userProfilePicture.jpg');

      // Try to download the image
      try {
        Uint8List? imageData = await ref.getData();
        if (imageData != null) {
          return MemoryImage(imageData);
        }
      } catch (e) {
        AppLogger.error("Failed to fetch user profile image from uid: $e");
      }
    }

    // If image fetch failed, return null
    return null;
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Uplads the user profile image to Google Cloud Storage
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<bool> uploadNewUserProfileImage(File imageFile, ProviderUserProfile providerUserProfile) async {
    // Initialize success variable
    bool success = false;

    try {
      // Get a reference to the logged-in user's profile pic and upload the new picture
      final gcsPath = 'users/${providerUserProfile.uid}/profile_picture/userProfilePicture.jpg';
      final ref = FirebaseStorage.instance.ref().child(gcsPath);

      // Get existing metadata, upload the file, and then re-upload the metadata
      try {
        final existingMetadata = await ref.getMetadata();
        await ref.putFile(
          imageFile,
          SettableMetadata(customMetadata: existingMetadata.customMetadata ?? <String, String>{}),
        );
      } catch (e) {
        Map<String, String> customMetadata = {};
        await ref.putFile(imageFile, SettableMetadata(customMetadata: customMetadata));
      }
      success = true;
    } catch (e) {
      AppLogger.error("Failed To Upload: $e");

      success = false;
    }

    return success;
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Deletes the user profile image from Google Cloud Storage
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<bool> deleteUserProfileImage(ProviderUserProfile providerUserProfile) async {
    // Initialize success variable
    bool success = false;

    try {
      // Get a reference to the logged-in user's profile pic and upload the new picture
      final gcsPath = 'users/${providerUserProfile.uid}/profile_picture/userProfilePicture.jpg';
      final ref = FirebaseStorage.instance.ref().child(gcsPath);
      await ref.delete();
      success = true;
    } catch (e) {
      success = false;
    }

    return success;
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Deletes the account data associated with the current user.
  //
  // Returns: A Future that completes when the account data is successfully deleted.
  ////////////////////////////////////////////////////////////////////////////////
  static Future<void> deleteAccountData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser; // Retrieve the currently authenticated user
      if (currentUser == null) {
        return; // Exit the method if the user is null
      }
      String userID = currentUser.uid; // User ID
      await FirebaseFirestore.instance
          .collection(FS_COL_IC_USER_PROFILES)
          .doc(userID)
          .delete(); // Delete the document associated with the user ID from the "FS_COL_MIC_USER_PROFILES" collection

      AppLogger.print('Document deleted successfully!');
    } catch (e) {
      AppLogger.error('Error deleting document: $e');
    }
  }
}
