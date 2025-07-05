import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class DeviceInfo {
  final String name;
  final String ip;
  final bool isReceiving;

  DeviceInfo({required this.name, required this.ip, required this.isReceiving});

  Map<String, dynamic> toJson() => {
    'name': name,
    'ip': ip,
    'isReceiving': isReceiving,
  };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    name: json['name'],
    ip: json['ip'],
    isReceiving: json['isReceiving'],
  );
}

class DeviceDiscovery extends ChangeNotifier {
  static final DeviceDiscovery _instance = DeviceDiscovery._internal();
  factory DeviceDiscovery() => _instance;
  DeviceDiscovery._internal();

  final List<DeviceInfo> _availableDevices = [];
  bool _isScanning = false;
  RawDatagramSocket? _udpSocket;

  List<DeviceInfo> get availableDevices => _availableDevices;
  bool get isScanning => _isScanning;

  Future<void> startDiscovery(String deviceName, String deviceIP) async {
    _isScanning = true;
    _availableDevices.clear();
    notifyListeners();

    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5001);
      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = _udpSocket!.receive();
          if (datagram != null) {
            try {
              String message = utf8.decode(datagram.data);
              Map<String, dynamic> deviceData = jsonDecode(message);
              DeviceInfo device = DeviceInfo.fromJson(deviceData);

              if (!_availableDevices.any((d) => d.ip == device.ip) &&
                  device.ip != deviceIP) {
                _availableDevices.add(device);
                notifyListeners();
              }
            } catch (e) {
              // Handle parsing errors
            }
          }
        }
      });

      // Broadcast discovery message
      await _broadcastDiscovery(deviceName, deviceIP);

      // Stop scanning after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        _isScanning = false;
        notifyListeners();
      });
    } catch (e) {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> _broadcastDiscovery(String deviceName, String deviceIP) async {
    try {
      DeviceInfo thisDevice = DeviceInfo(
        name: deviceName,
        ip: deviceIP,
        isReceiving: false,
      );
      String message = jsonEncode(thisDevice.toJson());
      List<int> data = utf8.encode(message);

      // Broadcast to subnet
      String subnet = deviceIP.substring(0, deviceIP.lastIndexOf('.'));
      InternetAddress broadcastAddr = InternetAddress('$subnet.255');

      _udpSocket?.send(data, broadcastAddr, 5001);
    } catch (e) {
      // Handle broadcast error
    }
  }

  void announceReceiver(String deviceName, String deviceIP) async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5001);
      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = _udpSocket!.receive();
          if (datagram != null) {
            try {
              // Respond to discovery requests
              DeviceInfo receiverDevice = DeviceInfo(
                name: deviceName,
                ip: deviceIP,
                isReceiving: true,
              );
              String response = jsonEncode(receiverDevice.toJson());
              List<int> data = utf8.encode(response);
              _udpSocket?.send(data, datagram.address, 5001);
            } catch (e) {
              // Handle error
            }
          }
        }
      });
    } catch (e) {
      // Handle error
    }
  }

  void stopDiscovery() {
    _udpSocket?.close();
    _availableDevices.clear();
    _isScanning = false;
    notifyListeners();
  }
}
