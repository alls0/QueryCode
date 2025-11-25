import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_result_screen.dart';
import 'package:easy_localization/easy_localization.dart'; // YENİ: Paketi import et

class QuestionModel {
  String questionText;
  List<String> options;
  QuestionModel({this.questionText = '', required this.options});
}

class CreateQuestionScreen extends StatefulWidget {
  const CreateQuestionScreen({super.key});
  @override
  State<CreateQuestionScreen> createState() => _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends State<CreateQuestionScreen> {
  final List<QuestionModel> _questions = [
    QuestionModel(options: ['', '']),
  ];
  // _CreateQuestionScreenState sınıfının içine, diğer değişkenlerin (ör: final List<QuestionModel> _questions = [...];) hemen altına ekle.
  late TextEditingController _eventTitleController;
// ...
  int _activeIndex = 0;
  Duration _selectedDuration = Duration.zero;
  bool _isNicknameRequired = true;
  late TextEditingController _questionController;
  late List<TextEditingController> _optionControllers;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupControllersForIndex(_activeIndex);
    // YENİ: Başlık kontrolcüsünü başlat
    _eventTitleController = TextEditingController();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _eventTitleController.dispose(); // YENİ: Başlık kontrolcüsünü kapat
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // MEVCUT _createEventAndNavigate FONKSİYONUNU BUNUNLA DEĞİŞTİR:
  Future<void> _createEventAndNavigate() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedEvents =
          prefs.getStringList('saved_events') ?? [];

      if (savedEvents.length >= 15) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("memory_full".tr()),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      _saveCurrentQuestionData();
      final eventData = {
        'createdAt': Timestamp.now(),
        // YENİ: Başlık bilgisini ekle
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("create_error".tr() + e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupControllersForIndex(int index) {
    _questionController =
        TextEditingController(text: _questions[index].questionText);
    _optionControllers = _questions[index]
        .options
        .map((option) => TextEditingController(text: option))
        .toList();
  }

  void _saveCurrentQuestionData() {
    _questions[_activeIndex].questionText = _questionController.text;
    for (int i = 0; i < _optionControllers.length; i++) {
      if (i < _questions[_activeIndex].options.length) {
        _questions[_activeIndex].options[i] = _optionControllers[i].text;
      }
    }
  }

  void _saveAndSwitchTo(int newIndex) {
    _saveCurrentQuestionData();
    setState(() {
      _activeIndex = newIndex;
      _setupControllersForIndex(newIndex);
    });
  }

  void _selectTime(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "create_timer_title".tr(),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF1A202C)),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10.0,
                runSpacing: 10.0,
                alignment: WrapAlignment.center,
                children: [
                  _buildDurationChip(
                      "time_30s".tr(), const Duration(seconds: 30)),
                  _buildDurationChip(
                      "time_1m".tr(), const Duration(minutes: 1)),
                  _buildDurationChip(
                      "time_2m".tr(), const Duration(minutes: 2)),
                  _buildDurationChip(
                      "time_5m".tr(), const Duration(minutes: 5)),
                  _buildDurationChip("time_indefinite".tr(), Duration.zero),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDurationChip(String label, Duration duration) {
    bool isSelected = _selectedDuration == duration;
    return ActionChip(
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF1A202C),
        fontWeight: FontWeight.bold,
      ),
      backgroundColor:
          isSelected ? Colors.blue.shade600 : const Color(0xFFE2E8F0),
      onPressed: () {
        setState(() {
          _selectedDuration = duration;
        });
        Navigator.pop(context);
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) {
      return "time_indefinite".tr();
    }
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final consistentCardShadow = [
      BoxShadow(
          color: Colors.black.withAlpha(20),
          blurRadius: 18,
          offset: const Offset(0, 7)),
    ];
    const mainColor = Color(0xFF1A202C);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: mainColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("create_title".tr(),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: mainColor, fontSize: 21)),
        centerTitle: true,
      ),
      body: Container(
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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            children: [
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(230, 255, 255, 255),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: consistentCardShadow,
                ),
                child: TextField(
                  controller: _eventTitleController,
                  decoration: InputDecoration(
                      hintText: "event_name_hint".tr(),
                      border: InputBorder.none),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ..._questions.asMap().entries.map((entry) {
                      int index = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: GestureDetector(
                          onTap: () => _saveAndSwitchTo(index),
                          child: _buildTabButton(
                              "${"create_question_tab_prefix".tr()}${index + 1}",
                              isActive: _activeIndex == index),
                        ),
                      );
                    }),
                    _buildAddButton(() {
                      _saveAndSwitchTo(_activeIndex);
                      setState(() {
                        _questions.add(QuestionModel(options: ['', '']));
                        _saveAndSwitchTo(_questions.length - 1);
                      });
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(230, 255, 255, 255),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: consistentCardShadow,
                ),
                child: TextField(
                  controller: _questionController,
                  decoration: InputDecoration(
                      hintText: "create_question_hint".tr(),
                      border: InputBorder.none),
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text("create_options_title".tr(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color.fromARGB(255, 40, 43, 51))),
              ),
              ..._optionControllers.asMap().entries.map((entry) {
                int index = entry.key;
                TextEditingController controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildOptionRow(
                      '${index + 1}', "create_option_hint".tr(), controller),
                );
              }),
              Center(
                child: _buildAddButton(() {
                  setState(() {
                    _questions[_activeIndex].options.add('');
                    _optionControllers.add(TextEditingController());
                  });
                }, isLarge: true),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(230, 255, 255, 255),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: consistentCardShadow,
                ),
                child: SwitchListTile(
                  title: Text(
                    "create_nickname_required".tr(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: mainColor),
                  ),
                  value: _isNicknameRequired,
                  onChanged: (bool value) {
                    setState(() {
                      _isNicknameRequired = value;
                    });
                  },
                  activeColor: Colors.blue.shade600,
                  contentPadding: const EdgeInsets.only(left: 16, right: 8),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _isLoading ? null : _createEventAndNavigate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 28),
                    decoration: BoxDecoration(
                      color: _isLoading
                          ? Colors.grey
                          : const Color.fromARGB(255, 0, 135, 253),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.blue.withAlpha(40),
                            blurRadius: 16,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code_2_rounded,
                                  size: 30, color: Colors.white),
                              const SizedBox(width: 14),
                              Text("create_qr_button".tr(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16))
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _selectTime(context),
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: const BoxDecoration(
                            color: mainColor, shape: BoxShape.circle),
                        child: const Icon(Icons.timer_outlined,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 13),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(17),
                          boxShadow: consistentCardShadow),
                      child: Text(
                        _formatDuration(_selectedDuration),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: mainColor),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, {required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1A202C) : Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Text(text,
          style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF4A5568),
              fontWeight: FontWeight.bold,
              fontSize: 15)),
    );
  }

  Widget _buildAddButton(VoidCallback onTap, {bool isLarge = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        width: isLarge ? 54 : 44,
        height: isLarge ? 54 : 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(23),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Icon(Icons.add,
            color: const Color(0xFF4A5568), size: isLarge ? 29 : 22),
      ),
    );
  }

  Widget _buildOptionRow(
      String number, String hintText, TextEditingController controller) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
              color: Color(0xFF1A202C), shape: BoxShape.circle),
          child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
