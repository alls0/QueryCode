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

class QRResultScreen extends StatefulWidget {
  final String eventId;

  const QRResultScreen({super.key, required this.eventId});

  @override
  State<QRResultScreen> createState() => _QRResultScreenState();
}

class _QRResultScreenState extends State<QRResultScreen> {
  final GlobalKey _qrKey = GlobalKey();
  String _eventTitle = '';

  // --- TASARIM AYARLARI ---
  final List<String> _viewModes = ['LIST', 'STATS', 'CHART'];
  String _currentViewMode = 'LIST';

  // --- RENK PALETİ (GRİ & BEYAZ) ---
  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _primaryColor = const Color(0xFF2D3748);
  final Color _secondaryColor = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

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
      Map<String, int> optionCounts = {};
      
      final optionsList = (question['options'] as List<dynamic>? ?? []);
      for (var option in optionsList) {
        optionCounts[option.toString()] = 0;
      }

      for (var respondentAnswers in results.values) {
        if (respondentAnswers is List) {
          for (var answer in respondentAnswers) {
            if (answer is Map && answer['question'] == questionText) {
              final selectedOption = answer['answer'];
              if (selectedOption != null && optionCounts.containsKey(selectedOption)) {
                optionCounts[selectedOption] = optionCounts[selectedOption]! + 1;
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
            
        finalStats[option] = {
          'count': count,
          'percent': percent, 
        };
      });
      stats[questionText] = {
        'totalVotes': totalVotesForQuestion,
        'options': finalStats,
      };
    }
    return {'stats': stats, 'totalRespondents': totalRespondents};
  }

  // --- QR PAYLAŞIM ---
  Future<void> _shareQrCode() async {
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
            text: "QR Code for $_eventTitle");
      }
    } catch (e) {
      debugPrint("Error sharing QR: $e");
    }
  }

  // --- YENİ MODERN HEADER (APPBAR YERİNE) ---
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Özel Geri Butonu (Kare, Gölgeli, Modern)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _primaryColor),
            ),
          ),

          // 2. Başlık ve Alt Başlık
          Column(
            children: [
              Text(
                "LIVE RESULTS", // Modern bir üst başlık
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: _secondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _eventTitle.isEmpty ? "Results" : _eventTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),

          // 3. Dengeleyici Boşluk (Simetri için)
          const SizedBox(width: 48), 
        ],
      ),
    );
  }

  // --- GÖRÜNÜM SEÇİCİ ---
  Widget _buildViewSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: _viewModes.map((mode) {
          final isSelected = _currentViewMode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentViewMode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  mode == 'LIST' ? "List" : mode == 'STATS' ? "Stats" : "Chart", 
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isSelected ? Colors.white : _secondaryColor,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- LİSTE GÖRÜNÜMÜ ---
  Widget _buildListView(Map<String, dynamic> results) {
    if (results.isEmpty) return _buildEmptyState();
    
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final name = results.keys.elementAt(index);
        final answers = (results[name] as List<dynamic>? ?? []);
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedIconColor: _secondaryColor,
            iconColor: _primaryColor,
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFEDF2F7),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : "?",
                style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)
              ),
            ),
            title: Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: _primaryColor)),
            children: answers.map((a) {
              if (a is Map) {
                return ListTile(
                  title: Text(a['question']?.toString() ?? '', style: TextStyle(fontSize: 13, color: _secondaryColor)),
                  trailing: Text(a['answer']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: _primaryColor)),
                );
              }
              return const SizedBox.shrink();
            }).toList(),
          ),
        );
      },
    );
  }

  // --- İSTATİSTİK GÖRÜNÜMÜ ---
  Widget _buildStatsView(Map<String, dynamic> stats) {
    if (stats.isEmpty) return _buildEmptyState();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: stats.entries.map((entry) {
        final question = entry.key;
        final entryValue = entry.value as Map<dynamic, dynamic>? ?? {};
        final options = Map<String, dynamic>.from(entryValue['options'] as Map? ?? {});
        final questionTotalVotes = (entryValue['totalVotes'] as num?)?.toInt() ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(question, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _primaryColor)),
              const SizedBox(height: 20),
              ...options.entries.map((opt) {
                final optValue = opt.value as Map<dynamic, dynamic>? ?? {};
                final rawPercent = (optValue['percent'] as num?)?.toDouble() ?? 0.0;
                final percent = rawPercent / 100;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(opt.key, style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w500))
                          ),
                          Text("${(percent * 100).toStringAsFixed(0)}%", style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent.isNaN ? 0.0 : percent,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFEDF2F7), 
                          valueColor: AlwaysStoppedAnimation(_primaryColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Divider(height: 32, color: _borderColor),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("total_responses".tr(), style: TextStyle(color: _secondaryColor, fontSize: 14)),
                  Text("$questionTotalVotes", style: TextStyle(color: _primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- GRAFİK GÖRÜNÜMÜ ---
  Widget _buildChartView(Map<String, dynamic> stats) {
     if (stats.isEmpty) return _buildEmptyState();
     
     final keys = stats.keys.toList();
     return PageView.builder(
       controller: PageController(viewportFraction: 0.92),
       itemCount: keys.length,
       itemBuilder: (context, index) {
         final question = keys[index];
         final entryValue = stats[question] as Map<dynamic, dynamic>? ?? {};
         final options = Map<String, dynamic>.from(entryValue['options'] as Map? ?? {});
         final totalVotes = (entryValue['totalVotes'] as num?)?.toInt() ?? 0;
         
         int maxVote = 0;
         options.forEach((_, val) {
           final valMap = val as Map<dynamic, dynamic>? ?? {};
           final c = (valMap['count'] as num?)?.toInt() ?? 0;
           if(c > maxVote) maxVote = c;
         });
         final double maxY = (maxVote == 0 ? 5 : maxVote * 1.2).toDouble();

         final barGroups = options.entries.toList().asMap().entries.map((e) {
            final valMap = e.value.value as Map<dynamic, dynamic>? ?? {};
            final count = (valMap['count'] as num?)?.toInt() ?? 0;
            
            return BarChartGroupData(
              x: e.key,
              barRods: [BarChartRodData(
                toY: count.toDouble(),
                color: _primaryColor,
                width: 32, 
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: Colors.transparent, 
                ),
              )],
            );
         }).toList();

         return Container(
           margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
           padding: const EdgeInsets.all(24),
           decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.circular(16),
             border: Border.all(color: _borderColor), 
             boxShadow: [ 
               BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
             ],
           ),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(
                 question, 
                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _primaryColor),
                 maxLines: 2,
                 overflow: TextOverflow.ellipsis,
               ),
               const SizedBox(height: 24),
               Expanded(
                 child: BarChart(
                   BarChartData(
                     maxY: maxY,
                     barGroups: barGroups,
                     gridData: FlGridData(
                       show: true,
                       drawVerticalLine: false,
                       getDrawingHorizontalLine: (value) => FlLine(
                         color: _borderColor, 
                         strokeWidth: 1,
                         dashArray: [3, 3], 
                       ),
                     ),
                     borderData: FlBorderData(show: false),
                     titlesData: FlTitlesData(
                       topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                       rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                       leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
                       bottomTitles: AxisTitles(
                         sideTitles: SideTitles(
                           showTitles: true,
                           getTitlesWidget: (val, meta) {
                             if (val.toInt() >= options.length) return const SizedBox();
                             final text = options.keys.elementAt(val.toInt());
                             return Padding(
                               padding: const EdgeInsets.only(top: 12.0),
                               child: Text(
                                 text.length > 8 ? "${text.substring(0,8)}.." : text, 
                                 style: TextStyle(fontSize: 12, color: _secondaryColor),
                               ),
                             );
                           },
                           reservedSize: 30,
                         )
                       ),
                     ),
                     barTouchData: BarTouchData(
                       touchTooltipData: BarTouchTooltipData(
                         getTooltipColor: (_) => Colors.white,
                         tooltipBorder: BorderSide(color: _borderColor),
                         tooltipPadding: const EdgeInsets.all(8),
                         tooltipMargin: 8,
                         getTooltipItem: (group, groupIndex, rod, rodIndex) {
                           final optionName = options.keys.elementAt(group.x);
                           return BarTooltipItem(
                             '$optionName\n',
                             TextStyle(color: _secondaryColor, fontWeight: FontWeight.w500, fontSize: 12),
                             children: <TextSpan>[
                               TextSpan(
                                 text: '${rod.toY.toInt()} Votes',
                                 style: TextStyle(color: _primaryColor, fontSize: 14, fontWeight: FontWeight.bold),
                               ),
                             ],
                           );
                         },
                       ),
                     ),
                   ),
                 ),
               ),
               Container(
                 margin: const EdgeInsets.only(top: 24),
                 padding: const EdgeInsets.only(top: 16),
                 decoration: BoxDecoration(
                   border: Border(top: BorderSide(color: _borderColor)),
                 ),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text("total_responses".tr(), style: TextStyle(color: _secondaryColor, fontSize: 14)),
                     Text("$totalVotes", style: TextStyle(color: _primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                   ],
                 ),
               ),
               Center(
                 child: Padding(
                   padding: const EdgeInsets.only(top: 10),
                   child: Text("${index + 1} / ${keys.length}", style: TextStyle(color: Colors.grey.shade300, fontSize: 10)),
                 ),
               )
             ],
           ),
         );
       },
     );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No Data Yet", style: TextStyle(color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);
    final qrData = 'https://querycode-app.web.app/event/${widget.eventId}';

    return Scaffold(
      backgroundColor: _backgroundColor,
      // APPBAR KALDIRILDI, BODY İÇİNDE CUSTOM HEADER VAR
      body: SafeArea(
        child: Column(
          children: [
            // 1. YENİ CUSTOM HEADER
            _buildHeader(context),
            
            // 2. İÇERİK (StreamBuilder)
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: eventRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  
                  if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text("Event not found"));
                  
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  if (_eventTitle.isEmpty) {
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                       if(mounted) setState(() => _eventTitle = data['title'] ?? 'Results');
                     });
                  }
        
                  final results = Map<String, dynamic>.from(data['results'] as Map? ?? {});
                  final questions = data['questions'] as List<dynamic>? ?? [];
                  
                  final stats = _calculateStatsLogic(results, questions);
        
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // QR KODU KARTI
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _borderColor),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))
                            ]
                          ),
                          child: Column(
                            children: [
                              RepaintBoundary(
                                key: _qrKey,
                                child: QrImageView(
                                  data: qrData,
                                  size: 180,
                                  backgroundColor: Colors.white,
                                  dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _primaryColor),
                                  eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: _primaryColor),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _shareQrCode,
                                  icon: Icon(Icons.ios_share_rounded, color: _primaryColor, size: 22),
                                  label: Text(
                                    "share_qr".tr(),
                                    style: TextStyle(
                                      color: _primaryColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF1F5F9), 
                                    foregroundColor: _primaryColor.withOpacity(0.1),
                                    elevation: 0,
                                    side: BorderSide.none,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        _buildViewSelector(),
                        const SizedBox(height: 8),

                        // İÇERİK (LİSTE/GRAFİK)
                        // Expanded yerine Container kullanıyoruz çünkü SingleChildScrollView içindeyiz
                        // Boyut hatası almamak için height veriyoruz veya shrinkWrap kullanıyoruz.
                        // Ancak ListView içinde ListView olduğu için "shrinkWrap: true" ve "physics: NeverScrollableScrollPhysics" kullanmalıyız.
                        // Fakat view modlarına göre dönen widget'lar ListView. O yüzden onları düzenlememiz lazım.
                        // En temizi: _buildListView vb. metodların içindeki ListView'ı Column'a çevirmek veya shrinkWrap eklemektir.
                        // AŞAĞIDAKİ SizedBox ÇÖZÜMÜ GEÇİCİDİR, EKRAN BOYUTUNA GÖRE AYARLANMALIDIR.
                        // DAHA İYİ ÇÖZÜM: SingleChildScrollView'ı kaldırıp Column yapısına geri dönmek.
                        
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}