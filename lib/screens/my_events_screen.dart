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
  List<DocumentSnapshot> _allEvents = [];
  List<DocumentSnapshot> _filteredEvents = [];
  List<String> _favoriteEventIds = [];
  bool _isLoading = true;

  // Filtreleme Seçenekleri
  bool _showOnlyFavorites = false;
  bool _sortNewestFirst = true; // Varsayılan: Yeniden eskiye

  // --- TASARIM SABİTLERİ (mainTextColor hatasını çözmek için tekrar eklendi) ---
  final Color _mainTextColor = const Color(0xFF1A202C); // Koyu Gri/Siyah
  final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(15),
      blurRadius: 16,
      offset: const Offset(4, 7),
    ),
  ];
  // ----------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

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
        SnackBar(content: Text("event_deleted".tr())),
      );
    }
  }

  Future<void> _confirmAndDelete(String eventId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("are_you_sure".tr(),
              style: TextStyle(
                  color: _mainTextColor, fontWeight: FontWeight.bold)),
          content: Text("delete_confirm_text".tr()),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("cancel".tr(),
                  style: const TextStyle(color: Colors.grey)),
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

  // --- GÜNCELLENMİŞ FİLTRE DİYALOĞU ---
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
                        color: _mainTextColor)),
                const SizedBox(height: 10),
                const Divider(),

                // FAVORİ FİLTRESİ
                SwitchListTile(
                  activeColor: const Color(0xFF3182CE), // Ana mavi tonu
                  title: Text("only_favorites".tr(),
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: _mainTextColor)),
                  secondary: const Icon(Icons.star, color: Colors.amber),
                  value: _showOnlyFavorites,
                  onChanged: (val) {
                    setModalState(() => _showOnlyFavorites = val);
                    setState(() => _applyFilters());
                  },
                ),
                const SizedBox(height: 8),

                // SIRALAMA FİLTRESİ
                ListTile(
                  title: Text("sort_label".tr(),
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: _mainTextColor)),
                  leading: Icon(
                      _sortNewestFirst
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: _mainTextColor),
                  trailing: DropdownButton<bool>(
                    value: _sortNewestFirst,
                    underline: Container(),
                    icon:
                        Icon(Icons.keyboard_arrow_down, color: _mainTextColor),
                    style: TextStyle(
                        color: _mainTextColor, fontWeight: FontWeight.bold),
                    items: [
                      DropdownMenuItem(
                          value: true,
                          child: Text("sort_newest".tr(),
                              style: TextStyle(color: _mainTextColor))),
                      DropdownMenuItem(
                          value: false,
                          child: Text("sort_oldest".tr(),
                              style: TextStyle(color: _mainTextColor))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _sortNewestFirst = val);
                        setState(() => _applyFilters());
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Gradient'in yukarı kadar çıkması için
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _mainTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("events_title".tr(),
            style:
                TextStyle(color: _mainTextColor, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: _mainTextColor),
            onPressed: _showFilterDialog,
            tooltip: "filter_sort_title".tr(),
          )
        ],
      ),
      body: Container(
        // --- GRADIENT ARKA PLAN ---
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredEvents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                shape: BoxShape.circle),
                            child: Icon(Icons.event_busy,
                                size: 64,
                                color: _mainTextColor.withOpacity(0.5)),
                          ),
                          const SizedBox(height: 16),
                          Text("events_no_events".tr(),
                              style: TextStyle(
                                  color: _mainTextColor,
                                  fontWeight: FontWeight.w600)),
                          if (_showOnlyFavorites)
                            Text("no_favorites_hint".tr(),
                                style: TextStyle(
                                    color: _mainTextColor.withOpacity(0.6),
                                    fontSize: 13)),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 10),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                  "${_filteredEvents.length} / 15 ${"event_limit_label".tr()}",
                                  style: TextStyle(
                                      color: _filteredEvents.length >= 15
                                          ? Colors.red
                                          : _mainTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _filteredEvents.length,
                            itemBuilder: (context, index) {
                              final eventDoc = _filteredEvents[index];
                              final eventData =
                                  eventDoc.data() as Map<String, dynamic>;
                              final eventId = eventDoc.id;
                              final Timestamp timestamp =
                                  eventData['createdAt'] ?? Timestamp.now();
                              final date = timestamp.toDate();
                              final bool isFavorite =
                                  _favoriteEventIds.contains(eventId);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: _cardShadow,
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.qr_code_2,
                                        color: Color(0xFF3182CE)),
                                  ),
                                  title: Text(
                                    // YENİ: Başlık varsa onu göster, yoksa numarayı göster
                                    eventData['eventTitle'] ??
                                        "${"events_prefix".tr()}${index + 1}",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _mainTextColor,
                                        fontSize: 16),
                                  ),
                                  // --- GÜNCELLENMİŞ ALT BAŞLIK (SUBTITLE) ---
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      "${date.day}/${date.month}/${date.year} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13),
                                    ),
                                  ),
                                  // ------------------------------------------
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isFavorite
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          color: isFavorite
                                              ? Colors.amber
                                              : Colors.grey[400],
                                          size: 28,
                                        ),
                                        onPressed: () =>
                                            _toggleFavorite(eventId),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline_rounded,
                                            color: Colors.red.shade400,
                                            size: 24),
                                        onPressed: () =>
                                            _confirmAndDelete(eventId),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            QRResultScreen(eventId: eventId),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
