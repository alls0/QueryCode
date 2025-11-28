import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_result_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path_utils;

// --- MODEL ---
class QuestionModel {
  String questionText;
  List<String> options;
  TextEditingController textController;
  List<TextEditingController> optionControllers;
  List<Map<String, String>> attachments;

  QuestionModel({
    this.questionText = '',
    required this.options,
    List<Map<String, String>>? attachments,
  })  : textController = TextEditingController(text: questionText),
        optionControllers =
            options.map((e) => TextEditingController(text: e)).toList(),
        attachments = attachments ?? [];
}

class CreateQuestionScreen extends StatefulWidget {
  const CreateQuestionScreen({super.key});
  @override
  State<CreateQuestionScreen> createState() => _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends State<CreateQuestionScreen> {
  // --- LİMİTLER ---
  static const int _maxQuestions = 10;
  static const int _maxOptions = 10;
  static const int _maxAttachments = 3;

  late List<QuestionModel> _questions;
  late TextEditingController _eventTitleController;
  late PageController _pageController;

  int _activeIndex = 0;
  Duration _selectedDuration = Duration.zero;
  bool _isNicknameRequired = true;
  bool _isLoading = false;
  final String _loadingText =
      "..."; // Sadeleştirilmiş yükleme metni

  final ImagePicker _picker = ImagePicker();

  // Tasarım Renkleri
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _primaryDark = const Color(0xFF1A202C);
  final Color _primaryBlue = const Color(0xFF3182CE);
  final Color _softGrey = const Color(0xFFA0AEC0);
  final Color _surfaceWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _questions = [
      QuestionModel(options: ['', ''])
    ];
    _eventTitleController = TextEditingController();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _eventTitleController.dispose();
    _pageController.dispose();
    for (var q in _questions) {
      q.textController.dispose();
      for (var o in q.optionControllers) o.dispose();
    }
    super.dispose();
  }

  // --- MEDYA İŞLEMLERİ ---
  Future<void> _pickImage(int index, ImageSource source) async {
    // LİMİT KONTROLÜ
    if (_questions[index].attachments.length >= _maxAttachments) {
      _showWarning("Maksimum $_maxAttachments görsel ekleyebilirsiniz.");
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _questions[index]
              .attachments
              .add({'path': image.path, 'type': 'image'});
        });
      }
    } catch (e) {
      debugPrint("Resim hatası: $e");
    }
  }

  Future<void> _pickFile(int index) async {
    // LİMİT KONTROLÜ
    if (_questions[index].attachments.length >= _maxAttachments) {
      _showWarning("Maksimum $_maxAttachments dosya ekleyebilirsiniz.");
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() {
          _questions[index]
              .attachments
              .add({'path': result.files.single.path!, 'type': 'file'});
        });
      }
    } catch (e) {
      debugPrint("Dosya hatası: $e");
    }
  }

  void _removeAttachment(int questionIndex, int attachmentIndex) {
    setState(() {
      _questions[questionIndex].attachments.removeAt(attachmentIndex);
    });
  }

  void _showAttachmentOptions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                  leading: Icon(Icons.camera_alt_rounded, color: _primaryDark),
                  title: Text('Fotoğraf Çek',
                      style: TextStyle(color: _primaryDark)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(index, ImageSource.camera);
                  }),
              ListTile(
                  leading:
                      Icon(Icons.photo_library_rounded, color: _primaryDark),
                  title: Text('Galeriden Seç',
                      style: TextStyle(color: _primaryDark)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(index, ImageSource.gallery);
                  }),
              ListTile(
                  leading: Icon(Icons.attach_file_rounded, color: _primaryDark),
                  title:
                      Text('Dosya Ekle', style: TextStyle(color: _primaryDark)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile(index);
                  }),
            ],
          ),
        );
      },
    );
  }

  void _syncData() {
    for (var q in _questions) {
      q.questionText = q.textController.text;
      q.options = q.optionControllers.map((c) => c.text).toList();
    }
  }

  void _addNewQuestion() {
    // LİMİT KONTROLÜ
    if (_questions.length >= _maxQuestions) {
      _showWarning("En fazla $_maxQuestions soru oluşturabilirsiniz.");
      return;
    }

    _syncData();
    setState(() => _questions.add(QuestionModel(options: ['', ''])));
    Future.delayed(const Duration(milliseconds: 100), () {
      _pageController.animateToPage(_questions.length - 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _questions.removeAt(index);
      if (_activeIndex >= _questions.length)
        _activeIndex = _questions.length - 1;
    });
  }

  // --- LOGIC: FIREBASE STORAGE YÜKLEME ---
  Future<String> _uploadFileToStorage(String localPath) async {
    File file = File(localPath);
    String fileName =
        "${DateTime.now().millisecondsSinceEpoch}_${path_utils.basename(localPath)}";

    Reference storageRef =
        FirebaseStorage.instance.ref().child('uploads/$fileName');

    UploadTask uploadTask = storageRef.putFile(file);
    TaskSnapshot snapshot = await uploadTask;

    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _createEventAndNavigate() async {
    _syncData();
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedEvents =
          prefs.getStringList('saved_events') ?? [];

      if (savedEvents.length >= 15) {
        if (mounted) _showWarning("memory_full".tr());
        return;
      }

      List<Map<String, dynamic>> processedQuestions = [];

      for (int i = 0; i < _questions.length; i++) {
        var q = _questions[i];
        List<Map<String, String>> uploadedAttachments = [];

        for (int j = 0; j < q.attachments.length; j++) {
          var attachment = q.attachments[j];
          String localPath = attachment['path']!;
          String type = attachment['type']!;

          try {
            if (!localPath.startsWith('http')) {
              String downloadUrl = await _uploadFileToStorage(localPath);
              uploadedAttachments.add({'path': downloadUrl, 'type': type});
            } else {
              uploadedAttachments.add(attachment);
            }
          } catch (e) {
            debugPrint("Dosya yükleme hatası: $e");
            if (mounted) {
              _showWarning("Yükleme hatası (Q${i + 1}): ${e.toString()}");
            }
          }
        }

        processedQuestions.add({
          'questionText': q.questionText,
          'options': q.options,
          'attachments': uploadedAttachments,
        });
      }

      final eventData = {
        'createdAt': Timestamp.now(),
        'eventTitle': _eventTitleController.text.trim().isNotEmpty
            ? _eventTitleController.text.trim()
            : 'events_prefix'.tr() + (savedEvents.length + 1).toString(),
        'durationInSeconds': _selectedDuration.inSeconds,
        'isNicknameRequired': _isNicknameRequired,
        'questions': processedQuestions,
        'results': {},
      };

      final docRef =
          await FirebaseFirestore.instance.collection('events').add(eventData);
      final eventId = docRef.id;

      if (!savedEvents.contains(eventId)) savedEvents.add(eventId);
      await prefs.setStringList('saved_events', savedEvents);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => QRResultScreen(eventId: eventId)),
        );
      }
    } catch (e) {
      if (mounted) _showWarning("create_error".tr() + e.toString());
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  // --- UI PARÇALARI ---

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
                offset: const Offset(0, 10))
          ]),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: _bgLight,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text("Q${index + 1}",
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _primaryDark,
                            fontSize: 16))),
                if (_questions.length > 1)
                  IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: Colors.red.shade300),
                      onPressed: () => _removeQuestion(index))
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextField(
                    controller: question.textController,
                    maxLines: 3,
                    style: TextStyle(
                        fontSize: 18, color: _primaryDark, height: 1.4),
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
                            borderSide: BorderSide(
                                color: _primaryDark.withOpacity(0.9))))),
                const SizedBox(height: 16),

                // --- MEDYA LİSTESİ (ÖNİZLEME) ---
                if (question.attachments.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: question.attachments.length,
                      itemBuilder: (context, attachIndex) {
                        final attachment = question.attachments[attachIndex];
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: _bgLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                                image: attachment['type'] == 'image'
                                    ? DecorationImage(
                                        image: FileImage(
                                            File(attachment['path']!)),
                                        fit: BoxFit.cover)
                                    : null,
                              ),
                              child: attachment['type'] == 'file'
                                  ? Center(
                                      child: Icon(Icons.insert_drive_file,
                                          color: _primaryDark))
                                  : null,
                            ),
                            Positioned(
                              top: 4,
                              right: 16,
                              child: GestureDetector(
                                onTap: () =>
                                    _removeAttachment(index, attachIndex),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            blurRadius: 2,
                                            color: Colors.black12)
                                      ]),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.red),
                                ),
                              ),
                            )
                          ],
                        );
                      },
                    ),
                  ),

                // Medya Ekle Butonu
                InkWell(
                  onTap: () => _showAttachmentOptions(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                        color: _bgLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _primaryDark.withOpacity(0.2),
                            style: BorderStyle.solid)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: _primaryDark, size: 20),
                          const SizedBox(width: 8),
                          Text(
                              question.attachments.length >= _maxAttachments
                                  ? "Limit Doldu (${question.attachments.length}/$_maxAttachments)"
                                  : "Medya Ekle (${question.attachments.length}/$_maxAttachments)",
                              style: TextStyle(
                                  color: _primaryDark,
                                  fontWeight: FontWeight.w600))
                        ]),
                  ),
                ),

                const SizedBox(height: 24),

                Text("create_options_title".tr(),
                    style: TextStyle(
                        color: _softGrey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1)),
                const SizedBox(height: 12),
...List.generate(question.optionControllers.length, (optIndex) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        // Sol taraftaki yuvarlak işaret
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: _primaryDark.withOpacity(0.3),
                shape: BoxShape.circle)),
        const SizedBox(width: 12),

        // Seçenek Metin Alanı
        Expanded(
            child: TextField(
                controller: question.optionControllers[optIndex],
                style: TextStyle(color: _primaryDark),
                decoration: InputDecoration(
                    hintText: "create_option_hint".tr(),
                    hintStyle: TextStyle(
                        color: _softGrey.withOpacity(0.5)),
                    border: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: Colors.grey.shade200)),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: Colors.grey.shade200)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: _primaryDark))))),

        // --- SİLME BUTONU ---
        // Sadece 2'den fazla seçenek varsa gösterilir
        if (question.optionControllers.length > 2)
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: Colors.red.shade300, size: 22),
            onPressed: () {
              setState(() {
                // Controller'ı temizle ve listeden kaldır
                question.optionControllers[optIndex].dispose();
                question.optionControllers.removeAt(optIndex);
                question.options.removeAt(optIndex);
              });
            },
          ),
      ],
    ),
  );
}),
                const SizedBox(height: 8),
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: () {
                          // LİMİT KONTROLÜ
                          if (question.options.length >= _maxOptions) {
                            _showWarning(
                                "En fazla $_maxOptions seçenek ekleyebilirsiniz.");
                            return;
                          }
                          setState(() {
                            question.options.add('');
                            question.optionControllers
                                .add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                            "Seçenek Ekle (${question.options.length}/$_maxOptions)",
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                            foregroundColor: _primaryDark,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _surfaceWhite,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10)
                      ]),
                  child: Icon(Icons.close_rounded,
                      color: _primaryDark, size: 20))),
          const SizedBox(width: 16),
          Expanded(
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                      color: _surfaceWhite,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: TextField(
                      controller: _eventTitleController,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: _primaryDark),
                      decoration: InputDecoration(
                          hintText: "event_name_hint".tr(),
                          border: InputBorder.none,
                          icon: Icon(Icons.edit_rounded,
                              size: 16, color: _softGrey),
                          hintStyle: TextStyle(color: _softGrey))))),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
          color: _surfaceWhite,
          border: Border(top: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
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
                  child: Icon(Icons.tune_rounded, color: _primaryDark))),
          const Spacer(),
          Material(
              color: Colors.transparent,
              child: InkWell(
                  onTap: _addNewQuestion,
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                          color: _bgLight,
                          borderRadius: BorderRadius.circular(30)),
                      child: Row(children: [
                        Icon(Icons.add_rounded, color: _primaryDark, size: 20),
                        const SizedBox(width: 8),
                        Text("Soru (${_questions.length}/$_maxQuestions)",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _primaryDark))
                      ])))),
          const Spacer(),
          GestureDetector(
            onTap: _isLoading ? null : _createEventAndNavigate,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.45),
                decoration: BoxDecoration(
                    color: _primaryDark,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: _primaryDark.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]),
                child: _isLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _loadingText,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          )
                        ],
                      )
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text("Oluştur",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18)
                      ])),
          ),
        ],
      ),
    );
  }

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
                      Text("Ayarlar",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _primaryDark)),
                      const SizedBox(height: 20),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text("create_nickname_required".tr(),
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _primaryDark)),
                          value: _isNicknameRequired,
                          activeColor: _primaryBlue,
                          onChanged: (val) {
                            setSheetState(() => _isNicknameRequired = val);
                            this.setState(() => _isNicknameRequired = val);
                          }),
                      Divider(color: _bgLight, thickness: 2),
                      const SizedBox(height: 10),
                      Text("create_timer_title".tr(),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _primaryDark)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 10, children: [
                        _buildDurationChip(
                            "30s", const Duration(seconds: 30), setSheetState),
                        _buildDurationChip(
                            "1m", const Duration(minutes: 1), setSheetState),
                        _buildDurationChip(
                            "2m", const Duration(minutes: 2), setSheetState),
                        _buildDurationChip("∞", Duration.zero, setSheetState)
                      ]),
                      const SizedBox(height: 20),
                    ]));
          });
        });
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
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
                child: PageView.builder(
                    controller: _pageController,
                    itemCount: _questions.length,
                    onPageChanged: (index) =>
                        setState(() => _activeIndex = index),
                    itemBuilder: (context, index) =>
                        _buildQuestionCard(index))),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                        _questions.length,
                        (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 6,
                            width: _activeIndex == index ? 24 : 6,
                            decoration: BoxDecoration(
                                color: _activeIndex == index
                                    ? _primaryDark
                                    : _softGrey.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(3)))))),
            Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: _buildBottomBar()),
          ],
        ),
      ),
    );
  }
}
