import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

// Gerekli Kütüphaneler
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';

class QRResultScreen extends StatefulWidget {
  final String eventId;

  const QRResultScreen({super.key, required this.eventId});

  @override
  State<QRResultScreen> createState() => _QRResultScreenState();
}

class _QRResultScreenState extends State<QRResultScreen> {
  final GlobalKey _qrKey = GlobalKey();
  String _eventTitle = '';

  // --- GÖRÜNÜM VE İSTATİSTİK YÖNETİMİ ---
  final List<String> _viewModes = ['LIST', 'STATS', 'CHART'];
  String _currentViewMode = 'LIST';
  // İstatistikler artık StreamBuilder içinde hesaplanacağı için setState loop'u çözüldü.

  final Color _mainTextColor = const Color(0xFF1A202C); // Ana Metin Rengi
  final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(15),
      blurRadius: 16,
      offset: const Offset(4, 7),
    ),
  ];
  // ----------------------------------------

  // --- İSTATİSTİK HESAPLAMA LOGİĞİ (setState kullanmadan sadece Map döndürür) ---
  Map<String, dynamic> _calculateStatsLogic(
      Map<String, dynamic> results, List<dynamic> questions) {
    if (results.isEmpty) {
      return {'stats': {}, 'totalRespondents': 0};
    }

    int totalRespondents = results.keys.length;
    Map<String, Map<String, dynamic>> stats = {};

    for (var question in questions) {
      final questionText = question['questionText'];
      Map<String, int> optionCounts = {};

      for (var option in question['options']) {
        optionCounts[option] = 0;
      }

      for (var respondentAnswers in results.values) {
        for (var answer in respondentAnswers) {
          if (answer['question'] == questionText) {
            final selectedOption = answer['answer'];
            if (optionCounts.containsKey(selectedOption)) {
              optionCounts[selectedOption] = optionCounts[selectedOption]! + 1;
            }
            break;
          }
        }
      }

      int totalVotesForQuestion =
          optionCounts.values.fold(0, (sum, count) => sum + count);
      Map<String, dynamic> finalStats = {};
      optionCounts.forEach((option, count) {
        finalStats[option] = {
          'count': count,
          'percent': totalVotesForQuestion == 0
              ? 0.0
              : (count / totalVotesForQuestion) * 100,
        };
      });

      stats[questionText] = {
        'totalVotes': totalVotesForQuestion,
        'options': finalStats,
      };
    }

    return {'stats': stats, 'totalRespondents': totalRespondents};
  }
  // -----------------------------------------------------------------------------

  // --- QR KODUNU PAYLAŞMA FONKSİYONU ---
  Future<void> _shareQrCode() async {
    try {
      RenderRepaintBoundary? boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("QR kodu bulunamadı.")),
          );
        }
        return;
      }

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      Uint8List? pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/qr_code_${widget.eventId}.png';
        final File imageFile = File(imagePath);
        await imageFile.writeAsBytes(pngBytes);

        await Share.shareXFiles([XFile(imageFile.path)],
            text: "${_eventTitle} etkinliğinin QR kodu.",
            subject: "Etkinlik QR Kodu");
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("QR kodu oluşturulamadı.")),
          );
        }
      }
    } catch (e) {
      debugPrint("QR Kodu paylaşım hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("QR kodu paylaşılırken bir hata oluştu: $e")),
        );
      }
    }
  }

  // --- GÖRÜNÜM WIDGET'LARININ YÖNETİMİ ---
  Widget _buildCurrentView(Map<String, dynamic> results,
      List<dynamic> questions, Map<String, dynamic> statsData) {
    if (results.isEmpty) {
      return Center(
          child:
              Text("qr_no_results".tr(), style: TextStyle(color: Colors.grey)));
    }

    Map<String, Map<String, dynamic>> questionStats = statsData['stats'];
    int totalRespondents = statsData['totalRespondents'];

    switch (_currentViewMode) {
      case 'STATS':
        return _buildStatsView(questions, questionStats, totalRespondents);
      case 'CHART':
        return _buildChartView(questions, questionStats);
      case 'LIST':
      default:
        // Detaylı Liste Görünümü (Orijinal)
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final name = results.keys.elementAt(index);
            final answers = results[name] as List<dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: _cardShadow.sublist(0, 1), // Daha hafif gölge
              ),
              child: ExpansionTile(
                title: Text(name,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: _mainTextColor)),
                leading: CircleAvatar(
                    child: Text(name.substring(0, 1).toUpperCase())),
                children: answers.map((answerData) {
                  final question =
                      answerData['question'] ?? "qr_question_not_found".tr();
                  final answer = answerData['answer'] ?? '-';
                  return ListTile(
                    title: Text(question,
                        style: const TextStyle(fontStyle: FontStyle.italic)),
                    trailing: Text(answer,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
              ),
            );
          },
        );
    }
  }

  // --- İSTATİSTİK (SAYISAL) GÖRÜNÜMÜ ---
  Widget _buildStatsView(List<dynamic> questions,
      Map<String, Map<String, dynamic>> questionStats, int totalRespondents) {
    List<Widget> questionWidgets = [];

    questionWidgets.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Text(
          "${"total_respondents".tr()}: $totalRespondents",
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
      ),
    );

    questionStats.forEach((questionText, stats) {
      questionWidgets.add(
        Container(
          margin: const EdgeInsets.only(top: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: _cardShadow.sublist(0, 1),
          ),
          child: ExpansionTile(
            title: Text(questionText,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: _mainTextColor)),
            subtitle: Text("${"answer_count".tr()}: ${stats['totalVotes']}"),
            children:
                (stats['options'] as Map<String, dynamic>).entries.map((entry) {
              final option = entry.key;
              final data = entry.value;
              final count = data['count'];
              final percent = data['percent'].toStringAsFixed(1);

              return ListTile(
                leading: Text(option),
                trailing: Text("$count (${percent}%)",
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              );
            }).toList(),
          ),
        ),
      );
    });

    return ListView(children: questionWidgets);
  }

  // --- SÜTUN GRAFİĞİ GÖRÜNÜMÜ (fl_chart) ---
  // Dosya: lib/screens/qr_result_screen.dart
// MEVCUT _buildChartView FONKSİYONUNU TAMAMEN DEĞİŞTİR:

  Widget _buildChartView(List<dynamic> questions,
      Map<String, Map<String, dynamic>> questionStats) {
    if (questionStats.isEmpty) {
      return Center(child: Text("qr_no_results".tr()));
    }

    // İlk sorunun istatistiklerini al
    final firstQuestionText = questionStats.keys.first;
    final firstQuestionStats = questionStats[firstQuestionText];

    if (firstQuestionStats == null || firstQuestionStats['totalVotes'] == 0) {
      return const Center(child: Text("Henüz oy yok."));
    }

    final Map<String, dynamic> options = firstQuestionStats['options'];

    // Güvenli maksimum oy sayısını hesaplama (Hata vermesi muhtemel olan 'as int' düzeltildi)
    final int maxVotes = options.values
        .map((v) => v['count'] as int)
        .reduce((a, b) => a > b ? a : b);

    List<BarChartGroupData> barGroups =
        options.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;

      // HATA DÜZELTME: int tipindeki 'count' değeri .toDouble() metodu ile güvenli şekilde dönüştürüldü.
      final count = (entry.value.value['count'] as int).toDouble();

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count, // Artık double tipinde
            color: Colors.blue.shade600,
            width: 15,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        showingTooltipIndicators: const [0],
      );
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              firstQuestionText,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _mainTextColor),
            ),
          ),
          Container(
            height: 300,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: _cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 16, bottom: 8),
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final optionName =
                              options.keys.elementAt(value.toInt());
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 4,
                            child: Text(
                                optionName.substring(
                                        0,
                                        optionName.length > 8
                                            ? 8
                                            : optionName.length) +
                                    (optionName.length > 8 ? '...' : ''),
                                style: TextStyle(
                                    fontSize: 10, color: _mainTextColor)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: (maxVotes / 4).ceilToDouble() > 1
                            ? (maxVotes / 4).ceilToDouble()
                            : 1,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString(),
                              style: TextStyle(
                                  fontSize: 10, color: _mainTextColor));
                        },
                      ),
                    ),
                  ),
                  gridData:
                      const FlGridData(show: true, drawVerticalLine: false),
                  maxY: (maxVotes * 1.2).ceilToDouble() > 5
                      ? (maxVotes * 1.2).ceilToDouble()
                      : 5,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  groupsSpace: 20,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: options.entries.map((entry) {
                final option = entry.key;
                final count = entry.value['count'];
                final percent = entry.value['percent'].toStringAsFixed(1);
                return Text(
                  "$option: $count (${percent}%)",
                  style: TextStyle(fontSize: 14, color: _mainTextColor),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final DocumentReference eventRef =
        FirebaseFirestore.instance.collection('events').doc(widget.eventId);
    final String qrData =
        'https://querycode-app.web.app/event/${widget.eventId}';

    return StreamBuilder<DocumentSnapshot>(
      stream: eventRef.snapshots(),
      builder: (context, snapshot) {
        // HATA DÜZELTME: Bu noktadan sonra return edilmeyen kısımlar UI güncellemesine sebep olmaz.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text("qr_live_title".tr())),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.data() == null) {
          return Scaffold(
            appBar: AppBar(title: Text("qr_live_title".tr())),
            body: Center(child: Text("qr_error_loading".tr())),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        _eventTitle = data['eventTitle'] ?? "qr_live_title".tr();

        final results = (data['results'] as Map<String, dynamic>?) ?? {};

        // FIX: İstatistik hesaplamayı doğrudan StreamBuilder içinde çalıştırıp sonuçları kullanıyoruz.
        // Bu, sürekli setState döngüsünü engeller.
        final statsData =
            _calculateStatsLogic(results, data['questions'] ?? []);

        return Scaffold(
          extendBodyBehindAppBar: true, // Gradient'in yukarı kadar çıkması için
          appBar: AppBar(
              backgroundColor: Colors.transparent, // Şeffaf AppBar
              elevation: 0,
              title: Text(_eventTitle,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: _mainTextColor)),
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: _mainTextColor),
                onPressed: () => Navigator.pop(context),
              )),
          body: Container(
            // ARKA PLAN GRADIENT STİLİ UYGULANDI
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(192, 58, 142, 202),
                  Color.fromARGB(255, 219, 225, 232)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // QR BÖLÜMÜ
                    Text(
                      "qr_scan_prompt".tr(),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _mainTextColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      // QR KODU KARTI UYGULAMANIN STİLİNE BENZETİLDİ
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: _cardShadow,
                      ),
                      child: RepaintBoundary(
                        key: _qrKey,
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 180.0,
                        ),
                      ),
                    ),

                    // PAYLAŞIM LİNKİ VE ID
                    Text("qr_share_id_prompt".tr(),
                        style: TextStyle(color: _mainTextColor)),
                    SelectableText(
                      qrData,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3182CE)),
                    ),
                    const SizedBox(height: 20),

                    // PAYLAŞ BUTONU
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _shareQrCode,
                        icon: const Icon(Icons.share, color: Colors.white),
                        label: Text("share_qr".tr(),
                            style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // GÖRÜNÜM MODU SEÇİMİ VE CANLI SONUÇLAR BAŞLIĞI
                    Text(
                      "qr_live_results".tr(),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _mainTextColor),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ToggleButtons(
                        isSelected: _viewModes
                            .map((mode) => mode == _currentViewMode)
                            .toList(),
                        onPressed: (int index) {
                          setState(() {
                            // Bu setState sadece görünüm modunu değiştirir (LIST, STATS, CHART)
                            _currentViewMode = _viewModes[index];
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: Colors.blue.shade600,
                        color: Colors.grey.shade700,
                        borderColor: Colors.grey.shade400,
                        selectedBorderColor: Colors.blue.shade600,
                        children: [
                          // FIX: Yatay padding 12'den 8'e düşürülerek 24 piksel alan kazanıldı.
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text("view_mode_list".tr())),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text("view_mode_stats".tr())),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text("view_mode_chart".tr())),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // GÖRÜNÜM YÖNETİCİSİ
                    Expanded(
                      child: _buildCurrentView(
                          results, data['questions'] ?? [], statsData),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
