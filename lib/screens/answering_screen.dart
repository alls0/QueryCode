import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final List<Map<String, String>> _userAnswers = [];

  final PageController _mediaPageController = PageController();
  int _currentMediaIndex = 0;

  // Tasarım Renkleri
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
    super.dispose();
  }

  Future<void> _fetchEventData() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();

      if (docSnapshot.exists) {
        setState(() {
          _questions = docSnapshot.data()?['questions'] ?? [];
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
    _userAnswers.add({
      'question': _questions[_currentQuestionIndex]['questionText'],
      'answer': _selectedAnswer!,
    });

    if (_currentQuestionIndex >= _questions.length - 1) {
      setState(() {
        _isLoading = true;
      });
      try {
        final String respondentName = widget.nickname?.trim() ??
            'Anonim_${DateTime.now().millisecondsSinceEpoch}';

        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .update({
          'results.$respondentName': _userAnswers,
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ThankYouScreen()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("answer_error_submit".tr())),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
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

    // Eski veri yapısı desteği
    if (rawAttachments.isEmpty &&
        currentQuestion != null &&
        currentQuestion['attachmentPath'] != null) {
      rawAttachments.add({
        'path': currentQuestion['attachmentPath'],
        'type': currentQuestion['attachmentType'] ?? 'image'
      });
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
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
                  child: Text(_errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 16)))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      // Soru Kartı
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          currentQuestion != null
                              ? (currentQuestion['questionText'] ??
                                  "answer_question_not_found".tr())
                              : "",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Medya Alanı
                      if (rawAttachments.isNotEmpty) ...[
                        Container(
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                PageView.builder(
                                  controller: _mediaPageController,
                                  itemCount: rawAttachments.length,
                                  onPageChanged: (idx) {
                                    setState(() => _currentMediaIndex = idx);
                                  },
                                  itemBuilder: (context, idx) {
                                    final attachment = rawAttachments[idx];
                                    final path =
                                        attachment['path']?.toString() ?? '';
                                    final type = attachment['type'];

                                    if (path.isEmpty)
                                      return _buildErrorWidget();

                                    final bool isNetworkUrl =
                                        path.startsWith('http');

                                    if (type == 'image') {
                                      if (isNetworkUrl) {
                                        return Image.network(path,
                                            fit: BoxFit.contain, loadingBuilder:
                                                (context, child,
                                                    loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                              child: CircularProgressIndicator(
                                                  color: _primaryColor,
                                                  value: loadingProgress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                      : null));
                                        }, errorBuilder:
                                                (context, error, stackTrace) {
                                          return _buildErrorWidget();
                                        });
                                      } else {
                                        return Image.file(
                                          File(path),
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  _buildErrorWidget(),
                                        );
                                      }
                                    } else {
                                      return Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                                Icons.insert_drive_file_rounded,
                                                size: 50,
                                                color: _primaryColor),
                                            const SizedBox(height: 12),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20),
                                              child: Text(
                                                path
                                                    .split('/')
                                                    .last
                                                    .split('?')
                                                    .first,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            )
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                ),
                                if (rawAttachments.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                          rawAttachments.length, (idx) {
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _currentMediaIndex == idx
                                                ? _primaryColor
                                                : Colors.grey.shade300,
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Seçenekler
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              if (currentQuestion != null &&
                                  currentQuestion['options'] != null)
                                ...((currentQuestion['options']
                                        as List<dynamic>)
                                    .map((option) {
                                  final bool isSelected =
                                      _selectedAnswer == option;
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12.0),
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
                                          borderRadius:
                                              BorderRadius.circular(16),
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
                                }).toList()),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // İleri Butonu
                      SafeArea(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
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

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text("Görsel yüklenemedi",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      ],
    );
  }
}
