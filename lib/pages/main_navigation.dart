import 'package:flutter/material.dart';
import 'package:localshare/pages/send_tab.dart';
import 'package:localshare/pages/receive_tab.dart';
import 'package:localshare/pages/settings.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _hideNavigation = false;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.add(
      SendTab(
        onQrScannerVisibilityChanged: (hide) {
          setState(() => _hideNavigation = hide);
        },
      ),
    );
    _pages.add(const ReceiveTab());
    _pages.add(const SettingsTab());
  }

  @override
  Widget build(BuildContext context) {
    // return Scaffold(
    //   body: _pages[_currentIndex],
    //   bottomNavigationBar: BottomNavigationBar(
    //     currentIndex: _currentIndex,
    //     onTap: (index) => setState(() => _currentIndex = index),
    //     items: const [
    //       BottomNavigationBarItem(icon: Icon(Icons.send), label: 'Send'),
    //       BottomNavigationBarItem(icon: Icon(Icons.download), label: 'Receive'),
    //       BottomNavigationBarItem(
    //         icon: Icon(Icons.settings),
    //         label: 'Settings',
    //       ),
    //     ],
    //   ),
    // );
    return Scaffold(
      // backgroundColor: const Color(0xFF2C1D4D),
      body: _pages[_currentIndex],
      bottomNavigationBar:
          _hideNavigation
              ? null
              : NavigationBar(
                selectedIndex: _currentIndex,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.send), label: 'Send'),
                  NavigationDestination(
                    icon: Icon(Icons.download),
                    label: 'Receive',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
                onDestinationSelected:
                    (index) => setState(() => _currentIndex = index),
              ),
    );
  }
}
