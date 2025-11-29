import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'answering_screen.dart';
import 'nickname_entry_screen.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // <-- EKLENDİ

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  // --- KONTROLLER ---
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  bool isScanCompleted = false;
  late AnimationController _animationController;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    // Tarama çizgisi animasyonu
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- TARAMA MANTIĞI (GÜNCELLENDİ) ---
  Future<void> handleScannedValue(String scannedValue) async {
    if (isScanCompleted) return;
    setState(() {
      isScanCompleted = true;
    });

    // Web linkinize göre burayı düzenleyebilirsiniz
    const String targetBaseUrl = '/event/';

    // Basit bir kontrol: URL içinde "/event/" geçiyor mu?
    if (scannedValue.contains(targetBaseUrl)) {
      // ID'yi ayıkla
      final eventId = scannedValue.split(targetBaseUrl).last;

      if (eventId.isEmpty) {
        _showError("scan_invalid".tr());
        return;
      }

      // Bekleme dialog'u
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .get();

        if (!mounted) return;
        Navigator.pop(context); // Dialog'u kapat

        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;

          // --- YENİ EKLENEN TARİH KONTROLÜ BAŞLANGIÇ ---
          final Timestamp? startTs = data['startTime'];
          final Timestamp? endTs = data['endTime'];

          if (startTs != null && endTs != null) {
            final DateTime now = DateTime.now();
            final DateTime start = startTs.toDate();
            final DateTime end = endTs.toDate();
            // Dil desteğiyle format
            final DateFormat formatter =
                DateFormat('dd MMM HH:mm', context.locale.toString());

            if (now.isBefore(start)) {
              _showError("answer_event_not_started"
                  .tr(namedArgs: {'date': formatter.format(start)}));
              return; // Fonksiyondan çık, yönlendirme yapma
            }

            if (now.isAfter(end)) {
              _showError("answer_event_ended"
                  .tr(namedArgs: {'date': formatter.format(end)}));
              return; // Fonksiyondan çık, yönlendirme yapma
            }
          }
          // --- TARİH KONTROLÜ BİTİŞ ---

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
        } else {
          _showError("scanner_error_not_found".tr());
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          _showError("scanner_error_fetch".tr());
        }
      }
    } else {
      _showError("scanner_error_invalid".tr());
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    // Hata mesajını göster
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("alert_warning".tr(),
            style: TextStyle(fontSize: 18.sp)), // .sp
        content: Text(message, style: TextStyle(fontSize: 14.sp)), // .sp
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Kullanıcıyı tekrar tarama yapabilmesi için resetle
              if (mounted) {
                setState(() {
                  isScanCompleted = false;
                });
              }
            },
            child:
                Text("alert_ok".tr(), style: TextStyle(fontSize: 14.sp)), // .sp
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ekran boyutuna göre tarama alanını hesapla
    final scanWindowWidth = MediaQuery.of(context).size.width * 0.75;
    final scanWindowHeight = scanWindowWidth;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. KATMAN: KAMERA
          MobileScanner(
            controller: _cameraController,
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

          // 2. KATMAN: KARARTMA OVERLAY VE KESİK ALAN
          CustomPaint(
            painter: ScannerOverlayPainter(
              scanWindow: Rect.fromCenter(
                center: Offset(
                  MediaQuery.of(context).size.width / 2,
                  MediaQuery.of(context).size.height / 2,
                ),
                width: scanWindowWidth,
                height: scanWindowHeight,
              ),
              borderRadius: 20.r, // .r EKLENDİ
            ),
            child: Container(),
          ),

          // 3. KATMAN: ANİMASYONLU TARAMA ÇİZGİSİ
          Center(
            child: SizedBox(
              width: scanWindowWidth,
              height: scanWindowHeight,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      Positioned(
                        top:
                            _animationController.value * (scanWindowHeight - 4),
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2.h, // .h EKLENDİ
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.5),
                                blurRadius: 10.r, // .r EKLENDİ
                                spreadRadius: 2.r, // .r EKLENDİ
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 4. KATMAN: ÜST BİLGİ VE GERİ BUTONU
          Positioned(
            top: 50.h, // .h EKLENDİ
            left: 20.w, // .w EKLENDİ
            right: 20.w, // .w EKLENDİ
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(10.r), // .r EKLENDİ
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20.sp), // .sp EKLENDİ
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 8.h), // .w .h EKLENDİ
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20.r), // .r EKLENDİ
                  ),
                  child: Text(
                    "scanner_title".tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp, // .sp EKLENDİ
                    ),
                  ),
                ),
                SizedBox(width: 40.w), // .w EKLENDİ (Dengelemek için boşluk)
              ],
            ),
          ),

          // 5. KATMAN: ALT YAZI VE KONTROLLER
          Positioned(
            bottom: 50.h, // .h EKLENDİ
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "scan_align".tr(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14.sp, // .sp EKLENDİ
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 30.h), // .h EKLENDİ
                // Buton Paneli
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 40.w), // .w EKLENDİ
                  padding: EdgeInsets.symmetric(
                      vertical: 10.h, horizontal: 20.w), // .h .w EKLENDİ
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30.r), // .r EKLENDİ
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // El Feneri
                      IconButton(
                        onPressed: () {
                          _cameraController.toggleTorch();
                          setState(() {
                            _isFlashOn = !_isFlashOn;
                          });
                        },
                        icon: Icon(
                          _isFlashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: _isFlashOn ? Colors.yellow : Colors.white,
                          size: 28.sp, // .sp EKLENDİ
                        ),
                      ),
                      SizedBox(width: 30.w), // .w EKLENDİ
                      // Kamera Değiştir
                      IconButton(
                        onPressed: () => _cameraController.switchCamera(),
                        icon: Icon(
                          Icons.flip_camera_ios_rounded,
                          color: Colors.white,
                          size: 28.sp, // .sp EKLENDİ
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- ÖZEL ÇİZİM SINIFI ---
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;

  ScannerOverlayPainter({
    required this.scanWindow,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          scanWindow,
          Radius.circular(borderRadius),
        ),
      );

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.srcOver;

    final path =
        Path.combine(PathOperation.difference, backgroundPath, cutoutPath);

    canvas.drawPath(path, backgroundPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final cornerLength = 20.0;
    // Köşe çizimleri (Aynen korundu)
    canvas.drawPath(
        Path()
          ..moveTo(scanWindow.left, scanWindow.top + cornerLength)
          ..lineTo(scanWindow.left, scanWindow.top)
          ..lineTo(scanWindow.left + cornerLength, scanWindow.top),
        borderPaint);

    canvas.drawPath(
        Path()
          ..moveTo(scanWindow.right - cornerLength, scanWindow.top)
          ..lineTo(scanWindow.right, scanWindow.top)
          ..lineTo(scanWindow.right, scanWindow.top + cornerLength),
        borderPaint);

    canvas.drawPath(
        Path()
          ..moveTo(scanWindow.left, scanWindow.bottom - cornerLength)
          ..lineTo(scanWindow.left, scanWindow.bottom)
          ..lineTo(scanWindow.left + cornerLength, scanWindow.bottom),
        borderPaint);

    canvas.drawPath(
        Path()
          ..moveTo(scanWindow.right - cornerLength, scanWindow.bottom)
          ..lineTo(scanWindow.right, scanWindow.bottom)
          ..lineTo(scanWindow.right, scanWindow.bottom - cornerLength),
        borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
