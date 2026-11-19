// -----------------------------------------------------------------------
// Filename: screen_profile.dart
// Original Author: Dan Grissom
// Creation Date: 10/31/2024
// Copyright: (c) 2024 CSC322
// Description: This file contains the profile page.

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////

// Flutter imports
import 'dart:async';

// Flutter external package imports
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

// App file relative imports
import '../../providers/provider_user_profile.dart';
import '../settings/screen_profile_edit.dart';
import '../settings/screen_settings.dart';

//////////////////////////////////////////////////////////////////////////
// StateFUL widget which manages state. Simply initializes the state object.
//////////////////////////////////////////////////////////////////////////
class ScreenProfile extends ConsumerStatefulWidget {
  static const routeName = '/profile';

  const ScreenProfile({super.key});

  @override
  ConsumerState<ScreenProfile> createState() => _ScreenProfileState();
}

//////////////////////////////////////////////////////////////////////////
// The actual STATE which is managed by the above widget.
//////////////////////////////////////////////////////////////////////////
class _ScreenProfileState extends ConsumerState<ScreenProfile> {
  // The "instance variables" managed in this state
  bool _isInit = true;

  ////////////////////////////////////////////////////////////////
  // Runs the following code once upon initialization
  ////////////////////////////////////////////////////////////////
  @override
  void didChangeDependencies() {
    // If first time running this code, update provider settings
    if (_isInit) {
      _init();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
  }

  ////////////////////////////////////////////////////////////////
  // Initializes state variables and resources
  ////////////////////////////////////////////////////////////////
  Future<void> _init() async {}

  //////////////////////////////////////////////////////////////////////////
  // Primary Flutter method overridden which describes the layout and bindings for this widget.
  //////////////////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    // Return the scaffold
    
    final profile = ref.watch(providerUserProfile).profile;
    final String fullName = '${profile.firstName} ${profile.lastName}';
    const int points = 0;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: Icon(Icons.account_circle, size: 96)),
          const SizedBox(height: 8),
          Center(child: Text(fullName, style: Theme.of(context).textTheme.headlineSmall)),
          Center(child: Text(profile.email)),
          const SizedBox(height: 16),
          Card(
            // fix before vid
            child: InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    const Text('Silver Member'),
                    const SizedBox(height: 8),
                    
                    Text('$points pts', style: Theme.of(context).textTheme.headlineSmall),

                    const SizedBox(height: 8),
                    const LinearProgressIndicator(value: 0),

                    const SizedBox(height: 8),
                    const Text('Member Since —'),
                    ],

                  
                ),
                
              ),
            ),

            
          ),

          //do before work
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: Column(children: [Text('0'), Text('Stays')])),
              
              Expanded(child: Column(children: [Text('0'), Text('Nights')])),
              
              Expanded(child: Column(children: [Text('0'), Text('Dining')])),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('My Stays'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(ScreenProfileEdit.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(ScreenSettings.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log Out'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
