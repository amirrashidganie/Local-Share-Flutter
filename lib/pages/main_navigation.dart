import 'package:flutter/material.dart';
import 'package:localshare/pages/send_tab.dart';
import 'package:localshare/pages/receive_tab.dart';
import 'package:localshare/pages/settings_tab.dart';
import 'package:localshare/utils/auto_scan_manager.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _hideNavigation = false;
  final AutoScanManager _autoScanManager = AutoScanManager();

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

    // Enable auto-scan initially since we start on SendTab (index 0)
    _autoScanManager.enable();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                onDestinationSelected: (index) {
                  // Control auto-scan based on tab selection
                  if (index == 0) {
                    // SendTab - enable auto-scan
                    _autoScanManager.enable();
                  } else {
                    // Other tabs - disable auto-scan
                    _autoScanManager.disable();
                  }

                  setState(() => _currentIndex = index);
                },
              ),
    );
  }
}
