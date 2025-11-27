import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'qr_result_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  // --- VERİ DEĞİŞKENLERİ ---
  List<DocumentSnapshot> _allEvents = [];
  List<DocumentSnapshot> _filteredEvents = [];
  List<String> _favoriteEventIds = [];
  bool _isLoading = true;

  // --- FİLTRE DEĞİŞKENLERİ ---
  bool _showOnlyFavorites = false;
  bool _sortNewestFirst = true;

  // --- MODERN TASARIM SABİTLERİ (QR RESULT İLE AYNI) ---
  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _primaryColor = const Color(0xFF2D3748);
  final Color _secondaryColor = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- VERİ YÜKLEME ---
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final List<String> eventIds = prefs.getStringList('saved_events') ?? [];
    _favoriteEventIds = prefs.getStringList('favorite_events') ?? [];

    if (eventIds.isEmpty) {
      setState(() {
        _allEvents = [];
        _filteredEvents = [];
        _isLoading = false;
      });
      return;
    }

    final List<DocumentSnapshot> events = [];
    for (String id in eventIds) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('events').doc(id).get();
        if (doc.exists) {
          events.add(doc);
        }
      } catch (e) {
        debugPrint("Etkinlik yüklenemedi: $id");
      }
    }

    if (mounted) {
      setState(() {
        _allEvents = events;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  // --- FİLTRELEME MANTIĞI ---
  void _applyFilters() {
    List<DocumentSnapshot> tempEvents = List.from(_allEvents);

    if (_showOnlyFavorites) {
      tempEvents = tempEvents
          .where((doc) => _favoriteEventIds.contains(doc.id))
          .toList();
    }

    tempEvents.sort((a, b) {
      Timestamp timeA =
          (a.data() as Map<String, dynamic>)['createdAt'] ?? Timestamp(0, 0);
      Timestamp timeB =
          (b.data() as Map<String, dynamic>)['createdAt'] ?? Timestamp(0, 0);
      return _sortNewestFirst ? timeB.compareTo(timeA) : timeA.compareTo(timeB);
    });

    setState(() {
      _filteredEvents = tempEvents;
    });
  }

  // --- SİLME İŞLEMİ ---
  Future<void> _deleteEvent(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedEvents = prefs.getStringList('saved_events') ?? [];
    savedEvents.remove(eventId);
    await prefs.setStringList('saved_events', savedEvents);

    if (_favoriteEventIds.contains(eventId)) {
      _favoriteEventIds.remove(eventId);
      await prefs.setStringList('favorite_events', _favoriteEventIds);
    }

    setState(() {
      _allEvents.removeWhere((doc) => doc.id == eventId);
      _applyFilters();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("event_deleted".tr(),
              style: const TextStyle(color: Colors.white)),
          backgroundColor: _primaryColor,
        ),
      );
    }
  }

  Future<void> _confirmAndDelete(String eventId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("are_you_sure".tr(),
              style:
                  TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
          content: Text("delete_confirm_text".tr(),
              style: TextStyle(color: _secondaryColor)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child:
                  Text("cancel".tr(), style: TextStyle(color: _secondaryColor)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("delete".tr(),
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _deleteEvent(eventId);
    }
  }

  // --- FAVORİ İŞLEMİ ---
  Future<void> _toggleFavorite(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteEventIds.contains(eventId)) {
        _favoriteEventIds.remove(eventId);
      } else {
        _favoriteEventIds.add(eventId);
      }
      _applyFilters();
    });
    await prefs.setStringList('favorite_events', _favoriteEventIds);
  }

  // --- FİLTRE DİYALOĞU ---
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("filter_sort_title".tr(),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor)),
                const SizedBox(height: 10),
                Divider(color: _borderColor),

                // FAVORİ FİLTRESİ
                SwitchListTile(
                  activeColor: _primaryColor,
                  contentPadding: EdgeInsets.zero,
                  title: Text("only_favorites".tr(),
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: _primaryColor)),
                  secondary: const Icon(Icons.star_rounded,
                      color: Colors.amber, size: 28),
                  value: _showOnlyFavorites,
                  onChanged: (val) {
                    setModalState(() => _showOnlyFavorites = val);
                    setState(() => _applyFilters());
                  },
                ),
                const SizedBox(height: 8),

                // SIRALAMA FİLTRESİ
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("sort_label".tr(),
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: _primaryColor)),
                  leading: Icon(
                      _sortNewestFirst
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: _primaryColor),
                  trailing: DropdownButton<bool>(
                    value: _sortNewestFirst,
                    underline: Container(),
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: _primaryColor),
                    style: TextStyle(
                        color: _primaryColor, fontWeight: FontWeight.bold),
                    items: [
                      DropdownMenuItem(
                          value: true, child: Text("sort_newest".tr())),
                      DropdownMenuItem(
                          value: false, child: Text("sort_oldest".tr())),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _sortNewestFirst = val);
                        setState(() => _applyFilters());
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        });
      },
    );
  }

  // --- MODERN HEADER (QR Result Ekranındaki ile aynı stil) ---
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Geri Butonu
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
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: _primaryColor),
            ),
          ),

          // 2. Başlık
          Column(
            children: [
              Text(
                "HISTORY",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: _secondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "events_title".tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),

          // 3. Filtre Butonu (Sağda, Geri butonu ile aynı stilde)
          GestureDetector(
            onTap: _showFilterDialog,
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
              child: Icon(Icons.filter_list_rounded,
                  size: 20, color: _primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // --- ETKİNLİK KARTI ---
  Widget _buildEventCard(DocumentSnapshot eventDoc, int index) {
    final eventData = eventDoc.data() as Map<String, dynamic>;
    final eventId = eventDoc.id;
    final Timestamp timestamp = eventData['createdAt'] ?? Timestamp.now();
    final date = timestamp.toDate();
    final bool isFavorite = _favoriteEventIds.contains(eventId);
    final String title =
        eventData['eventTitle'] ?? "${"events_prefix".tr()}${index + 1}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => QRResultScreen(eventId: eventId)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // İkon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2F7), // Hafif gri arka plan
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.qr_code_2_rounded,
                      color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 16),

                // Metinler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _primaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${date.day}/${date.month}/${date.year} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(
                          color: _secondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Aksiyonlar (Favori & Sil)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isFavorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: isFavorite
                            ? Colors.amber
                            : _secondaryColor.withOpacity(0.5),
                        size: 24,
                      ),
                      onPressed: () => _toggleFavorite(eventId),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red.shade300,
                        size: 22,
                      ),
                      onPressed: () => _confirmAndDelete(eventId),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. MODERN HEADER
            _buildHeader(),

            // 2. İÇERİK
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_note_rounded,
                                  size: 64, color: _borderColor),
                              const SizedBox(height: 16),
                              Text("events_no_events".tr(),
                                  style: TextStyle(
                                      color: _secondaryColor,
                                      fontWeight: FontWeight.w600)),
                              if (_showOnlyFavorites)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text("no_favorites_hint".tr(),
                                      style: TextStyle(
                                          color:
                                              _secondaryColor.withOpacity(0.6),
                                          fontSize: 13)),
                                ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // LİMİT BİLGİSİ
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  "${_filteredEvents.length} / 15 ${"event_limit_label".tr()}",
                                  style: TextStyle(
                                    color: _filteredEvents.length >= 15
                                        ? Colors.red
                                        : _secondaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            // LİSTE
                            Expanded(
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: _filteredEvents.length,
                                itemBuilder: (context, index) {
                                  return _buildEventCard(
                                      _filteredEvents[index], index);
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
