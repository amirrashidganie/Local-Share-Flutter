import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class SettingsManager {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  static const String _keyTransferPort = 'transfer_port';
  static const String _keySaveLocation = 'save_location';
  static const String _keyAutoAcceptFiles = 'auto_accept_files';
  static const String _keySaveToGallery = 'save_to_gallery';
  static const String _keyVibrateOnTransfer = 'vibrate_on_transfer';
  static const String _keySoundOnTransfer = 'sound_on_transfer';
  static const String _keyShowTransferNotifications =
      'show_transfer_notifications';
  static const String _keyAutoScanNetwork = 'auto_scan_network';
  static const String _keyCustomSavePath = 'custom_save_path';
  static const String _keyNetworkTimeout = 'network_timeout';
  static const String _keyMaxFileSize = 'max_file_size';
  static const String _keyEnableCompression = 'enable_compression';

  // Default values
  static const int _defaultTransferPort = 5000;
  static const String _defaultSaveLocation = "LocalShare";
  static const bool _defaultAutoAcceptFiles = false;
  static const bool _defaultSaveToGallery = true;
  static const bool _defaultVibrateOnTransfer = true;
  static const bool _defaultSoundOnTransfer = true;
  static const bool _defaultShowTransferNotifications = true;
  static const bool _defaultAutoScanNetwork = true;
  static const int _defaultNetworkTimeout = 30;
  static const int _defaultMaxFileSize = 1024; // MB
  static const bool _defaultEnableCompression = false;

  // Network settings
  int _transferPort = _defaultTransferPort;
  String _saveLocation = _defaultSaveLocation;
  String? _customSavePath;
  int _networkTimeout = _defaultNetworkTimeout;
  int _maxFileSize = _defaultMaxFileSize;
  bool _enableCompression = _defaultEnableCompression;

  // Transfer settings
  bool _autoAcceptFiles = _defaultAutoAcceptFiles;
  bool _saveToGallery = _defaultSaveToGallery;
  bool _vibrateOnTransfer = _defaultVibrateOnTransfer;
  bool _soundOnTransfer = _defaultSoundOnTransfer;
  bool _showTransferNotifications = _defaultShowTransferNotifications;
  bool _autoScanNetwork = _defaultAutoScanNetwork;

  // Getters
  int get transferPort => _transferPort;
  String get saveLocation => _saveLocation;
  String? get customSavePath => _customSavePath;
  int get networkTimeout => _networkTimeout;
  int get maxFileSize => _maxFileSize;
  bool get enableCompression => _enableCompression;
  bool get autoAcceptFiles => _autoAcceptFiles;
  bool get saveToGallery => _saveToGallery;
  bool get vibrateOnTransfer => _vibrateOnTransfer;
  bool get soundOnTransfer => _soundOnTransfer;
  bool get showTransferNotifications => _showTransferNotifications;
  bool get autoScanNetwork => _autoScanNetwork;

  // Initialize settings
  Future<void> initialize() async {
    await _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _transferPort = prefs.getInt(_keyTransferPort) ?? _defaultTransferPort;
      _saveLocation = prefs.getString(_keySaveLocation) ?? _defaultSaveLocation;
      _customSavePath = prefs.getString(_keyCustomSavePath);
      _networkTimeout =
          prefs.getInt(_keyNetworkTimeout) ?? _defaultNetworkTimeout;
      _maxFileSize = prefs.getInt(_keyMaxFileSize) ?? _defaultMaxFileSize;
      _enableCompression =
          prefs.getBool(_keyEnableCompression) ?? _defaultEnableCompression;

      _autoAcceptFiles =
          prefs.getBool(_keyAutoAcceptFiles) ?? _defaultAutoAcceptFiles;
      _saveToGallery =
          prefs.getBool(_keySaveToGallery) ?? _defaultSaveToGallery;
      _vibrateOnTransfer =
          prefs.getBool(_keyVibrateOnTransfer) ?? _defaultVibrateOnTransfer;
      _soundOnTransfer =
          prefs.getBool(_keySoundOnTransfer) ?? _defaultSoundOnTransfer;
      _showTransferNotifications =
          prefs.getBool(_keyShowTransferNotifications) ??
          _defaultShowTransferNotifications;
      _autoScanNetwork =
          prefs.getBool(_keyAutoScanNetwork) ?? _defaultAutoScanNetwork;
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt(_keyTransferPort, _transferPort);
      await prefs.setString(_keySaveLocation, _saveLocation);
      if (_customSavePath != null) {
        await prefs.setString(_keyCustomSavePath, _customSavePath!);
      }
      await prefs.setInt(_keyNetworkTimeout, _networkTimeout);
      await prefs.setInt(_keyMaxFileSize, _maxFileSize);
      await prefs.setBool(_keyEnableCompression, _enableCompression);

      await prefs.setBool(_keyAutoAcceptFiles, _autoAcceptFiles);
      await prefs.setBool(_keySaveToGallery, _saveToGallery);
      await prefs.setBool(_keyVibrateOnTransfer, _vibrateOnTransfer);
      await prefs.setBool(_keySoundOnTransfer, _soundOnTransfer);
      await prefs.setBool(
        _keyShowTransferNotifications,
        _showTransferNotifications,
      );
      await prefs.setBool(_keyAutoScanNetwork, _autoScanNetwork);
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  // Network settings setters
  Future<void> setTransferPort(int port) async {
    if (port > 0 && port < 65536) {
      _transferPort = port;
      await _saveSettings();
    }
  }

  Future<void> setSaveLocation(String location) async {
    _saveLocation = location;
    await _saveSettings();
  }

  Future<void> setCustomSavePath(String? path) async {
    _customSavePath = path;
    await _saveSettings();
  }

  Future<void> setNetworkTimeout(int timeout) async {
    if (timeout > 0) {
      _networkTimeout = timeout;
      await _saveSettings();
    }
  }

  Future<void> setMaxFileSize(int sizeMB) async {
    if (sizeMB > 0) {
      _maxFileSize = sizeMB;
      await _saveSettings();
    }
  }

  Future<void> setEnableCompression(bool enable) async {
    _enableCompression = enable;
    await _saveSettings();
  }

  // Transfer settings setters
  Future<void> setAutoAcceptFiles(bool value) async {
    _autoAcceptFiles = value;
    await _saveSettings();
  }

  Future<void> setSaveToGallery(bool value) async {
    _saveToGallery = value;
    await _saveSettings();
  }

  Future<void> setVibrateOnTransfer(bool value) async {
    _vibrateOnTransfer = value;
    await _saveSettings();
  }

  Future<void> setSoundOnTransfer(bool value) async {
    _soundOnTransfer = value;
    await _saveSettings();
  }

  Future<void> setShowTransferNotifications(bool value) async {
    _showTransferNotifications = value;
    await _saveSettings();
  }

  Future<void> setAutoScanNetwork(bool value) async {
    _autoScanNetwork = value;
    await _saveSettings();
  }

  // Get available save locations
  List<Map<String, String>> getAvailableSaveLocations() {
    List<Map<String, String>> locations = [
      {
        'name': 'LocalShare',
        'path': '/storage/emulated/0/LocalShare',
        'description': 'Default LocalShare folder (app documents)',
      },
      {
        'name': 'Download',
        'path': '/storage/emulated/0/Download',
        'description': 'System downloads folder',
      },
      {
        'name': 'DCIM',
        'path': '/storage/emulated/0/DCIM',
        'description': 'Camera and media folder',
      },
      {
        'name': 'Documents',
        'path': '/storage/emulated/0/Documents',
        'description': 'Documents folder',
      },
    ];

    if (_customSavePath != null && _customSavePath!.isNotEmpty) {
      locations.add({
        'name': 'Custom',
        'path': _customSavePath!,
        'description': 'Custom location',
      });
    }

    return locations;
  }

  // Get current save directory
  Future<Directory> getCurrentSaveDirectory() async {
    try {
      switch (_saveLocation) {
        case 'Download':
          return Directory('/storage/emulated/0/Download');
        case 'DCIM':
          return Directory('/storage/emulated/0/DCIM');
        case 'Documents':
          return Directory('/storage/emulated/0/Documents');
        case 'Custom':
          if (_customSavePath != null && _customSavePath!.isNotEmpty) {
            return Directory(_customSavePath!);
          }
          // Fallback to app documents directory
          return await getApplicationDocumentsDirectory();
        case 'LocalShare':
        default:
          // Use app documents directory instead of external storage
          final appDir = await getApplicationDocumentsDirectory();
          final localShareDir = Directory('${appDir.path}/LocalShare');
          if (!await localShareDir.exists()) {
            await localShareDir.create(recursive: true);
          }
          return localShareDir;
      }
    } catch (e) {
      print('Error getting save directory: $e');
      // Fallback to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final localShareDir = Directory('${appDir.path}/LocalShare');
      if (!await localShareDir.exists()) {
        await localShareDir.create(recursive: true);
      }
      return localShareDir;
    }
  }

  // Pick custom save location
  Future<String?> pickCustomSaveLocation() async {
    try {
      String? path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Save Location',
      );
      if (path != null) {
        await setCustomSavePath(path);
        await setSaveLocation('Custom');
        return path;
      }
    } catch (e) {
      print('Error picking custom save location: $e');
    }
    return null;
  }

  // Reset settings to defaults
  Future<void> resetToDefaults() async {
    _transferPort = _defaultTransferPort;
    _saveLocation = _defaultSaveLocation;
    _customSavePath = null;
    _networkTimeout = _defaultNetworkTimeout;
    _maxFileSize = _defaultMaxFileSize;
    _enableCompression = _defaultEnableCompression;

    _autoAcceptFiles = _defaultAutoAcceptFiles;
    _saveToGallery = _defaultSaveToGallery;
    _vibrateOnTransfer = _defaultVibrateOnTransfer;
    _soundOnTransfer = _defaultSoundOnTransfer;
    _showTransferNotifications = _defaultShowTransferNotifications;
    _autoScanNetwork = _defaultAutoScanNetwork;

    await _saveSettings();
  }

  // Export settings
  Map<String, dynamic> exportSettings() {
    return {
      'transferPort': _transferPort,
      'saveLocation': _saveLocation,
      'customSavePath': _customSavePath,
      'networkTimeout': _networkTimeout,
      'maxFileSize': _maxFileSize,
      'enableCompression': _enableCompression,
      'autoAcceptFiles': _autoAcceptFiles,
      'saveToGallery': _saveToGallery,
      'vibrateOnTransfer': _vibrateOnTransfer,
      'soundOnTransfer': _soundOnTransfer,
      'showTransferNotifications': _showTransferNotifications,
      'autoScanNetwork': _autoScanNetwork,
    };
  }

  // Import settings
  Future<void> importSettings(Map<String, dynamic> settings) async {
    _transferPort = settings['transferPort'] ?? _defaultTransferPort;
    _saveLocation = settings['saveLocation'] ?? _defaultSaveLocation;
    _customSavePath = settings['customSavePath'];
    _networkTimeout = settings['networkTimeout'] ?? _defaultNetworkTimeout;
    _maxFileSize = settings['maxFileSize'] ?? _defaultMaxFileSize;
    _enableCompression =
        settings['enableCompression'] ?? _defaultEnableCompression;

    _autoAcceptFiles = settings['autoAcceptFiles'] ?? _defaultAutoAcceptFiles;
    _saveToGallery = settings['saveToGallery'] ?? _defaultSaveToGallery;
    _vibrateOnTransfer =
        settings['vibrateOnTransfer'] ?? _defaultVibrateOnTransfer;
    _soundOnTransfer = settings['soundOnTransfer'] ?? _defaultSoundOnTransfer;
    _showTransferNotifications =
        settings['showTransferNotifications'] ??
        _defaultShowTransferNotifications;
    _autoScanNetwork = settings['autoScanNetwork'] ?? _defaultAutoScanNetwork;

    await _saveSettings();
  }
}
