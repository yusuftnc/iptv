import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/entities.dart';
import '../models/cast_pick_result.dart';
import '../services/cast_service.dart';

/// Aynı Wi-Fi üzerindeki Cast hedeflerini listeler.
Future<CastPickResult?> showCastDevicePicker(BuildContext context) async {
  final cast = CastService.instance;
  final isIOS = !kIsWeb && Platform.isIOS;

  if (!cast.isSupported && !isIOS) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yansıtma yalnızca Android ve iOS’ta desteklenir'),
      ),
    );
    return null;
  }

  if (cast.isSupported) {
    unawaited(cast.startDiscovery());
  }

  if (!context.mounted) return null;

  final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

  final result = await showModalBottomSheet<CastPickResult>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.grey[900],
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.cast, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Yansıtılacak cihaz',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Yeniden ara',
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: () => cast.startDiscovery(refresh: true),
                    ),
                    if (cast.isConnected)
                      TextButton(
                        onPressed: () async {
                          await cast.disconnect();
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Bağlantıyı kes'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isIOS
                      ? 'Aynı ağdaki Chromecast ve Cast destekli televizyonlar. '
                          'Apple TV için Kontrol Merkezi’nden Ekran Yansıt’ı kullanın.'
                      : 'Aynı ağdaki Chromecast ve Cast destekli televizyonlar.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildDeviceList(cast),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (result == null && !cast.isConnected) {
    unawaited(cast.stopDiscovery());
  }
  return result;
}

Widget _buildDeviceList(CastService cast) {
  if (!cast.isSupported) {
    return const Center(
      child: Text(
        'Bu telefonda Google Cast desteklenmiyor.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  return StreamBuilder<List<GoogleCastDevice>>(
    stream: cast.devicesStream,
    initialData: cast.devices,
    builder: (context, snapshot) {
      final devices = snapshot.data ?? <GoogleCastDevice>[];
      if (devices.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Cihazlar aranıyor…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Telefon ve televizyonun aynı Wi-Fi ağında\n'
                'olduğundan emin olun.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        itemCount: devices.length,
        separatorBuilder: (context, index) {
          return const Divider(color: Colors.white12, height: 1);
        },
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            leading: Icon(_deviceIcon(device), color: Colors.white),
            title: Text(
              device.friendlyName,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              _deviceKind(device),
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.white38,
            ),
            onTap: () {
              Navigator.pop(context, CastPickGoogleCast(device));
            },
          );
        },
      );
    },
  );
}

/// Ham model kodlarını (M7, X96, H96…) kullanıcıya gösterme.
String _deviceKind(GoogleCastDevice device) {
  final model = (device.modelName ?? '').trim();
  final haystack = '${device.friendlyName} $model'.toLowerCase();

  if (haystack.contains('nest hub') || haystack.contains('nest display')) {
    return 'Google Nest';
  }
  if (haystack.contains('nest mini') ||
      haystack.contains('google home') ||
      haystack.contains('speaker')) {
    return 'Hoparlör';
  }
  if (haystack.contains('chromecast')) {
    return haystack.contains('google tv') ? 'Google TV' : 'Chromecast';
  }
  if (haystack.contains('google tv') || haystack.contains('android tv')) {
    return 'Google TV';
  }
  if (haystack.contains('apple tv') || haystack.contains('airplay')) {
    return 'Apple TV';
  }
  if (haystack.contains('smart tv') ||
      haystack.contains('television') ||
      haystack.contains('tv')) {
    return 'Televizyon';
  }

  if (model.isEmpty || _looksLikeHardwareCode(model)) {
    return 'Televizyon';
  }
  return model;
}

bool _looksLikeHardwareCode(String model) {
  final compact = model.replaceAll(RegExp(r'[\s\-_]'), '');
  if (compact.length <= 4) return true;
  return RegExp(r'^[A-Za-z]{0,3}\d{1,4}[A-Za-z0-9]*$').hasMatch(compact);
}

IconData _deviceIcon(GoogleCastDevice device) {
  final kind = _deviceKind(device);
  if (kind == 'Hoparlör') return Icons.speaker;
  if (kind == 'Google Nest') return Icons.smart_display;
  return Icons.tv;
}
