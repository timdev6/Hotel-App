import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/provider_user_profile.dart';
import '../../screens/general/screen_book.dart';
import '../../screens/general/screen_dining.dart';
import '../../screens/general/screen_home.dart';
import '../../screens/general/screen_profile.dart';
import 'widget_app_drawer.dart';
import 'widget_primary_app_bar.dart';

class PrimaryBottomNavTabIndex extends Notifier<int> {
  @override
  int build() => 0;

  void selectTab(int index) => state = index;
}

final providerPrimaryBottomNavTabIndex =
    NotifierProvider<PrimaryBottomNavTabIndex, int>(
      PrimaryBottomNavTabIndex.new,
    );

class WidgetPrimaryScaffold extends ConsumerWidget {
  static const routeName = '/home';

  const WidgetPrimaryScaffold({super.key});

  Widget _screenFor(BottomNavSelection selection) {
    switch (selection) {
      case BottomNavSelection.HOME_SCREEN:
        return ScreenHome();
      case BottomNavSelection.BOOK_SCREEN:
        return const ScreenBook();
      case BottomNavSelection.DINING_SCREEN:
        return const ScreenDining();
      case BottomNavSelection.PROFILE_SCREEN:
        return const ScreenProfile();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(providerPrimaryBottomNavTabIndex);
    final profile = ref.watch(providerUserProfile).profile;
    final initials =
        '${profile.firstName.isNotEmpty ? profile.firstName[0] : ''}'
        '${profile.lastName.isNotEmpty ? profile.lastName[0] : ''}'
            .toUpperCase();

    return Scaffold(
      appBar: WidgetPrimaryAppBar(
        title: Text(BottomNavSelection.values[tabIndex].label),
        actionButtons: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => ref
                  .read(providerPrimaryBottomNavTabIndex.notifier)
                  .selectTab(BottomNavSelection.PROFILE_SCREEN.index),
              child: CircleAvatar(
                radius: 18,
                child: initials.isEmpty
                    ? const Icon(Icons.person)
                    : Text(initials),
              ),
            ),
          ),
        ],
      ),
      drawer: WidgetAppDrawer(),
      body: _screenFor(BottomNavSelection.values[tabIndex]),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: tabIndex,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        onTap: (index) => ref
            .read(providerPrimaryBottomNavTabIndex.notifier)
            .selectTab(index),
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
