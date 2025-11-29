import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'thank_you_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class AnsweringScreen extends StatefulWidget {
  final String eventId;
  final String? nickname;

  const AnsweringScreen({
    super.key,
    required this.eventId,
    this.nickname,
  });

  @override
  State<AnsweringScreen> createState() => _AnsweringScreenState();
}

class _AnsweringScreenState extends State<AnsweringScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;

  String? _selectedAnswer;
  final TextEditingController _otherAnswerController = TextEditingController();
  static const String _otherOptionKey = '__OTHER_OPTION_SELECTED__';

  final List<Map<String, String>> _userAnswers = [];
  final PageController _mediaPageController = PageController();
  int _currentMediaIndex = 0;
  String? _deviceId;

  final Color _primaryColor = const Color(0xFF1A202C);
  final Color _bgColor = const Color(0xFFF8FAFC);
  final Color _surfaceColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchEventData();
  }

  @override
  void dispose() {
    _mediaPageController.dispose();
    _otherAnswerController.dispose();
    super.dispose();
  }

  Future<void> _fetchEventData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString('device_unique_id');

      if (_deviceId == null) {
        _deviceId = const Uuid().v4();
        await prefs.setString('device_unique_id', _deviceId!);
      }

      final docSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;

        final Timestamp? startTs = data['startTime'];
        final Timestamp? endTs = data['endTime'];

        if (startTs != null && endTs != null) {
          final DateTime now = DateTime.now();
          final DateTime start = startTs.toDate();
          final DateTime end = endTs.toDate();

          // TARİH FORMATI GÜNCELLEMESİ (Dil desteği eklendi)
          final DateFormat formatter =
              DateFormat('dd MMM HH:mm', context.locale.toString());

          if (now.isBefore(start)) {
            setState(() {
              _errorMessage = "answer_event_not_started"
                  .tr(namedArgs: {'date': formatter.format(start)});
              _isLoading = false;
            });
            return;
          }

          if (now.isAfter(end)) {
            setState(() {
              _errorMessage = "answer_event_ended"
                  .tr(namedArgs: {'date': formatter.format(end)});
              _isLoading = false;
            });
            return;
          }
        }

        final List<dynamic> votedDevices = data['votedDevices'] ?? [];
        if (votedDevices.contains(_deviceId)) {
          setState(() {
            _errorMessage = "answer_already_voted".tr();
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _questions = data['questions'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "answer_error_not_found".tr();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "answer_error_fetch".tr();
        _isLoading = false;
      });
    }
  }

  void _submitAndGoToNext() async {
    String finalAnswer = _selectedAnswer == _otherOptionKey
        ? _otherAnswerController.text.trim()
        : _selectedAnswer!;

    if (finalAnswer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("answer_enter_answer".tr())),
      );
      return;
    }

    _userAnswers.add({
      'question': _questions[_currentQuestionIndex]['questionText'],
      'answer': finalAnswer,
    });

    if (_currentQuestionIndex >= _questions.length - 1) {
      setState(() => _isLoading = true);

      try {
        final String respondentName = widget.nickname?.trim() ??
            'Anonim_${DateTime.now().millisecondsSinceEpoch}';

        final eventRef =
            FirebaseFirestore.instance.collection('events').doc(widget.eventId);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentSnapshot snapshot = await transaction.get(eventRef);
          if (!snapshot.exists) throw Exception("Event not found");

          final data = snapshot.data() as Map<String, dynamic>;
          final List<dynamic> votedDevices = data['votedDevices'] ?? [];

          if (votedDevices.contains(_deviceId)) {
            throw Exception("Already voted");
          }

          transaction.update(eventRef, {
            'results.$respondentName': _userAnswers,
            'votedDevices': FieldValue.arrayUnion([_deviceId])
          });
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ThankYouScreen()),
          );
        }
      } catch (e) {
        if (mounted) {
          String errorMsg = "answer_error_submit".tr();

          if (e.toString().contains("Already voted")) {
            errorMsg = "answer_already_voted".tr();
          }

          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(errorMsg)));

          if (e.toString().contains("Already voted")) {
            setState(() {
              _errorMessage = "answer_already_voted".tr();
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
          }
        }
      }
    } else {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _otherAnswerController.clear();
        _currentMediaIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = !_isLoading && _questions.isNotEmpty
        ? _questions[_currentQuestionIndex]
        : null;

    final List<dynamic> rawAttachments = currentQuestion != null
        ? (currentQuestion['attachments'] as List<dynamic>? ?? [])
        : [];

    final bool allowOpenEnded = currentQuestion != null
        ? (currentQuestion['allowOpenEnded'] ?? false)
        : false;

    List<dynamic> options = [];
    if (currentQuestion != null && currentQuestion['options'] != null) {
      options = List.from(currentQuestion['options']);
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        iconTheme: IconThemeData(color: _primaryColor),
        title: _isLoading
            ? null
            : Text(
                "${"answer_title_prefix".tr()} ${_currentQuestionIndex + 1}/${_questions.length}",
                style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 60, color: Colors.orangeAccent),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          currentQuestion?['questionText'] ?? "",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (rawAttachments.isNotEmpty) ...[
                        SizedBox(
                          height: 250,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: PageView.builder(
                              controller: _mediaPageController,
                              itemCount: rawAttachments.length,
                              onPageChanged: (idx) =>
                                  setState(() => _currentMediaIndex = idx),
                              itemBuilder: (context, idx) {
                                final attachment = rawAttachments[idx];
                                final path =
                                    attachment['path']?.toString() ?? '';
                                if (attachment['type'] == 'image') {
                                  return Image.network(path,
                                      fit: BoxFit.contain);
                                } else {
                                  return const Center(
                                      child: Icon(Icons.insert_drive_file,
                                          size: 50));
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              ...options.map((option) {
                                final bool isSelected =
                                    _selectedAnswer == option;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: InkWell(
                                    onTap: () => setState(
                                        () => _selectedAnswer = option),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 18, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _primaryColor
                                            : _surfaceColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: isSelected
                                                ? _primaryColor
                                                : Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        option,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : _primaryColor),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              if (allowOpenEnded)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Column(
                                    children: [
                                      InkWell(
                                        onTap: () => setState(() =>
                                            _selectedAnswer = _otherOptionKey),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 18, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: _selectedAnswer ==
                                                    _otherOptionKey
                                                ? _surfaceColor
                                                : _surfaceColor,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: _selectedAnswer ==
                                                        _otherOptionKey
                                                    ? _primaryColor
                                                    : Colors.grey.shade300,
                                                width: _selectedAnswer ==
                                                        _otherOptionKey
                                                    ? 2
                                                    : 1),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.edit_note_rounded,
                                                  color: _selectedAnswer ==
                                                          _otherOptionKey
                                                      ? _primaryColor
                                                      : Colors.grey),
                                              const SizedBox(width: 8),
                                              Text(
                                                "answer_other_label".tr(),
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: _selectedAnswer ==
                                                            _otherOptionKey
                                                        ? _primaryColor
                                                        : Colors.grey.shade700),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (_selectedAnswer == _otherOptionKey)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 10.0),
                                          child: TextField(
                                            controller: _otherAnswerController,
                                            autofocus: true,
                                            maxLength: 20,
                                            decoration: InputDecoration(
                                              hintText:
                                                  "answer_other_hint".tr(),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  borderSide: BorderSide(
                                                      color: _primaryColor)),
                                              focusedBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  borderSide: BorderSide(
                                                      color: _primaryColor,
                                                      width: 2)),
                                            ),
                                          ),
                                        )
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SafeArea(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: _selectedAnswer == null
                              ? null
                              : _submitAndGoToNext,
                          child: Text(
                            _currentQuestionIndex < _questions.length - 1
                                ? "answer_next_button".tr()
                                : "answer_finish_button".tr(),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
    );
  }
}
