// -----------------------------------------------------------------------
// Filename: widget_primary_scaffold.dart
// Original Author: Dan Grissom
// Creation Date: 5/27/2024
// Copyright: (c) 2024 CSC322
// Description: This file contains the primary scaffold for the app.

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////
// Dart imports

// Flutter external package imports
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

// App relative file imports
import '../../screens/general/screen_profile.dart';
import '../../screens/general/screen_home.dart';
import '../../screens/general/screen_book.dart';
import '../../screens/general/screen_dining.dart';
import 'widget_primary_app_bar.dart';
import 'widget_app_drawer.dart';

//////////////////////////////////////////////////////////////////////////
// Localized provider for the current tab index
//////////////////////////////////////////////////////////////////////////
class PrimaryBottomNavTabIndex extends Notifier<int> {
  @override
  int build() => 0;

  void selectTab(int index) => state = index;
}

final providerPrimaryBottomNavTabIndex =
    NotifierProvider<PrimaryBottomNavTabIndex, int>(
      PrimaryBottomNavTabIndex.new,
    );

//////////////////////////////////////////////////////////////////////////
// StateFUL widget which manages state. Simply initializes the
// state object.
//////////////////////////////////////////////////////////////////////////
class WidgetPrimaryScaffold extends ConsumerStatefulWidget {
  static const routeName = "/home";

  const WidgetPrimaryScaffold({super.key});

  @override
  // ignore: library_private_types_in_public_api
  ConsumerState<WidgetPrimaryScaffold> createState() =>
      _WidgetPrimaryScaffoldState();
}

//////////////////////////////////////////////////////////////////////////
// The actual STATE which is managed by the above widget.
//////////////////////////////////////////////////////////////////////////
class _WidgetPrimaryScaffoldState extends ConsumerState<WidgetPrimaryScaffold> {
  // The "instance variables" managed in this state
  var _isInit = true;

  @override
  void initState() {
    super.initState();
  }

  ////////////////////////////////////////////////////////////////////////
  // Gets the current state of the providers for consumption on
  // this page
  ////////////////////////////////////////////////////////////////////////
  Future<void> _init() async {
    // Get providers
  }

  ////////////////////////////////////////////////////////////////
  // Runs the following code once upon initialization
  ////////////////////////////////////////////////////////////////
  @override
  void didChangeDependencies() {
    // If first time running this code, update provider settings
    if (_isInit) {
      _init();
    }

    // Now initialized; run super method
    _isInit = false;
    super.didChangeDependencies();
  }

  ////////////////////////////////////////////////////////////////
  // Takes in the current tab index and returns the appropriate
  // screen to display.
  ////////////////////////////////////////////////////////////////
  Widget _getScreenToDisplay(int currentTabIndex) {
    switch (BottomNavSelection.values[currentTabIndex]) {
      case BottomNavSelection.HOME_SCREEN:
        return ScreenHome();
      case BottomNavSelection.BOOK_SCREEN:
        return const ScreenBook();
      case BottomNavSelection.DINING_SCREEN:
        return const ScreenDining();
      case BottomNavSelection.PROFILE_SCREEN:
        return ScreenProfile();
    }
  }

  ////////////////////////////////////////////////////////////////
  // Takes in the current tab index and returns the appropriate
  // app bar widget to display.
  ////////////////////////////////////////////////////////////////
  Widget _getAppBarTitle(int currentTabIndex) {
    return Text(BottomNavSelection.values[currentTabIndex].label);
  }

  ////////////////////////////////////////////////////////////////
  // Takes in the current tab index and returns the appropriate
  // actions to display in the app bar (right side).
  ////////////////////////////////////////////////////////////////
  List<Widget>? _getAppBarActions(int currentTabIndex) {
    // Initialize the actions
    List<Widget> actions = [];

    // If not chat tab, return null (no actions)
    return actions.isEmpty ? null : actions;
  }

  ////////////////////////////////////////////////////////////////
  // Primary Flutter method overriden which describes the layout
  // and bindings for this widget.
  ////////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    // Get providers
    final currentTabIndex = ref.watch(providerPrimaryBottomNavTabIndex);

    return Scaffold(
      appBar: WidgetPrimaryAppBar(
        actionButtons: _getAppBarActions(currentTabIndex),
        title: _getAppBarTitle(currentTabIndex),
      ),
      drawer: WidgetAppDrawer(),
      body: _getScreenToDisplay(currentTabIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentTabIndex,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) {
          ref.read(providerPrimaryBottomNavTabIndex.notifier).selectTab(index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'Book'),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Dining',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
