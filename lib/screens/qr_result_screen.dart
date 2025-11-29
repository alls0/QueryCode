import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // <-- EKLENDİ

class QRResultScreen extends StatefulWidget {
  final String eventId;

  const QRResultScreen({super.key, required this.eventId});

  @override
  State<QRResultScreen> createState() => _QRResultScreenState();
}

class _QRResultScreenState extends State<QRResultScreen> {
  final GlobalKey _qrKey = GlobalKey();

  // --- TASARIM AYARLARI ---
  final List<String> _viewModes = ['LIST', 'STATS', 'CHART'];
  String _currentViewMode = 'LIST';

  // --- RENK PALETİ ---
  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _primaryColor = const Color(0xFF2D3748);
  final Color _secondaryColor = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
  }

  // --- ÇIKIŞ KONTROL MANTIĞI (YENİLENMİŞ TASARIM) ---
  Future<bool> _onWillPop() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 24.w), // .w EKLENDİ
        child: Container(
          padding: EdgeInsets.all(24.r), // .r EKLENDİ
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r), // .r EKLENDİ
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16.r, // .r EKLENDİ
                offset: Offset(0, 4.h), // .h EKLENDİ
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. İKON (Kırmızı yerine TURUNCU/AMBER)
              Container(
                padding: EdgeInsets.all(16.r), // .r EKLENDİ
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7ED), // Çok açık turuncu (Amber-50)
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.priority_high_rounded, // Sade ünlem ikonu
                  color: const Color(0xFFF97316), // Canlı Turuncu (Orange-500)
                  size: 32.sp, // .sp EKLENDİ
                ),
              ),
              SizedBox(height: 20.h), // .h EKLENDİ

              // 2. BAŞLIK
              Text(
                "alert_warning".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20.sp, // .sp EKLENDİ
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              SizedBox(height: 12.h), // .h EKLENDİ

              // 3. AÇIKLAMA
              Text(
                "result_guest_warning".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp, // .sp EKLENDİ
                  color: _secondaryColor,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24.h), // .h EKLENDİ

              // 4. BUTONLAR
              Row(
                children: [
                  // İptal (Gri ve Sade)
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(vertical: 14.h), // .h EKLENDİ
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12.r), // .r EKLENDİ
                        ),
                      ),
                      child: Text(
                        "cancel".tr(),
                        style: TextStyle(
                          color: _secondaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp, // .sp EKLENDİ
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w), // .w EKLENDİ

                  // Çıkış (Kırmızı yerine UYGULAMA RENGİ)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _primaryColor, // Diğer butonlarla aynı renk
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(vertical: 14.h), // .h EKLENDİ
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12.r), // .r EKLENDİ
                        ),
                      ),
                      child: Text(
                        "result_exit".tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp, // .sp EKLENDİ
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return shouldLeave ?? false;
  }

  // --- İSTATİSTİK HESAPLAMA ---
  Map<String, dynamic> _calculateStatsLogic(
      Map<String, dynamic> results, List<dynamic> questions) {
    if (results.isEmpty) {
      return {'stats': <String, Map<String, dynamic>>{}, 'totalRespondents': 0};
    }

    int totalRespondents = results.keys.length;
    Map<String, Map<String, dynamic>> stats = {};

    for (var question in questions) {
      final questionText = question['questionText'] as String? ?? "Unknown";
      final allowOpenEnded = question['allowOpenEnded'] as bool? ?? false;

      Map<String, int> optionCounts = {};
      final optionsList = (question['options'] as List<dynamic>? ?? []);
      for (var option in optionsList) {
        optionCounts[option.toString()] = 0;
      }

      // "Diğer" seçeneği için dil desteği
      final otherLabel = "feedback_other".tr();
      if (allowOpenEnded) optionCounts[otherLabel] = 0;

      for (var respondentAnswers in results.values) {
        if (respondentAnswers is List) {
          for (var answer in respondentAnswers) {
            if (answer is Map && answer['question'] == questionText) {
              final selectedOption = answer['answer'];
              if (selectedOption != null) {
                if (optionCounts.containsKey(selectedOption)) {
                  optionCounts[selectedOption] =
                      optionCounts[selectedOption]! + 1;
                } else if (allowOpenEnded) {
                  optionCounts[otherLabel] =
                      (optionCounts[otherLabel] ?? 0) + 1;
                }
              }
              break;
            }
          }
        }
      }

      int totalVotesForQuestion =
          optionCounts.values.fold(0, (sum, count) => sum + count);
      Map<String, dynamic> finalStats = {};
      optionCounts.forEach((option, count) {
        double percent = totalVotesForQuestion == 0
            ? 0.0
            : (count / totalVotesForQuestion) * 100;
        finalStats[option] = {'count': count, 'percent': percent};
      });
      stats[questionText] = {
        'totalVotes': totalVotesForQuestion,
        'options': finalStats
      };
    }
    return {'stats': stats, 'totalRespondents': totalRespondents};
  }

  // --- QR PAYLAŞIM ---
  Future<void> _shareQrCode(String eventTitle, String link) async {
    try {
      RenderRepaintBoundary? boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List? pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/qr_code_${widget.eventId}.png';
        final file = await File(imagePath).writeAsBytes(pngBytes);
        await Share.shareXFiles([XFile(file.path)],
            text: "$eventTitle\n$link", subject: eventTitle);
      }
    } catch (e) {
      debugPrint("Error sharing QR: $e");
    }
  }

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("link_copied".tr(),
                style: const TextStyle(color: Colors.white)),
            backgroundColor: _primaryColor,
            duration: const Duration(seconds: 2)),
      );
    }
  }

  // --- YENİ: MODERN ZAMAN BİLGİSİ KARTI ---
  Widget _buildTimeInfoCard(Timestamp? startTs, Timestamp? endTs) {
    if (startTs == null || endTs == null) return const SizedBox.shrink();

    final start = startTs.toDate();
    final end = endTs.toDate();
    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMM HH:mm', context.locale.toString());

    // Durum Tasarım Değişkenleri
    String statusText;
    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;

    if (now.isBefore(start)) {
      // BAŞLAMADI -> Turuncu (Bekleme hissi için ideal, kalabilir)
      final diff = start.difference(now);
      statusText = "result_time_start_left".tr(
          namedArgs: {'h': '${diff.inHours}', 'm': '${diff.inMinutes % 60}'});
      statusColor = const Color(0xFFD97706); // Amber-700
      statusBgColor = const Color(0xFFFFFBEB); // Amber-50
      statusIcon = Icons.hourglass_empty_rounded;
    } else if (now.isAfter(end)) {
      // BİTTİ -> Gri (Pasif/Geçmiş hissi için en doğrusu)
      statusText = "result_time_ended".tr();
      statusColor = const Color(0xFF718096); // Cool Gray
      statusBgColor = const Color(0xFFF7FAFC);
      statusIcon = Icons.flag_rounded;
    } else {
      // AKTİF -> ARTIK MAVİ (Uygulamanın Ana Rengi)
      // Yeşil yerine uygulamanızın imza mavisini kullanıyoruz
      final diff = end.difference(now);
      statusText = "result_time_end_left".tr(
          namedArgs: {'h': '${diff.inHours}', 'm': '${diff.inMinutes % 60}'});

      // AuthScreen'deki _primaryBlue ile aynı ton (0xFF3182CE)
      statusColor = const Color(0xFF3182CE);
      // Çok uçuk mavi arka plan
      statusBgColor = const Color(0xFFEBF8FF);
      statusIcon = Icons.timer_rounded;
    }

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: 16.w, vertical: 8.h), // .w .h EKLENDİ
      padding: EdgeInsets.all(20.r), // .r EKLENDİ
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r), // .r EKLENDİ
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10.r, // .r EKLENDİ
              offset: Offset(0, 4.h)) // .h EKLENDİ
        ],
      ),
      child: Column(
        children: [
          // 1. ÜST KISIM: DURUM ROZETİ (Artık Mavi)
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: 12.w, vertical: 6.h), // .w .h EKLENDİ
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(30.r), // .r EKLENDİ
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon,
                    color: statusColor, size: 16.sp), // .sp EKLENDİ
                SizedBox(width: 8.w), // .w EKLENDİ
                Text(
                  statusText,
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.sp), // .sp EKLENDİ
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h), // .h EKLENDİ

          // 2. ALT KISIM: ZAMAN ÇİZELGESİ (Aynı kalıyor)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Başlangıç
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.play_circle_outline_rounded,
                          size: 14.sp, color: _secondaryColor), // .sp EKLENDİ
                      SizedBox(width: 4.w), // .w EKLENDİ
                      Text("create_start".tr().toUpperCase(),
                          style: TextStyle(
                              color: _secondaryColor,
                              fontSize: 10.sp, // .sp EKLENDİ
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ],
                  ),
                  SizedBox(height: 4.h), // .h EKLENDİ
                  Text(dateFormat.format(start),
                      style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15.sp)), // .sp EKLENDİ
                ],
              ),

              // Ortadaki Ok
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w), // .w EKLENDİ
                  child: Row(
                    children: [
                      Expanded(
                          child: Divider(color: _borderColor, thickness: 1)),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4.w), // .w EKLENDİ
                        child: Icon(Icons.arrow_forward_rounded,
                            color: _secondaryColor.withOpacity(0.4),
                            size: 16.sp), // .sp EKLENDİ
                      ),
                      Expanded(
                          child: Divider(color: _borderColor, thickness: 1)),
                    ],
                  ),
                ),
              ),

              // Bitiş
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text("create_end".tr().toUpperCase(),
                          style: TextStyle(
                              color: _secondaryColor,
                              fontSize: 10.sp, // .sp EKLENDİ
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                      SizedBox(width: 4.w), // .w EKLENDİ
                      Icon(Icons.stop_circle_outlined,
                          size: 14.sp, color: _secondaryColor), // .sp EKLENDİ
                    ],
                  ),
                  SizedBox(height: 4.h), // .h EKLENDİ
                  Text(dateFormat.format(end),
                      style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15.sp)), // .sp EKLENDİ
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: 20.w, vertical: 20.h), // .w .h EKLENDİ
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () async {
              if (await _onWillPop()) {
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Container(
              padding: EdgeInsets.all(12.r), // .r EKLENDİ
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r), // .r EKLENDİ
                border: Border.all(color: _borderColor),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10.r, // .r EKLENDİ
                      offset: Offset(0, 4.h)) // .h EKLENDİ
                ],
              ),
              child: Icon(Icons.close_rounded,
                  size: 20.sp, color: _primaryColor), // .sp EKLENDİ
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text("qr_live_results".tr().toUpperCase(),
                    style: TextStyle(
                        fontSize: 10.sp, // .sp EKLENDİ
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: _secondaryColor)),
                SizedBox(height: 4.h), // .h EKLENDİ
                Text(title.isEmpty ? "Results" : title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18.sp, // .sp EKLENDİ
                        fontWeight: FontWeight.bold,
                        color: _primaryColor)),
              ],
            ),
          ),
          SizedBox(width: 48.w), // .w EKLENDİ (Dengelemek için)
        ],
      ),
    );
  }

  Widget _buildViewSelector() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h), // .w .h EKLENDİ
      padding: EdgeInsets.all(4.r), // .r EKLENDİ
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r), // .r EKLENDİ
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10.r, // .r EKLENDİ
              offset: Offset(0, 4.h)) // .h EKLENDİ
        ],
      ),
      child: Row(
        children: _viewModes.map((mode) {
          final isSelected = _currentViewMode == mode;
          String label;
          if (mode == 'LIST')
            label = "view_mode_list".tr();
          else if (mode == 'STATS')
            label = "view_mode_stats".tr();
          else
            label = "view_mode_chart".tr();

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentViewMode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 10.h), // .h EKLENDİ
                decoration: BoxDecoration(
                    color: isSelected ? _primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12.r)), // .r EKLENDİ
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp, // .sp EKLENDİ
                        color: isSelected ? Colors.white : _secondaryColor)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListView(Map<String, dynamic> results) {
    if (results.isEmpty) return _buildEmptyState();
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(
          horizontal: 16.w, vertical: 8.h), // .w .h EKLENDİ
      itemCount: results.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h), // .h EKLENDİ
      itemBuilder: (context, index) {
        final name = results.keys.elementAt(index);
        final answers = (results[name] as List<dynamic>? ?? []);
        return Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r), // .r EKLENDİ
              border: Border.all(color: _borderColor),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4.r, // .r EKLENDİ
                    offset: Offset(0, 2.h)) // .h EKLENDİ
              ]),
          child: ExpansionTile(
            shape: const Border(),
            collapsedIconColor: _secondaryColor,
            iconColor: _primaryColor,
            leading: CircleAvatar(
                backgroundColor: const Color(0xFFEDF2F7),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?",
                    style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp))), // .sp EKLENDİ
            title: Text(name,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                    fontSize: 16.sp)), // .sp EKLENDİ
            children: answers.map((a) {
              if (a is Map) {
                return ListTile(
                    title: Text(a['question']?.toString() ?? '',
                        style: TextStyle(
                            fontSize: 13.sp,
                            color: _secondaryColor)), // .sp EKLENDİ
                    trailing: Text(a['answer']?.toString() ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _primaryColor,
                            fontSize: 14.sp))); // .sp EKLENDİ
              }
              return const SizedBox.shrink();
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildStatsView(Map<String, dynamic> stats) {
    if (stats.isEmpty) return _buildEmptyState();
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(
          horizontal: 16.w, vertical: 8.h), // .w .h EKLENDİ
      children: stats.entries.map((entry) {
        final question = entry.key;
        final entryValue = entry.value as Map<dynamic, dynamic>? ?? {};
        final options =
            Map<String, dynamic>.from(entryValue['options'] as Map? ?? {});
        final questionTotalVotes =
            (entryValue['totalVotes'] as num?)?.toInt() ?? 0;

        return Container(
          margin: EdgeInsets.only(bottom: 16.h), // .h EKLENDİ
          padding: EdgeInsets.all(24.r), // .r EKLENDİ
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r), // .r EKLENDİ
              border: Border.all(color: _borderColor),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4.r, // .r EKLENDİ
                    offset: Offset(0, 2.h)) // .h EKLENDİ
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(question,
                style: TextStyle(
                    fontSize: 16.sp, // .sp EKLENDİ
                    fontWeight: FontWeight.w700,
                    color: _primaryColor)),
            SizedBox(height: 20.h), // .h EKLENDİ
            ...options.entries.map((opt) {
              final optValue = opt.value as Map<dynamic, dynamic>? ?? {};
              final rawPercent =
                  (optValue['percent'] as num?)?.toDouble() ?? 0.0;
              final percent = (rawPercent / 100).clamp(0.0, 1.0);
              return Padding(
                  padding: EdgeInsets.only(bottom: 16.h), // .h EKLENDİ
                  child: Column(children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                              child: Text(opt.key,
                                  style: TextStyle(
                                      color: _primaryColor,
                                      fontSize: 14.sp, // .sp EKLENDİ
                                      fontWeight: FontWeight.w500))),
                          Text("${(percent * 100).toStringAsFixed(0)}%",
                              style: TextStyle(
                                  color: _primaryColor,
                                  fontSize: 14.sp, // .sp EKLENDİ
                                  fontWeight: FontWeight.bold))
                        ]),
                    SizedBox(height: 8.h), // .h EKLENDİ
                    ClipRRect(
                        borderRadius: BorderRadius.circular(4.r), // .r EKLENDİ
                        child: LinearProgressIndicator(
                            value: percent.isNaN ? 0.0 : percent,
                            minHeight: 8.h, // .h EKLENDİ
                            backgroundColor: const Color(0xFFEDF2F7),
                            valueColor: AlwaysStoppedAnimation(_primaryColor))),
                  ]));
            }),
            Divider(height: 32.h, color: _borderColor), // .h EKLENDİ
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("total_respondents".tr(),
                  style: TextStyle(
                      color: _secondaryColor, fontSize: 14.sp)), // .sp EKLENDİ
              Text("$questionTotalVotes",
                  style: TextStyle(
                      color: _primaryColor,
                      fontSize: 16.sp, // .sp EKLENDİ
                      fontWeight: FontWeight.bold))
            ])
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildChartView(Map<String, dynamic> stats) {
    if (stats.isEmpty) return _buildEmptyState();
    final keys = stats.keys.toList();
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(
          horizontal: 16.w, vertical: 8.h), // .w .h EKLENDİ
      itemCount: keys.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: 16.h), // .h EKLENDİ
      itemBuilder: (context, index) {
        final question = keys[index];
        final entryValue = stats[question] as Map<dynamic, dynamic>? ?? {};
        final options =
            Map<String, dynamic>.from(entryValue['options'] as Map? ?? {});
        final totalVotes = (entryValue['totalVotes'] as num?)?.toInt() ?? 0;
        int maxVote = 0;
        options.forEach((_, val) {
          final c = ((val as Map)['count'] as num?)?.toInt() ?? 0;
          if (c > maxVote) maxVote = c;
        });
        final double maxY = (maxVote == 0 ? 5 : maxVote * 1.2).toDouble();
        final barGroups = options.entries.toList().asMap().entries.map((e) {
          final count = ((e.value.value as Map)['count'] as num?)?.toInt() ?? 0;
          return BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(
                toY: count.toDouble(),
                color: _primaryColor,
                width: 22.w, // .w EKLENDİ
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: Colors.grey.withOpacity(0.05)))
          ]);
        }).toList();

        return Container(
          height: 350.h, // .h EKLENDİ
          padding: EdgeInsets.all(24.r), // .r EKLENDİ
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r), // .r EKLENDİ
              border: Border.all(color: _borderColor),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4.r, // .r EKLENDİ
                    offset: Offset(0, 2.h)) // .h EKLENDİ
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(question,
                style: TextStyle(
                    fontSize: 16.sp, // .sp EKLENDİ
                    fontWeight: FontWeight.w700,
                    color: _primaryColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            SizedBox(height: 24.h), // .h EKLENDİ
            Expanded(
                child: BarChart(BarChartData(
                    maxY: maxY,
                    barGroups: barGroups,
                    gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                            color: _borderColor.withOpacity(0.5),
                            strokeWidth: 1,
                            dashArray: [5, 5])),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  if (val < 0 || val.toInt() >= options.length)
                                    return const SizedBox();
                                  final text =
                                      options.keys.elementAt(val.toInt());
                                  return Padding(
                                      padding: EdgeInsets.only(
                                          top: 12.0.h), // .h EKLENDİ
                                      child: Text(
                                          text.length > 8
                                              ? "${text.substring(0, 8)}.."
                                              : text,
                                          style: TextStyle(
                                              fontSize: 11.sp, // .sp EKLENDİ
                                              color: _secondaryColor)));
                                },
                                reservedSize: 30.h))), // .h EKLENDİ
                    barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.white,
                            tooltipBorder: BorderSide(color: _borderColor),
                            tooltipPadding: EdgeInsets.all(8.r), // .r EKLENDİ
                            tooltipMargin: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              if (group.x < 0 || group.x >= options.length)
                                return null;
                              final optionName =
                                  options.keys.elementAt(group.x);
                              return BarTooltipItem(
                                  '$optionName\n',
                                  TextStyle(
                                      color: _secondaryColor,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12.sp), // .sp EKLENDİ
                                  children: <TextSpan>[
                                    TextSpan(
                                        text: '${rod.toY.toInt()} Votes',
                                        style: TextStyle(
                                            color: _primaryColor,
                                            fontSize: 14.sp, // .sp EKLENDİ
                                            fontWeight: FontWeight.bold))
                                  ]);
                            }))))),
            Container(
                margin: EdgeInsets.only(top: 24.h), // .h EKLENDİ
                padding: EdgeInsets.only(top: 16.h), // .h EKLENDİ
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: _borderColor))),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("total_respondents".tr(),
                          style: TextStyle(
                              color: _secondaryColor,
                              fontSize: 14.sp)), // .sp EKLENDİ
                      Text("$totalVotes",
                          style: TextStyle(
                              color: _primaryColor,
                              fontSize: 16.sp, // .sp EKLENDİ
                              fontWeight: FontWeight.bold))
                    ]))
          ]),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.bar_chart_rounded,
          size: 65.sp, color: Colors.grey.shade300), // .sp EKLENDİ
      SizedBox(height: 16.h), // .h EKLENDİ
      Text("result_no_data".tr(),
          style: TextStyle(
              color: Colors.grey.shade400, fontSize: 14.sp)) // .sp EKLENDİ
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final eventRef =
        FirebaseFirestore.instance.collection('events').doc(widget.eventId);
    // URL'yi kendi web linkinize göre düzenleyin
    final qrData = 'https://querycode-app.web.app/event/${widget.eventId}';

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            stream: eventRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || !snapshot.data!.exists)
                return const Center(child: Text("Event not found"));

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final currentTitle = data['eventTitle'] as String? ?? 'Results';

              // --- YENİ: Tarih Verilerini Çek ---
              final Timestamp? startTs = data['startTime'];
              final Timestamp? endTs = data['endTime'];
              // --------------------------------

              final results =
                  Map<String, dynamic>.from(data['results'] as Map? ?? {});
              final questions = data['questions'] as List<dynamic>? ?? [];
              final statsLogicResult = _calculateStatsLogic(results, questions);
              final statsData =
                  statsLogicResult['stats'] as Map<String, dynamic>;

              return Column(
                children: [
                  _buildHeader(context, currentTitle),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // --- YENİ: ZAMAN BİLGİSİ KARTI ---
                          _buildTimeInfoCard(startTs, endTs),
                          // ---------------------------------

                          // QR KODU VE LİNK KARTI
                          Container(
                            margin: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 8.h), // .w .h EKLENDİ
                            padding: EdgeInsets.all(16.r), // .r EKLENDİ
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(16.r), // .r EKLENDİ
                                border: Border.all(color: _borderColor),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 8.r, // .r EKLENDİ
                                      offset: Offset(0, 4.h)) // .h EKLENDİ
                                ]),
                            child: Column(
                              children: [
                                RepaintBoundary(
                                  key: _qrKey,
                                  child: QrImageView(
                                    data: qrData,
                                    size: 180.w, // .w EKLENDİ (QR boyutu)
                                    backgroundColor: Colors.white,
                                    dataModuleStyle: QrDataModuleStyle(
                                        dataModuleShape:
                                            QrDataModuleShape.square,
                                        color: _primaryColor),
                                    eyeStyle: QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: _primaryColor),
                                  ),
                                ),
                                SizedBox(height: 16.h), // .h EKLENDİ
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _shareQrCode(currentTitle, qrData),
                                    icon: Icon(Icons.ios_share_rounded,
                                        color: _primaryColor,
                                        size: 22.sp), // .sp EKLENDİ
                                    label: Text("share_qr".tr(),
                                        style: TextStyle(
                                            color: _primaryColor,
                                            fontSize: 16.sp, // .sp EKLENDİ
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5)),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFF1F5F9),
                                        foregroundColor:
                                            _primaryColor.withOpacity(0.1),
                                        elevation: 0,
                                        side: BorderSide.none,
                                        padding: EdgeInsets.symmetric(
                                            vertical: 18.h), // .h EKLENDİ
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                16.r))), // .r EKLENDİ
                                  ),
                                ),
                                SizedBox(height: 12.h), // .h EKLENDİ
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    onPressed: () => _copyLink(qrData),
                                    icon: Icon(Icons.copy_rounded,
                                        color: _secondaryColor,
                                        size: 20.sp), // .sp EKLENDİ
                                    label: Text("copy_link".tr(),
                                        style: TextStyle(
                                            color: _secondaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14.sp)), // .sp EKLENDİ
                                    style: TextButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 12.h), // .h EKLENDİ
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                12.r), // .r EKLENDİ
                                            side: BorderSide(
                                                color: _borderColor))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8.h), // .h EKLENDİ
                          _buildViewSelector(),
                          SizedBox(height: 8.h), // .h EKLENDİ
                          if (_currentViewMode == 'LIST')
                            _buildListView(results)
                          else if (_currentViewMode == 'STATS')
                            _buildStatsView(statsData)
                          else
                            _buildChartView(statsData),
                          SizedBox(height: 20.h), // .h EKLENDİ
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
    );
  }
}
