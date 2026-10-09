import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/entities.dart';
import '../models/cast_pick_result.dart';
import '../services/cast_service.dart';

/// Aynı Wi-Fi üzerindeki Cast / AirPlay hedeflerini listeler.
Future<CastPickResult?> showCastDevicePicker(BuildContext context) async {
  final cast = CastService.instance;
  final isIOS = !kIsWeb && Platform.isIOS;

  if (!cast.isSupported && !isIOS) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yansıtma yalnızca Android ve iOS\'ta desteklenir'),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                        child: const Text('Bağlantıyı Kes'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cast’li TV ve M7. Seçilince yayının görüntüsü gider. '
                  'Kontrol Merkezi’ndeki Ekran Yansıt ayrıdır; '
                  'uygulama o listeyi açamaz, o düğme yalnızca ses taşır.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
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
        'Bu cihazda Google Cast yok.',
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
                'Cast cihazları aranıyor...\n'
                '• Telefon ve TV aynı Wi-Fi\'de olsun\n'
                '• iPhone: Ayarlar > Gizlilik > Yerel Ağ > uygulama açık\n'
                '• TV\'de Chromecast built-in / Cast açık olsun',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        itemCount: devices.length,
        separatorBuilder: (context, index) {
          return const Divider(color: Colors.white12);
        },
        itemBuilder: (context, index) {
          final device = devices[index];
          final model = device.modelName ?? 'Cast cihazı';
          return ListTile(
            leading: const Icon(Icons.tv, color: Colors.white),
            title: Text(
              device.friendlyName,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              model,
              style: const TextStyle(color: Colors.white54),
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
