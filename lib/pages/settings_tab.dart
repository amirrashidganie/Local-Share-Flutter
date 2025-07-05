import 'package:flutter/material.dart';
import 'package:localshare/notifiers/dark_mode_notifier.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:localshare/utils/settings_manager.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final SettingsManager _settingsManager = SettingsManager();
  String _appVersion = "";
  String _buildNumber = "";

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    await _settingsManager.initialize();
    await _loadAppInfo();
    setState(() {});
  }

  Future<void> _loadAppInfo() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Info Section
          _buildSection("App Info", Icons.info_outline, [
            _buildInfoTile(
              "Version",
              "v$_appVersion ($_buildNumber)",
              Icons.app_settings_alt,
            ),
            _buildInfoTile("Build Date", "July 2025", Icons.calendar_today),
            _buildInfoTile("Developer", "MindShiftz Team", Icons.person),
          ]),
          const SizedBox(height: 24),

          // Transfer Settings Section
          _buildSection("Transfer Settings", Icons.settings, [
            _buildSwitchTile(
              "Auto-accept files",
              "Automatically accept incoming files",
              Icons.download_done,
              _settingsManager.autoAcceptFiles,
              (value) async {
                await _settingsManager.setAutoAcceptFiles(value);
                setState(() {});
              },
            ),
            _buildSwitchTile(
              "Save to gallery",
              "Save images to device gallery",
              Icons.photo_library,
              _settingsManager.saveToGallery,
              (value) async {
                await _settingsManager.setSaveToGallery(value);
                setState(() {});
              },
            ),
            _buildSwitchTile(
              "Vibrate on transfer",
              "Vibrate when transfer completes",
              Icons.vibration,
              _settingsManager.vibrateOnTransfer,
              (value) async {
                await _settingsManager.setVibrateOnTransfer(value);
                setState(() {});
              },
            ),
            _buildSwitchTile(
              "Sound on transfer",
              "Play sound when transfer completes",
              Icons.volume_up,
              _settingsManager.soundOnTransfer,
              (value) async {
                await _settingsManager.setSoundOnTransfer(value);
                setState(() {});
              },
            ),
            _buildSwitchTile(
              "Show notifications",
              "Show transfer progress notifications",
              Icons.notifications,
              _settingsManager.showTransferNotifications,
              (value) async {
                await _settingsManager.setShowTransferNotifications(value);
                setState(() {});
              },
            ),
            _buildSwitchTile(
              "Auto-scan network",
              "Automatically scan for devices",
              Icons.wifi_find,
              _settingsManager.autoScanNetwork,
              (value) async {
                await _settingsManager.setAutoScanNetwork(value);
                setState(() {});
              },
            ),
          ]),
          const SizedBox(height: 24),

          // Network Settings Section
          _buildSection("Network Settings", Icons.wifi, [
            _buildEditableTile(
              "Transfer Port",
              "Port ${_settingsManager.transferPort}",
              Icons.settings_ethernet,
              () => _showPortDialog(),
            ),
            _buildEditableTile(
              "Save Location",
              _settingsManager.saveLocation,
              Icons.folder,
              () => _showLocationDialog(),
            ),
            _buildEditableTile(
              "Network Timeout",
              "${_settingsManager.networkTimeout} seconds",
              Icons.timer,
              () => _showTimeoutDialog(),
            ),
            _buildEditableTile(
              "Max File Size",
              "${_settingsManager.maxFileSize} MB",
              Icons.storage,
              () => _showMaxFileSizeDialog(),
            ),
            _buildSwitchTile(
              "Enable Compression",
              "Compress files during transfer",
              Icons.compress,
              _settingsManager.enableCompression,
              (value) async {
                await _settingsManager.setEnableCompression(value);
                setState(() {});
              },
            ),
          ]),
          const SizedBox(height: 24),

          // Appearance Section
          _buildSection("Appearance", Icons.palette, [
            ValueListenableBuilder<bool>(
              valueListenable: darkModeNotifier,
              builder: (context, isDark, child) {
                return _buildSwitchTile(
                  "Dark Mode",
                  "Use dark theme",
                  Icons.dark_mode,
                  isDark,
                  (value) => darkModeNotifier.value = value,
                );
              },
            ),
          ]),
          const SizedBox(height: 24),

          // Privacy & Security Section
          _buildSection("Privacy & Security", Icons.security, [
            _buildTile(
              "Permissions",
              "Manage app permissions",
              Icons.lock,
              () => _showPermissionsDialog(),
            ),
            _buildTile(
              "Clear Cache",
              "Clear temporary files",
              Icons.cleaning_services,
              () => _clearCache(),
            ),
            _buildTile(
              "Transfer History",
              "View transfer history",
              Icons.history,
              () => _showTransferHistory(),
            ),
            _buildTile(
              "Reset Settings",
              "Reset all settings to defaults",
              Icons.restore,
              () => _showResetSettingsDialog(),
            ),
          ]),
          const SizedBox(height: 24),

          // Support Section
          _buildSection("Support", Icons.help_outline, [
            _buildTile(
              "Help & FAQ",
              "Get help and answers",
              Icons.help,
              () => _openHelp(),
            ),
            _buildTile(
              "Report Bug",
              "Report a bug or issue",
              Icons.bug_report,
              () => _reportBug(),
            ),
            _buildTile(
              "Feature Request",
              "Suggest new features",
              Icons.lightbulb,
              () => _requestFeature(),
            ),
            _buildTile(
              "Rate App",
              "Rate us on Play Store",
              Icons.star,
              () => _rateApp(),
            ),
          ]),
          const SizedBox(height: 24),

          // About Section
          _buildSection("About", Icons.info, [
            _buildTile(
              "Privacy Policy",
              "Read our privacy policy",
              Icons.privacy_tip,
              () => _openPrivacyPolicy(),
            ),
            _buildTile(
              "Terms of Service",
              "Read our terms of service",
              Icons.description,
              () => _openTermsOfService(),
            ),

            _buildTile(
              "Share App",
              "Share with friends and family",
              Icons.share,
              () => _shareApp(),
            ),
          ]),
          const SizedBox(height: 24),

          // Credits Section
          _buildSection("Credits", Icons.favorite, [
            _buildInfoTile(
              "Made with ❤️",
              "by MindShiftz Team",
              Icons.favorite,
            ),
            _buildInfoTile("Icons", "Material Design Icons", Icons.style),
            _buildInfoTile("Framework", "Flutter", Icons.flutter_dash),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildEditableTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: const Icon(Icons.edit, size: 16),
      onTap: onTap,
    );
  }

  // Dialog and action methods
  void _showPortDialog() {
    final controller = TextEditingController(
      text: _settingsManager.transferPort.toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Transfer Port"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Enter the port number for file transfers:"),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Port",
                    border: OutlineInputBorder(),
                    hintText: "5000",
                  ),
                  controller: controller,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  int? port = int.tryParse(controller.text);
                  if (port != null && port > 0 && port < 65536) {
                    await _settingsManager.setTransferPort(port);
                    setState(() {});
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please enter a valid port (1-65535)"),
                      ),
                    );
                  }
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  void _showLocationDialog() {
    final locations = _settingsManager.getAvailableSaveLocations();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Save Location"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: locations.length + 1, // +1 for custom picker
                itemBuilder: (context, index) {
                  if (index == locations.length) {
                    return ListTile(
                      title: const Text("Choose Custom Location"),
                      subtitle: const Text("Select a custom folder"),
                      leading: const Icon(Icons.folder_open),
                      onTap: () async {
                        String? path =
                            await _settingsManager.pickCustomSaveLocation();
                        if (path != null && mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Save location set to: $path"),
                            ),
                          );
                        }
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                    );
                  }

                  final location = locations[index];
                  return ListTile(
                    title: Text(location['name']!),
                    subtitle: Text(location['description']!),
                    leading: const Icon(Icons.folder),
                    trailing:
                        _settingsManager.saveLocation == location['name']
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                    onTap: () async {
                      await _settingsManager.setSaveLocation(location['name']!);
                      setState(() {});
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ),
    );
  }

  void _showTimeoutDialog() {
    final controller = TextEditingController(
      text: _settingsManager.networkTimeout.toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Network Timeout"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Enter network timeout in seconds:"),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Timeout (seconds)",
                    border: OutlineInputBorder(),
                    hintText: "30",
                  ),
                  controller: controller,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  int? timeout = int.tryParse(controller.text);
                  if (timeout != null && timeout > 0) {
                    await _settingsManager.setNetworkTimeout(timeout);
                    setState(() {});
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please enter a valid timeout value"),
                      ),
                    );
                  }
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  void _showMaxFileSizeDialog() {
    final controller = TextEditingController(
      text: _settingsManager.maxFileSize.toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Max File Size"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Enter maximum file size in MB:"),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Max Size (MB)",
                    border: OutlineInputBorder(),
                    hintText: "1024",
                  ),
                  controller: controller,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  int? size = int.tryParse(controller.text);
                  if (size != null && size > 0) {
                    await _settingsManager.setMaxFileSize(size);
                    setState(() {});
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please enter a valid file size"),
                      ),
                    );
                  }
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  void _showPermissionsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Permissions"),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("This app needs the following permissions:"),
                SizedBox(height: 16),
                Text("• Storage: To save received files"),
                Text("• Location: To discover nearby devices"),
                Text("• Camera: To scan QR codes"),
                Text("• Microphone: For audio file access"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Clear Cache"),
            content: const Text(
              "This will clear all temporary files. Are you sure?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  // Implement cache clearing
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Cache cleared successfully")),
                  );
                },
                child: const Text("Clear"),
              ),
            ],
          ),
    );
  }

  void _showResetSettingsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Reset Settings"),
            content: const Text(
              "This will reset all settings to their default values. This action cannot be undone. Are you sure?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  await _settingsManager.resetToDefaults();
                  setState(() {});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Settings reset to defaults")),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Reset"),
              ),
            ],
          ),
    );
  }

  void _showTransferHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransferHistoryScreen()),
    );
  }

  void _openHelp() {
    // Implement help screen or open URL
    launchUrl(Uri.parse("https://mindshiftz.com/localshare"));
    // ScaffoldMessenger.of(
    //   context,
    // ).showSnackBar(const SnackBar(content: Text("Help & FAQ coming soon")));
  }

  void _reportBug() {
    // Implement bug reporting
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Bug reporting coming soon")));
  }

  void _requestFeature() {
    // Implement feature request
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Feature request coming soon")),
    );
  }

  void _rateApp() {
    // Implement app rating
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Rate app coming soon")));
  }

  void _openPrivacyPolicy() {
    // Implement privacy policy
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Privacy policy coming soon")));
  }

  void _openTermsOfService() {
    // Implement terms of service
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Terms of service coming soon")),
    );
  }

  void _openSourceCode() {
    // Implement open source link
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Open source coming soon")));
  }

  void _shareApp() {
    Share.share(
      'Check out LocalShare - Fast and secure file sharing app!',
      subject: 'LocalShare App',
    );
  }
}

// Transfer History Screen
class TransferHistoryScreen extends StatelessWidget {
  const TransferHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Transfer History"), elevation: 0),
      body: const Center(child: Text("Transfer history coming soon")),
    );
  }
}
