import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'answering_screen.dart';
import 'nickname_entry_screen.dart';
import 'package:easy_localization/easy_localization.dart'; // YENİ: Paketi import et

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool isScanCompleted = false;

  Future<void> handleScannedValue(String scannedValue) async {
    if (isScanCompleted) return;
    setState(() {
      isScanCompleted = true;
    });

    const String targetUrl = 'https://querycode-app.web.app/event/';

    if (scannedValue.startsWith(targetUrl)) {
      final eventId = scannedValue.substring(targetUrl.length);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .get();

        Navigator.pop(context); // Bekleme göstergesini kapat

        if (docSnapshot.exists && mounted) {
          final data = docSnapshot.data()!;
          final bool isNicknameRequired = data['isNicknameRequired'] ?? false;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) {
                if (isNicknameRequired) {
                  return NicknameEntryScreen(eventId: eventId);
                } else {
                  return AnsweringScreen(eventId: eventId);
                }
              },
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("scanner_error_not_found".tr())),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("scanner_error_fetch".tr())),
          );
          Navigator.pop(context);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("scanner_error_invalid".tr())),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("scanner_title".tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? scannedValue = barcodes.first.rawValue;
            if (scannedValue != null) {
              handleScannedValue(scannedValue);
            }
          }
        },
      ),
    );
  }
}
