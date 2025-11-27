import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_result_screen.dart';
import 'package:easy_localization/easy_localization.dart';

// --- MODEL ---
class QuestionModel {
  String questionText;
  List<String> options;
  // Her soru kendi controller'larını tutsun ki PageView'da kaybolmasınlar
  TextEditingController textController;
  List<TextEditingController> optionControllers;

  QuestionModel({
    this.questionText = '',
    required this.options,
  })  : textController = TextEditingController(text: questionText),
        optionControllers =
            options.map((e) => TextEditingController(text: e)).toList();
}

class CreateQuestionScreen extends StatefulWidget {
  const CreateQuestionScreen({super.key});
  @override
  State<CreateQuestionScreen> createState() => _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends State<CreateQuestionScreen> {
  // --- VERİLER ---
  late List<QuestionModel> _questions;
  late TextEditingController _eventTitleController;
  late PageController _pageController;

  int _activeIndex = 0;
  Duration _selectedDuration = Duration.zero;
  bool _isNicknameRequired = true;
  bool _isLoading = false;

  // --- TASARIM RENKLERİ ---
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _primaryDark = const Color(0xFF2D3748);
  final Color primaryDark = const Color(0xFF3182CE);
  final Color _softGrey = const Color(0xFFA0AEC0);
  final Color _surfaceWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _questions = [
      QuestionModel(options: ['', '']),
    ];
    _eventTitleController = TextEditingController();
    _pageController =
        PageController(viewportFraction: 0.92); // Kartların kenarları görünsün
  }

  @override
  void dispose() {
    _eventTitleController.dispose();
    _pageController.dispose();
    for (var q in _questions) {
      q.textController.dispose();
      for (var o in q.optionControllers) {
        o.dispose();
      }
    }
    super.dispose();
  }

  // --- LOGIC: VERİ GÜNCELLEME ---
  void _syncData() {
    // Controller'daki verileri modele eşitle
    for (var q in _questions) {
      q.questionText = q.textController.text;
      q.options = q.optionControllers.map((c) => c.text).toList();
    }
  }

  // --- LOGIC: YENİ SORU EKLEME ---
  void _addNewQuestion() {
    _syncData();
    setState(() {
      _questions.add(QuestionModel(options: ['', '']));
    });
    // Yeni eklenen soruya animasyonla git
    Future.delayed(const Duration(milliseconds: 100), () {
      _pageController.animateToPage(
        _questions.length - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // --- LOGIC: SORU SİLME ---
  void _removeQuestion(int index) {
    if (_questions.length <= 1) return; // En az 1 soru kalmalı

    // Klavyeyi kapat
    FocusScope.of(context).unfocus();

    setState(() {
      _questions.removeAt(index);
      // Index güvenliği
      if (_activeIndex >= _questions.length) {
        _activeIndex = _questions.length - 1;
      }
    });
  }

  // --- LOGIC: ETKİNLİK OLUŞTURMA ---
  Future<void> _createEventAndNavigate() async {
    _syncData(); // Son durumu kaydet
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedEvents =
          prefs.getStringList('saved_events') ?? [];

      if (savedEvents.length >= 15) {
        if (mounted) _showError("memory_full".tr());
        return;
      }

      final eventData = {
        'createdAt': Timestamp.now(),
        'eventTitle': _eventTitleController.text.trim().isNotEmpty
            ? _eventTitleController.text.trim()
            : 'events_prefix'.tr() + (savedEvents.length + 1).toString(),
        'durationInSeconds': _selectedDuration.inSeconds,
        'isNicknameRequired': _isNicknameRequired,
        'questions': _questions
            .map((q) => {'questionText': q.questionText, 'options': q.options})
            .toList(),
        'results': {},
      };

      final docRef =
          await FirebaseFirestore.instance.collection('events').add(eventData);
      final eventId = docRef.id;

      if (!savedEvents.contains(eventId)) {
        savedEvents.add(eventId);
      }
      await prefs.setStringList('saved_events', savedEvents);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => QRResultScreen(eventId: eventId)),
        );
      }
    } catch (e) {
      if (mounted) _showError("create_error".tr() + e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
    setState(() => _isLoading = false);
  }

  // --- UI: BOTTOM SETTINGS SHEET (AYARLAR MENÜSÜ) ---
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Settings",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryDark)),
                const SizedBox(height: 20),

                // Rumuz Ayarı
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("create_nickname_required".tr(),
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: _primaryDark)),
                  value: _isNicknameRequired,
                  activeColor: primaryDark,
                  onChanged: (val) {
                    setSheetState(() => _isNicknameRequired = val);
                    this.setState(() =>
                        _isNicknameRequired = val); // Ana ekranı da güncelle
                  },
                ),
                Divider(color: _bgLight, thickness: 2),

                // Süre Ayarı
                const SizedBox(height: 10),
                Text("create_timer_title".tr(),
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: _primaryDark)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [
                    _buildDurationChip(
                        "30s", const Duration(seconds: 30), setSheetState),
                    _buildDurationChip(
                        "1m", const Duration(minutes: 1), setSheetState),
                    _buildDurationChip(
                        "2m", const Duration(minutes: 2), setSheetState),
                    _buildDurationChip("∞", Duration.zero, setSheetState),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildDurationChip(
      String label, Duration duration, StateSetter setSheetState) {
    bool isSelected = _selectedDuration == duration;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: _primaryDark,
      labelStyle: TextStyle(color: isSelected ? Colors.white : _primaryDark),
      backgroundColor: _bgLight,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (bool selected) {
        setSheetState(() => _selectedDuration = duration);
        this.setState(() => _selectedDuration = duration);
      },
    );
  }

  // --- UI: HEADER ---
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          // Geri Butonu
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _surfaceWhite,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 10)
                  ]),
              child: Icon(Icons.close_rounded, color: _primaryDark, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          // Başlık Input
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: _surfaceWhite,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _eventTitleController,
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: _primaryDark),
                decoration: InputDecoration(
                  hintText: "event_name_hint".tr(),
                  border: InputBorder.none,
                  icon: Icon(Icons.edit_rounded, size: 16, color: _softGrey),
                  hintStyle: TextStyle(color: _softGrey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI: SORU KARTI (CARD) ---
  Widget _buildQuestionCard(int index) {
    final question = _questions[index];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Kart Üstü: Soru Sayısı ve Silme
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: _bgLight, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    "Q${index + 1}",
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _primaryDark,
                        fontSize: 16),
                  ),
                ),
                if (_questions.length > 1)
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: Colors.red.shade300),
                    onPressed: () => _removeQuestion(index),
                  )
              ],
            ),
          ),

          // Soru İçeriği (Kaydırılabilir alan)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Soru Metni
                TextField(
                  controller: question.textController,
                  maxLines: 3,
                  style:
                      TextStyle(fontSize: 18, color: _primaryDark, height: 1.4),
                  decoration: InputDecoration(
                    hintText: "create_question_hint".tr(),
                    hintStyle: TextStyle(
                        color: _softGrey.withOpacity(0.5), fontSize: 18),
                    border: InputBorder.none,
                    filled: true,
                    fillColor: _bgLight,
                    contentPadding: const EdgeInsets.all(16),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: _primaryDark.withOpacity(0.9))),
                  ),
                ),
                const SizedBox(height: 24),

                // Seçenekler Başlığı
                Text("create_options_title".tr(),
                    style: TextStyle(
                        color: _softGrey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1)),
                const SizedBox(height: 12),

                // Seçenek Listesi
                ...List.generate(question.optionControllers.length, (optIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: _primaryDark.withOpacity(0.3),
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: question.optionControllers[optIndex],
                            style: TextStyle(color: _primaryDark),
                            decoration: InputDecoration(
                              hintText: "create_option_hint".tr(),
                              hintStyle:
                                  TextStyle(color: _softGrey.withOpacity(0.5)),
                              border: UnderlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200)),
                              enabledBorder: UnderlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200)),
                              focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: _primaryDark)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Seçenek Ekle Butonu
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        question.options.add('');
                        question.optionControllers.add(TextEditingController());
                      });
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text("Add Option",
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: _primaryDark,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI: BOTTOM BAR (ALT AKSİYON ALANI) ---
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          // Ayarlar Butonu (Sol)
          InkWell(
            onTap: _showSettingsSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _bgLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _selectedDuration != Duration.zero ||
                              !_isNicknameRequired
                          ? _primaryDark
                          : Colors.transparent,
                      width: 2)),
              child: Icon(Icons.tune_rounded, color: _primaryDark),
            ),
          ),

          const Spacer(),

          // Soru Ekle Butonu (Orta - Floating)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _addNewQuestion,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _bgLight,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, color: _primaryDark, size: 20),
                    const SizedBox(width: 8),
                    Text("Question",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: _primaryDark)),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // Oluştur Butonu (Sağ)
          GestureDetector(
            onTap: _isLoading ? null : _createEventAndNavigate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: _primaryDark,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: _primaryDark.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Row(
                      children: [
                        Text("Create",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      // Klavye açıldığında ekranın sıkışmasını önle
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // 1. ÜST BAŞLIK ALANI
            _buildHeader(),

            // 2. KART ALANI (SAYFALAMA)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _questions.length,
                onPageChanged: (index) => setState(() => _activeIndex = index),
                itemBuilder: (context, index) {
                  return _buildQuestionCard(index);
                },
              ),
            ),

            // 3. SAYFA GÖSTERGESİ (NOKTALAR)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_questions.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: _activeIndex == index ? 24 : 6,
                    decoration: BoxDecoration(
                      color: _activeIndex == index
                          ? _primaryDark
                          : _softGrey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

            // 4. ALT AKSİYON BARI
            // Klavye açıkken alt barı gizle veya yukarı taşı mantığı
            Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: _buildBottomBar(),
            ),
          ],
        ),
      ),
    );
  }
}
