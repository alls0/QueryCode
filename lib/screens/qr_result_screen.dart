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
  
  // React tasarımındaki renk paleti
  final Color _backgroundColor = const Color(0xFFF8FAFC); // Slate-50
  final Color _primaryBlue = const Color(0xFF3B82F6);     // Blue-500
  final Color _textDark = const Color(0xFF0F172A);        // Slate-900
  final Color _textGray = const Color(0xFF64748B);        // Slate-500
  final Color _borderColor = const Color(0xFFE2E8F0);     // Slate-200

  // --- İSTATİSTİK HESAPLAMA ---
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

  // --- QR MODAL ---
  void _showQrModal(BuildContext context, String qrData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            RepaintBoundary(
              key: _qrKey,
              child: QrImageView(
                data: qrData,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share, color: Colors.white),
                label: Text("share_qr".tr()), 
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _shareQrCode();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- GÖRÜNÜM SEÇİCİ (Segmented Control) ---
  Widget _buildViewSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
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
                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent, // Blue-50
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  // Dil dosyasına göre: "Liste", "İstatistik", "Grafik"
                  mode == 'LIST' ? "List" : mode == 'STATS' ? "Stats" : "Chart", 
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isSelected ? _primaryBlue : _textGray,
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
        final answers = results[name] as List<dynamic>;
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 2,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: ExpansionTile(
            shape: const Border(),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF1F5F9),
              child: Text(name[0].toUpperCase(), style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold)),
            ),
            title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: _textDark)),
            children: answers.map((a) => ListTile(
              title: Text(a['question'], style: TextStyle(fontSize: 13, color: _textGray)),
              trailing: Text(a['answer'], style: TextStyle(fontWeight: FontWeight.w600, color: _textDark)),
            )).toList(),
          ),
        );
      },
    );
  }

  // --- İSTATİSTİK GÖRÜNÜMÜ ---
  Widget _buildStatsView(Map<String, Map<String, dynamic>> stats) {
    if (stats.isEmpty) return _buildEmptyState();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: stats.entries.map((entry) {
        final question = entry.key;
        final options = entry.value['options'] as Map<String, dynamic>;
        
        // Bu soruya verilen toplam oy sayısı
        final questionTotalVotes = entry.value['totalVotes'] as int;

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
              Text(question, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textDark)),
              const SizedBox(height: 20),
              ...options.entries.map((opt) {
                final count = opt.value['count'] as int;
                final percent = (opt.value['percent'] as double) / 100;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(opt.key, style: TextStyle(color: _textDark, fontWeight: FontWeight.w500)),
                          Text("${(percent * 100).toStringAsFixed(0)}%", style: TextStyle(color: _textDark, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFF1F5F9), // Slate-100
                          valueColor: AlwaysStoppedAnimation(_primaryBlue),
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
                  Text("total_responses".tr(), style: TextStyle(color: _textGray)),
                  Text("$questionTotalVotes", style: TextStyle(color: _textDark, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- GRAFİK GÖRÜNÜMÜ (React Tasarımı Entegre Edildi) ---
  Widget _buildChartView(Map<String, Map<String, dynamic>> stats) {
     if (stats.isEmpty) return _buildEmptyState();
     
     final keys = stats.keys.toList();
     return PageView.builder(
       controller: PageController(viewportFraction: 0.92),
       itemCount: keys.length,
       itemBuilder: (context, index) {
         final question = keys[index];
         final options = stats[question]!['options'] as Map<String, dynamic>;
         final totalVotes = stats[question]!['totalVotes'] as int;
         
         // Maksimum oy sayısını bul (Y ekseni aralığı için)
         int maxVote = 0;
         options.forEach((_, val) {
           final c = val['count'] as int;
           if(c > maxVote) maxVote = c;
         });
         // Y ekseninin biraz boşluklu durması için tavan değer
         final double maxY = (maxVote == 0 ? 5 : maxVote * 1.2).toDouble();

         final barGroups = options.entries.toList().asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [BarChartRodData(
                toY: (e.value.value['count'] as int).toDouble(),
                color: _primaryBlue, // React kodundaki #3B82F6
                width: 32, // Biraz daha kalın çubuklar
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: Colors.transparent, // Arkaplan çubuğu görünmez
                ),
              )],
            );
         }).toList();

         return Container(
           margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
           padding: const EdgeInsets.all(24),
           decoration: BoxDecoration(
             color: Colors.white, // bg-white
             borderRadius: BorderRadius.circular(16), // rounded-2xl
             border: Border.all(color: _borderColor), // border-gray-100
             boxShadow: [ // shadow-sm
               BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
             ],
           ),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               // Başlık
               Text(
                 question, 
                 style: TextStyle(
                   fontSize: 16, 
                   fontWeight: FontWeight.w600, 
                   color: _textDark // text-gray-900
                 ),
                 maxLines: 2,
                 overflow: TextOverflow.ellipsis,
               ),
               const SizedBox(height: 24),
               
               // Grafik Alanı
               Expanded(
                 child: BarChart(
                   BarChartData(
                     maxY: maxY,
                     barGroups: barGroups,
                     // Izgara Çizgileri (React: strokeDasharray="3 3")
                     gridData: FlGridData(
                       show: true,
                       drawVerticalLine: false,
                       getDrawingHorizontalLine: (value) => FlLine(
                         color: const Color(0xFFF1F5F9), // stroke="#F1F5F9"
                         strokeWidth: 1,
                         dashArray: [3, 3], // Kesikli çizgi efekti
                       ),
                     ),
                     // Kenarlıklar
                     borderData: FlBorderData(show: false),
                     // Eksen Başlıkları
                     titlesData: FlTitlesData(
                       topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                       rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                       // Y Ekseni (React: AxisLine=false)
                       leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
                       // X Ekseni
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
                                 style: TextStyle(
                                   fontSize: 12, 
                                   color: _textGray // fill="#64748B"
                                 ),
                               ),
                             );
                           },
                           reservedSize: 30,
                         )
                       ),
                     ),
                     // Tooltip Ayarları
                     barTouchData: BarTouchData(
                       touchTooltipData: BarTouchTooltipData(
                         getTooltipColor: (_) => Colors.white, // backgroundColor: 'white'
                         tooltipBorder: BorderSide(color: _borderColor), // border
                         tooltipPadding: const EdgeInsets.all(8),
                         tooltipMargin: 8,
                         // İçerik stili
                         getTooltipItem: (group, groupIndex, rod, rodIndex) {
                           final optionName = options.keys.elementAt(group.x);
                           return BarTooltipItem(
                             '$optionName\n',
                             TextStyle(
                               color: _textGray,
                               fontWeight: FontWeight.w500,
                               fontSize: 12,
                             ),
                             children: <TextSpan>[
                               TextSpan(
                                 text: '${rod.toY.toInt()} Votes',
                                 style: TextStyle(
                                   color: _textDark,
                                   fontSize: 14,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                             ],
                           );
                         },
                       ),
                     ),
                   ),
                 ),
               ),
               
               // Footer Alanı (React: mt-6 pt-4 border-t border-gray-100)
               Container(
                 margin: const EdgeInsets.only(top: 24),
                 padding: const EdgeInsets.only(top: 16),
                 decoration: BoxDecoration(
                   border: Border(top: BorderSide(color: const Color(0xFFF1F5F9))),
                 ),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(
                       "total_responses".tr(), // Total Responses
                       style: TextStyle(color: _textGray, fontSize: 14),
                     ),
                     Text(
                       "$totalVotes", 
                       style: TextStyle(color: _textDark, fontSize: 16, fontWeight: FontWeight.bold),
                     ),
                   ],
                 ),
               ),
               
               // Sayfa İndikatörü (Ekstra)
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(_eventTitle.isEmpty ? "Results" : _eventTitle, style: TextStyle(color: _textDark, fontWeight: FontWeight.bold)),
        leading: BackButton(color: _textDark),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_2_rounded, color: _primaryBlue),
            onPressed: () => _showQrModal(context, qrData),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
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

          final results = Map<String, dynamic>.from(data['results'] ?? {});
          final questions = data['questions'] ?? [];
          final stats = _calculateStatsLogic(results, questions);

          return Column(
            children: [
              _buildViewSelector(),
              Expanded(
                child: _currentViewMode == 'LIST' 
                  ? _buildListView(results)
                  : _currentViewMode == 'STATS'
                    ? _buildStatsView(stats['stats'])
                    : _buildChartView(stats['stats']),
              ),
            ],
          );
        },
      ),
    );
  }
}