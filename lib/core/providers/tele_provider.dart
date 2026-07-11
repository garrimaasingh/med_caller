import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class TeleProvider extends ChangeNotifier {
  static const EventChannel _callChannel =
      EventChannel('com.medcaller.call_detection');
  StreamSubscription? _callSubscription;
  String? _activeCallNumber;

  String? get activeCallNumber => _activeCallNumber;

  Future<void> initialize() async {
    // Request overlay permission upfront if not already granted
    final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasPermission) {
      await FlutterOverlayWindow.requestPermission();
    }

    _callSubscription = _callChannel.receiveBroadcastStream().listen(
      (event) async {
        if (event is! Map) return;

        final eventType = event['event'] as String? ?? '';
        final rawNumber = event['number'] as String? ?? '';
        // Apply Flutter-side normalization as a second safety net
        final number = _normalizeNumber(rawNumber);

        debugPrint(
          '[TeleProvider] event=$eventType | raw=$rawNumber | normalized=$number',
        );

        if (eventType == 'RINGING') {
          _activeCallNumber = number.isNotEmpty ? number : null;
          notifyListeners();

          // Show overlay for EVERY incoming call — even if number is unknown
          // The overlay UI will show a fallback if number is empty
          final hasOverlayPermission =
              await FlutterOverlayWindow.isPermissionGranted();
          if (!hasOverlayPermission) {
            debugPrint('[TeleProvider] No overlay permission, skipping');
            return;
          }

          await FlutterOverlayWindow.showOverlay(
            enableDrag: false,
            flag: OverlayFlag.defaultFlag,
            alignment: OverlayAlignment.center,
            visibility: NotificationVisibility.visibilityPublic,
            positionGravity: PositionGravity.auto,
            height: 520,
            width: WindowSize.matchParent,
          );

          // Pass the number (possibly empty string) to overlay isolate
          // The overlay decides whether to search Firestore or show fallback
          await FlutterOverlayWindow.shareData(number);
        } else if (eventType == 'CALL_ENDED') {
          debugPrint('[TeleProvider] Call ended, closing overlay');
          _activeCallNumber = null;
          notifyListeners();
          try {
            final isActive = await FlutterOverlayWindow.isActive();
            if (isActive) {
              await FlutterOverlayWindow.closeOverlay();
            }
          } catch (e) {
            debugPrint('[TeleProvider] closeOverlay error: $e');
          }
        }
      },
      onError: (error) {
        debugPrint('[TeleProvider] EventChannel error: $error');
      },
    );
  }

  /// Normalize a phone number to match Firestore document IDs.
  /// Strips +91 country code, leading 0, spaces, dashes.
  static String _normalizeNumber(String raw) {
    if (raw.isEmpty) return '';
    // Remove all non-digit characters
    String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    // Strip Indian country code (91 prefix → 10-digit number)
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    // Strip leading 0 (STD format)
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }
}
