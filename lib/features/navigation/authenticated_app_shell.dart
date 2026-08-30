import 'package:flutter/material.dart';

import '../community/community_screen.dart';
import '../home/home_screen.dart';
import '../profile/screens/profile_view_screen.dart';

class AuthenticatedAppShell extends StatefulWidget {
  const AuthenticatedAppShell({super.key});

  @override
  State<AuthenticatedAppShell> createState() => _AuthenticatedAppShellState();
}

class _AuthenticatedAppShellState extends State<AuthenticatedAppShell> {
  int _selectedIndex = 0;
  final _visited = <bool>[true, false, false];

  List<Widget> get _destinations => [
    const HomeScreen(embeddedInRootShell: true),
    _visited[1] ? const CommunityScreen() : const SizedBox.shrink(),
    _visited[2] ? const ProfileViewScreen() : const SizedBox.shrink(),
  ];

  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
      _visited[index] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _destinations),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectDestination,
          destinations: const [
            NavigationDestination(
              key: Key('nav-trips'),
              icon: Icon(Icons.luggage_outlined),
              selectedIcon: Icon(Icons.luggage),
              label: 'Trips',
            ),
            NavigationDestination(
              key: Key('nav-community'),
              icon: Icon(Icons.public_outlined),
              selectedIcon: Icon(Icons.public),
              label: 'Community',
            ),
            NavigationDestination(
              key: Key('nav-profile'),
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
