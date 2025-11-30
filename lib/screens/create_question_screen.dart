import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'qr_result_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path_utils;
import 'package:flutter_screenutil/flutter_screenutil.dart'; // <-- EKLENDİ
// Diğer importların altına ekleyin:
import 'my_events_screen.dart';

// --- MODEL ---
class QuestionModel {
  String questionText;
  List<String> options;
  TextEditingController textController;
  List<TextEditingController> optionControllers;
  List<Map<String, String>> attachments;
  bool allowOpenEnded;

  QuestionModel({
    this.questionText = '',
    required this.options,
    List<Map<String, String>>? attachments,
    this.allowOpenEnded = false,
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
  // --- LİMİT KONTROL FONKSİYONU ---

  // Hata Diyaloğu Gösteren Yardımcı Fonksiyon
  void _showLimitDialog(String message, {required bool showGoToEvents}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // Material 3 renk tonunu kaldırır
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Üst İkon (Hafif Kırmızı Arkaplanlı)
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.report_gmailerrorred_rounded, // Uyarı ikonu
                  color: Colors.red.shade400,
                  size: 36.sp,
                ),
              ),
              SizedBox(height: 20.h),

              // 2. Başlık
              Text(
                "limit_error_title".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: _primaryDark,
                ),
              ),
              SizedBox(height: 12.h),

              // 3. Mesaj İçeriği
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey.shade600,
                  height: 1.5, // Satır arası boşluk okunabilirliği artırır
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 28.h),

              // 4. Butonlar
              Row(
                children: [
                  // İPTAL BUTONU (Her zaman görünür)
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        backgroundColor: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Text(
                        "cancel".tr(),
                        style: TextStyle(
                          color: _primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),

                  // ETKİNLİKLERE GİT BUTONU (Sadece hafıza doluyken görünür)
                  if (showGoToEvents) ...[
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Diyaloğu kapat
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const MyEventsScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryDark,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          shadowColor: _primaryDark.withOpacity(0.3),
                        ),
                        child: Text(
                          "go_to_events".tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- LİMİTLER ---
  static const int _maxQuestions = 10;
  static const int _maxOptions = 10;
  static const int _maxAttachments = 3;

  late List<QuestionModel> _questions;
  late TextEditingController _eventTitleController;
  late PageController _pageController;

  int _activeIndex = 0;

  // --- TARİH VE SAAT DEĞİŞKENLERİ ---
  DateTime _startDate = DateTime.now();
  DateTime _endDate =
      DateTime.now().add(const Duration(hours: 1)); // Varsayılan 1 saat sonra

  bool _isNicknameRequired = true;
  bool _isLoading = false;

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
      QuestionModel(options: ['', '']) // Başlangıçta 2 boş seçenek
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

  // --- YARDIMCI: TARİH SEÇİCİ ---
  Future<void> _pickDateTime(bool isStart) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: _primaryDark),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _startDate : _endDate),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(primary: _primaryDark),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          final newDateTime =
              DateTime(date.year, date.month, date.day, time.hour, time.minute);

          if (isStart) {
            _startDate = newDateTime;
            if (_startDate.isAfter(_endDate)) {
              _endDate = _startDate.add(const Duration(hours: 1));
            }
          } else {
            if (newDateTime.isAfter(_startDate)) {
              _endDate = newDateTime;
            } else {
              _showWarning("create_date_error".tr());
            }
          }
        });
      }
    }
  }

  // --- MEDYA İŞLEMLERİ ---
  Future<void> _pickImage(int index, ImageSource source) async {
    if (_questions[index].attachments.length >= _maxAttachments) {
      _showWarning(
          "create_max_image".tr(namedArgs: {'limit': '$_maxAttachments'}));
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

  void _removeAttachment(int questionIndex, int attachmentIndex) {
    setState(() {
      _questions[questionIndex].attachments.removeAt(attachmentIndex);
    });
  }

  void _showAttachmentOptions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceWhite,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              // KAMERA
              ListTile(
                  leading: Icon(Icons.camera_alt_rounded,
                      color: _primaryDark, size: 24.sp),
                  title: Text('create_media_take_photo'.tr(),
                      style: TextStyle(color: _primaryDark, fontSize: 16.sp)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(index, ImageSource.camera);
                  }),

              // GALERİ
              ListTile(
                  leading: Icon(Icons.photo_library_rounded,
                      color: _primaryDark, size: 24.sp),
                  title: Text('create_media_gallery'.tr(),
                      style: TextStyle(color: _primaryDark, fontSize: 16.sp)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(index, ImageSource.gallery);
                  }),

              // (BURADAKİ "DOSYA EKLE" LISTTILE'INI SİLDİK)
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
    if (_questions.length >= _maxQuestions) {
      _showWarning(
          "create_max_questions".tr(namedArgs: {'limit': '$_maxQuestions'}));
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

  Future<bool> _checkCreationLimits() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // 1. Toplam Limit Kontrolü (Max 15)
    final allEventsQuery = await FirebaseFirestore.instance
        .collection('events')
        .where('creatorId', isEqualTo: user.uid)
        .get(); // count() fonksiyonu varsa onu kullanmak daha performanslıdır

    if (allEventsQuery.docs.length >= 15) {
      if (mounted) {
        _showLimitDialog(
          "limit_storage_full".tr(),
          showGoToEvents: true, // Silme ekranına yönlendirme butonu
        );
      }
      return false; // İşlemi durdur
    }

    // 2. Günlük Limit Kontrolü (Max 10)
    final now = DateTime.now();
    // Bugünün başlangıcı (Saat 00:00:00)
    final startOfDay = DateTime(now.year, now.month, now.day);

    final dailyEventsQuery = await FirebaseFirestore.instance
        .collection('events')
        .where('creatorId', isEqualTo: user.uid)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    if (dailyEventsQuery.docs.length >= 10) {
      if (mounted) {
        _showLimitDialog(
          "limit_daily_reached".tr(),
          showGoToEvents: false,
        );
      }
      return false; // İşlemi durdur
    }

    return true; // Limitler aşılmadı, devam et
  }

  Future<void> _createEventAndNavigate() async {
    bool canCreate = await _checkCreationLimits();
    if (!canCreate) return;
    _syncData();
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
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
            if (mounted)
              _showWarning("Yükleme hatası (Q${i + 1}): ${e.toString()}");
          }
        }

        processedQuestions.add({
          'questionText': q.questionText,
          'options': q.options,
          'attachments': uploadedAttachments,
          'allowOpenEnded': q.allowOpenEnded,
        });
      }

      final eventData = {
        'createdAt': Timestamp.now(),
        'creatorId': user?.uid, // Giriş yapmışsa ID, yoksa null (Misafir)
        'eventTitle': _eventTitleController.text.trim().isNotEmpty
            ? _eventTitleController.text.trim()
            : 'events_prefix'.tr(),
        'startTime': Timestamp.fromDate(_startDate),
        'endTime': Timestamp.fromDate(_endDate),
        'isNicknameRequired': _isNicknameRequired,
        'questions': processedQuestions,
        'results': {},
      };

      final docRef =
          await FirebaseFirestore.instance.collection('events').add(eventData);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => QRResultScreen(eventId: docRef.id)),
        );
      }
    } catch (e) {
      if (mounted) _showWarning("create_error".tr() + e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(message, style: TextStyle(fontSize: 14.sp)), // .sp EKLENDİ
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.r), // .r EKLENDİ
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r)))); // .r EKLENDİ
  }

  // --- UI PARÇALARI ---
  Widget _buildQuestionCard(int index) {
    final question = _questions[index];
    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: 6.w, vertical: 12.h), // .w .h EKLENDİ
      decoration: BoxDecoration(
          color: _surfaceWhite,
          borderRadius: BorderRadius.circular(24.r), // .r EKLENDİ
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20.r, // .r EKLENDİ
                offset: Offset(0, 10.h)) // .h EKLENDİ
          ]),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 20.w, 0), // .w .h EKLENDİ
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 6.h), // .w .h EKLENDİ
                    decoration: BoxDecoration(
                        color: _bgLight,
                        borderRadius:
                            BorderRadius.circular(12.r)), // .r EKLENDİ
                    child: Text("Q${index + 1}",
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _primaryDark,
                            fontSize: 16.sp))), // .sp EKLENDİ
                if (_questions.length > 1)
                  IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: Colors.red.shade300,
                          size: 24.sp), // .sp EKLENDİ
                      onPressed: () => _removeQuestion(index))
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(24.r), // .r EKLENDİ
              children: [
                // SORU METNİ
                TextField(
                    maxLength: 200,
                    controller: question.textController,
                    maxLines: 3,
                    style: TextStyle(
                        fontSize: 18.sp,
                        color: _primaryDark,
                        height: 1.4), // .sp EKLENDİ
                    decoration: InputDecoration(
                        hintText: "create_question_hint".tr(),
                        hintStyle: TextStyle(
                            color: _softGrey.withOpacity(0.5),
                            fontSize: 18.sp), // .sp EKLENDİ
                        border: InputBorder.none,
                        filled: true,
                        fillColor: _bgLight,
                        contentPadding: EdgeInsets.all(16.r), // .r EKLENDİ
                        enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(16.r), // .r EKLENDİ
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(16.r), // .r EKLENDİ
                            borderSide: BorderSide(
                                color: _primaryDark.withOpacity(0.9))))),
                SizedBox(height: 16.h), // .h EKLENDİ

                // MEDYA LİSTESİ
                if (question.attachments.isNotEmpty)
                  SizedBox(
                    height: 100.h, // .h EKLENDİ
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: question.attachments.length,
                      itemBuilder: (context, attachIndex) {
                        final attachment = question.attachments[attachIndex];
                        return Stack(
                          children: [
                            Container(
                              width: 100.w, // .w EKLENDİ
                              margin:
                                  EdgeInsets.only(right: 12.w), // .w EKLENDİ
                              decoration: BoxDecoration(
                                color: _bgLight,
                                borderRadius:
                                    BorderRadius.circular(12.r), // .r EKLENDİ
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
                                          color: _primaryDark,
                                          size: 32.sp)) // .sp EKLENDİ
                                  : null,
                            ),
                            Positioned(
                              top: 4.h, // .h EKLENDİ
                              right: 16.w, // .w EKLENDİ
                              child: GestureDetector(
                                onTap: () =>
                                    _removeAttachment(index, attachIndex),
                                child: Container(
                                  padding: EdgeInsets.all(4.r), // .r EKLENDİ
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            blurRadius: 2,
                                            color: Colors.black12)
                                      ]),
                                  child: Icon(Icons.delete_outline_rounded,
                                      size: 20.sp,
                                      color: Colors.red), // .sp EKLENDİ
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
                  borderRadius: BorderRadius.circular(12.r), // .r EKLENDİ
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        vertical: 12.h, horizontal: 16.w), // .h .w EKLENDİ
                    decoration: BoxDecoration(
                        color: _bgLight,
                        borderRadius: BorderRadius.circular(12.r), // .r EKLENDİ
                        border: Border.all(
                            color: _primaryDark.withOpacity(0.2),
                            style: BorderStyle.solid)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: _primaryDark, size: 20.sp), // .sp EKLENDİ
                          SizedBox(width: 8.w), // .w EKLENDİ
                          Text(
                              question.attachments.length >= _maxAttachments
                                  ? "create_media_limit".tr()
                                  : "create_media_add".tr(),
                              style: TextStyle(
                                  color: _primaryDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp)) // .sp EKLENDİ
                        ]),
                  ),
                ),
                SizedBox(height: 24.h), // .h EKLENDİ

                // --- SEÇENEKLER ---
                Text("create_options_title".tr(),
                    style: TextStyle(
                        color: _softGrey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp, // .sp EKLENDİ
                        letterSpacing: 1)),
                SizedBox(height: 12.h), // .h EKLENDİ
                ...List.generate(question.optionControllers.length, (optIndex) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h), // .h EKLENDİ
                    child: Row(
                      children: [
                        Container(
                            width: 8.w, // .w EKLENDİ
                            height: 8.w, // .w EKLENDİ
                            decoration: BoxDecoration(
                                color: _primaryDark.withOpacity(0.3),
                                shape: BoxShape.circle)),
                        SizedBox(width: 12.w), // .w EKLENDİ
                        Expanded(
                            child: TextField(
                                controller:
                                    question.optionControllers[optIndex],
                                style: TextStyle(
                                    color: _primaryDark,
                                    fontSize: 16.sp), // .sp EKLENDİ
                                decoration: InputDecoration(
                                    hintText: "create_option_hint".tr(),
                                    hintStyle: TextStyle(
                                        color: _softGrey.withOpacity(0.5),
                                        fontSize: 16.sp), // .sp EKLENDİ
                                    border: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade200)),
                                    enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade200)),
                                    focusedBorder: UnderlineInputBorder(
                                        borderSide:
                                            BorderSide(color: _primaryDark))))),

                        // SEÇENEK SİLME BUTONU
                        if (question.optionControllers.length > 2)
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 22.sp), // .sp EKLENDİ
                            onPressed: () {
                              setState(() {
                                question.options.removeAt(optIndex);
                                question.optionControllers[optIndex].dispose();
                                question.optionControllers.removeAt(optIndex);
                              });
                            },
                          ),
                      ],
                    ),
                  );
                }),
                SizedBox(height: 8.h), // .h EKLENDİ

                // --- SEÇENEK EKLE VE SAYAÇ ---
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: () {
                          if (question.options.length >= _maxOptions) {
                            _showWarning("create_max_options"
                                .tr(namedArgs: {'limit': '$_maxOptions'}));
                            return;
                          }
                          setState(() {
                            question.options.add('');
                            question.optionControllers
                                .add(TextEditingController());
                          });
                        },
                        icon:
                            Icon(Icons.add_rounded, size: 18.sp), // .sp EKLENDİ
                        label: Text(
                            "${"create_add_option".tr()} (${question.options.length}/$_maxOptions)", // SAYAÇ EKLENDİ
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp)), // .sp EKLENDİ
                        style: TextButton.styleFrom(
                            foregroundColor: _primaryDark,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h)))), // .w .h EKLENDİ

                // Açık Uçlu Seçenek
                SizedBox(height: 16.h), // .h EKLENDİ
                Divider(
                    color: Colors.grey.shade100, height: 24.h), // .h EKLENDİ
                // ...
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,

                  // --- AKTİF (AÇIK) RENKLER ---
                  activeColor: _primaryDark, // Top rengi (Koyu Lacivert)
                  activeTrackColor: _primaryDark
                      .withOpacity(0.3), // Arkadaki iz (Soluk Lacivert)

                  // --- PASİF (KAPALI) RENKLER ---
                  inactiveThumbColor:
                      _softGrey, // Top rengi (Sizin tanımladığınız gri)
                  inactiveTrackColor:
                      Colors.grey.shade200, // Arkadaki iz (Çok açık gri)

                  // İsteğe bağlı: Kenar çizgisini kaldırmak daha "flat" bir görüntü verir
                  trackOutlineColor:
                      MaterialStateProperty.all(Colors.transparent),

                  title: Text("create_other_option".tr(),
                      style: TextStyle(
                          color: _primaryDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp)), // .sp EKLENDİ
                  subtitle: Text("create_other_desc".tr(),
                      style: TextStyle(
                          color: _softGrey, fontSize: 12.sp)), // .sp EKLENDİ
                  value: question.allowOpenEnded,
                  onChanged: (val) {
                    setState(() {
                      question.allowOpenEnded = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 10.h), // .w .h EKLENDİ
      child: Row(
        children: [
          GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                  padding: EdgeInsets.all(10.r), // .r EKLENDİ
                  decoration: BoxDecoration(
                      color: _surfaceWhite,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10.r) // .r EKLENDİ
                      ]),
                  child: Icon(Icons.close_rounded,
                      color: _primaryDark, size: 20.sp))), // .sp EKLENDİ
          SizedBox(width: 16.w), // .w EKLENDİ
          Expanded(
              child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 4.h), // .w .h EKLENDİ
                  decoration: BoxDecoration(
                      color: _surfaceWhite,
                      borderRadius: BorderRadius.circular(30.r), // .r EKLENDİ
                      border: Border.all(color: Colors.grey.shade200)),
                  child: TextField(
                      controller: _eventTitleController,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _primaryDark,
                          fontSize: 16.sp), // .sp EKLENDİ
                      decoration: InputDecoration(
                          hintText: "event_name_hint".tr(),
                          border: InputBorder.none,
                          icon: Icon(Icons.edit_rounded,
                              size: 16.sp, color: _softGrey), // .sp EKLENDİ
                          hintStyle: TextStyle(
                              color: _softGrey,
                              fontSize: 16.sp))))), // .sp EKLENDİ
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h), // .w .h EKLENDİ
      decoration: BoxDecoration(
          color: _surfaceWhite,
          border: Border(top: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          InkWell(
              onTap: _showSettingsSheet,
              borderRadius: BorderRadius.circular(12.r), // .r EKLENDİ
              child: Container(
                  padding: EdgeInsets.all(12.r), // .r EKLENDİ
                  decoration: BoxDecoration(
                      color: _bgLight,
                      borderRadius: BorderRadius.circular(12.r), // .r EKLENDİ
                      border: Border.all(
                          color: _isNicknameRequired
                              ? _primaryDark
                              : Colors.transparent,
                          width: 2.w)), // .w EKLENDİ
                  child: Icon(Icons.tune_rounded,
                      color: _primaryDark, size: 24.sp))), // .sp EKLENDİ
          const Spacer(),
          Material(
              color: Colors.transparent,
              child: InkWell(
                  onTap: _addNewQuestion,
                  borderRadius: BorderRadius.circular(50.r), // .r EKLENDİ
                  child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 20.w, vertical: 12.h), // .w .h EKLENDİ
                      decoration: BoxDecoration(
                          color: _bgLight,
                          borderRadius:
                              BorderRadius.circular(30.r)), // .r EKLENDİ
                      child: Row(children: [
                        Icon(Icons.add_rounded,
                            color: _primaryDark, size: 20.sp), // .sp EKLENDİ
                        SizedBox(width: 8.w), // .w EKLENDİ
                        Text(
                            "${'create_question_tab_prefix'.tr()}${_questions.length}/$_maxQuestions",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _primaryDark,
                                fontSize: 14.sp)) // .sp EKLENDİ
                      ])))),
          const Spacer(),
          GestureDetector(
            onTap: _isLoading ? null : _createEventAndNavigate,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(
                    horizontal: 24.w, vertical: 14.h), // .w .h EKLENDİ
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.45),
                decoration: BoxDecoration(
                    color: _primaryDark,
                    borderRadius: BorderRadius.circular(14.r), // .r EKLENDİ
                    boxShadow: [
                      BoxShadow(
                          color: _primaryDark.withOpacity(0.3),
                          blurRadius: 12.r, // .r EKLENDİ
                          offset: Offset(0, 4.h)) // .h EKLENDİ
                    ]),
                child: _isLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            SizedBox(
                                width: 16.w, // .w EKLENDİ
                                height: 16.w, // .w EKLENDİ
                                child: const CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 10.w), // .w EKLENDİ
                            Flexible(
                                child: Text("create_creating".tr(),
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.sp, // .sp EKLENDİ
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis))
                          ])
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        Text("create_btn_create".tr(),
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp)), // .sp EKLENDİ
                        SizedBox(width: 8.w), // .w EKLENDİ
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18.sp) // .sp EKLENDİ
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
      isScrollControlled: true, // İçeriğe göre esnemesini sağlar
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24.r)), // .r EKLENDİ
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final dateFormat =
                DateFormat('dd MMM yyyy, HH:mm', context.locale.toString());

            // --- YARDIMCI: Modern Tarih Kartı Tasarımı ---
            Widget buildDateCard(String label, DateTime date, bool isStart) {
              return InkWell(
                onTap: () async {
                  await _pickDateTime(isStart);
                  setSheetState(() {});
                },
                borderRadius: BorderRadius.circular(16.r), // .r EKLENDİ
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 16.h), // .w .h EKLENDİ
                  decoration: BoxDecoration(
                    color: _bgLight,
                    borderRadius: BorderRadius.circular(16.r), // .r EKLENDİ
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      // Modern İkon Kutusu
                      Container(
                        padding: EdgeInsets.all(10.r), // .r EKLENDİ
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4.r, // .r EKLENDİ
                              offset: Offset(0, 2.h), // .h EKLENDİ
                            )
                          ],
                        ),
                        child: Icon(
                          isStart
                              ? Icons.calendar_today_rounded
                              : Icons.event_available_rounded,
                          color: _primaryDark, // Artık renkli değil, tutarlı
                          size: 20.sp, // .sp EKLENDİ
                        ),
                      ),
                      SizedBox(width: 16.w), // .w EKLENDİ
                      // Tarih Metinleri
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: TextStyle(
                                    color: _softGrey,
                                    fontSize: 12.sp, // .sp EKLENDİ
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: 4.h), // .h EKLENDİ
                            Text(
                              dateFormat.format(date),
                              style: TextStyle(
                                color: _primaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp, // .sp EKLENDİ
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Yönlendirme Oku
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 14.sp,
                          color: _softGrey.withOpacity(0.5)), // .sp EKLENDİ
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    24.h, // .h EKLENDİ
                top: 12.h, // .h EKLENDİ
                left: 24.w, // .w EKLENDİ
                right: 24.w, // .w EKLENDİ
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. MODERN DRAG HANDLE (TUTMA ÇUBUĞU) ---
                  Center(
                    child: Container(
                      width: 40.w, // .w EKLENDİ
                      height: 4.h, // .h EKLENDİ
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.r), // .r EKLENDİ
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h), // .h EKLENDİ

                  // Başlık
                  Row(
                    children: [
                      Icon(Icons.tune_rounded,
                          color: _primaryDark, size: 24.sp), // .sp EKLENDİ
                      SizedBox(width: 12.w), // .w EKLENDİ
                      Text("create_settings".tr(),
                          style: TextStyle(
                              fontSize: 20.sp, // .sp EKLENDİ
                              fontWeight: FontWeight.bold,
                              color: _primaryDark)),
                    ],
                  ),
                  SizedBox(height: 24.h), // .h EKLENDİ

                  // --- 2. SWITCH (DİĞERİYLE AYNI STİL) ---
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 4.h), // .h EKLENDİ
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r), // .r EKLENDİ
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: SwitchListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16.w), // .w EKLENDİ

                      // --- RENK UYUMU BURADA SAĞLANDI ---
                      activeColor: _primaryDark,
                      activeTrackColor: _primaryDark.withOpacity(0.3),
                      inactiveThumbColor: _softGrey,
                      inactiveTrackColor: Colors.grey.shade200,
                      trackOutlineColor:
                          MaterialStateProperty.all(Colors.transparent),
                      // ----------------------------------

                      title: Text("create_nickname_required".tr(),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _primaryDark,
                              fontSize: 15.sp)), // .sp EKLENDİ
                      // İsteğe bağlı açıklama ekleyebilirsiniz, boş durmasın diye ekledim
                      subtitle: Padding(
                        padding: EdgeInsets.only(top: 2.0.h), // .h EKLENDİ
                        child: Text(
                          "Katılımcılar isim girmek zorunda", // İsterseniz .tr() ekleyin
                          style: TextStyle(
                              color: _softGrey, fontSize: 12.sp), // .sp EKLENDİ
                        ),
                      ),
                      value: _isNicknameRequired,
                      onChanged: (val) {
                        setSheetState(() => _isNicknameRequired = val);
                        this.setState(() => _isNicknameRequired = val);
                      },
                    ),
                  ),

                  SizedBox(height: 24.h), // .h EKLENDİ

                  // --- 3. MODERN TARİH ALANI ---
                  Text("create_event_time".tr(),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _primaryDark,
                          fontSize: 14.sp)), // .sp EKLENDİ
                  SizedBox(height: 12.h), // .h EKLENDİ

                  // Başlangıç Kartı
                  buildDateCard("create_start".tr(), _startDate, true),
                  SizedBox(height: 12.h), // .h EKLENDİ
                  // Bitiş Kartı
                  buildDateCard("create_end".tr(), _endDate, false),

                  SizedBox(height: 16.h), // .h EKLENDİ
                ],
              ),
            );
          },
        );
      },
    );
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
                padding: EdgeInsets.symmetric(vertical: 10.h), // .h EKLENDİ
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                        _questions.length,
                        (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: EdgeInsets.symmetric(
                                horizontal: 3.w), // .w EKLENDİ
                            height: 6.h, // .h EKLENDİ
                            width: _activeIndex == index
                                ? 24.w
                                : 6.w, // .w EKLENDİ
                            decoration: BoxDecoration(
                                color: _activeIndex == index
                                    ? _primaryDark
                                    : _softGrey.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(
                                    3.r)))))), // .r EKLENDİ
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
