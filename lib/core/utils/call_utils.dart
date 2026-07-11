import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class CallUtils {
  static Future<void> makeCall(BuildContext context, String number) async {
    if (number.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid phone number')),
        );
      }
      return;
    }

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: number.trim(),
    );

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot open dialer. Device might not support calling.')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error making call: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making call: $e')),
        );
      }
    }
  }
}
