import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'qr_result_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  // --- VERİ DEĞİŞKENLERİ ---
  // Tek bir liste yerine 3 ayrı liste tutuyoruz
  List<DocumentSnapshot> _ongoingEvents = [];
  List<DocumentSnapshot> _upcomingEvents = [];
  List<DocumentSnapshot> _endedEvents = [];

  List<String> _favoriteEventIds = [];
  bool _isLoading = true;

  // --- FİLTRE DEĞİŞKENLERİ ---
  bool _showOnlyFavorites = false;
  bool _sortNewestFirst = true;

  final Color _backgroundColor = const Color(0xFFF8FAFC);
  final Color _primaryColor = const Color(0xFF2D3748);
  final Color _secondaryColor = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- VERİ YÜKLEME VE KATEGORİZE ETME ---
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _favoriteEventIds = prefs.getStringList('favorite_events') ?? [];

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('creatorId', isEqualTo: user.uid)
          .get();

      if (mounted) {
        setState(() {
          List<DocumentSnapshot> allDocs = querySnapshot.docs;

          // 1. Favori Filtresi
          if (_showOnlyFavorites) {
            allDocs = allDocs
                .where((doc) => _favoriteEventIds.contains(doc.id))
                .toList();
          }

          // 2. Sıralama
          allDocs.sort((a, b) {
            Timestamp timeA = (a.data() as Map<String, dynamic>)['createdAt'] ??
                Timestamp(0, 0);
            Timestamp timeB = (b.data() as Map<String, dynamic>)['createdAt'] ??
                Timestamp(0, 0);
            return _sortNewestFirst
                ? timeB.compareTo(timeA)
                : timeA.compareTo(timeB);
          });

          // 3. Kategorize Etme (Devam Eden, Başlamayan, Biten)
          final now = DateTime.now();
          _ongoingEvents = [];
          _upcomingEvents = [];
          _endedEvents = [];

          for (var doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final Timestamp startTs = data['startTime'] ?? Timestamp.now();
            final Timestamp endTs = data['endTime'] ?? Timestamp.now();

            final DateTime startDate = startTs.toDate();
            final DateTime endDate = endTs.toDate();

            if (endDate.isBefore(now)) {
              // Bitiş tarihi şu andan önceyse -> BİTEN
              _endedEvents.add(doc);
            } else if (startDate.isAfter(now)) {
              // Başlangıç tarihi şu andan sonraysa -> BAŞLAMAYAN
              _upcomingEvents.add(doc);
            } else {
              // Şu an başlangıç ve bitiş arasındaysa -> DEVAM EDEN
              _ongoingEvents.add(doc);
            }
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Etkinlikler yüklenemedi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SİLME İŞLEMİ ---
  Future<void> _deleteEvent(String eventId) async {
    await FirebaseFirestore.instance.collection('events').doc(eventId).delete();

    final prefs = await SharedPreferences.getInstance();
    if (_favoriteEventIds.contains(eventId)) {
      _favoriteEventIds.remove(eventId);
      await prefs.setStringList('favorite_events', _favoriteEventIds);
    }

    _loadData();

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
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: Text("are_you_sure".tr(),
              style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp)),
          content: Text("delete_confirm_text".tr(),
              style: TextStyle(color: _secondaryColor, fontSize: 14.sp)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("cancel".tr(),
                  style: TextStyle(color: _secondaryColor, fontSize: 14.sp)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("delete".tr(),
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp)),
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
    });
    await prefs.setStringList('favorite_events', _favoriteEventIds);
    _loadData(); // Listeleri tekrar güncellemek için
  }

  // --- FİLTRE DİYALOĞU ---
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.all(24.0.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("filter_sort_title".tr(),
                    style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor)),
                SizedBox(height: 10.h),
                Divider(color: _borderColor),
                SwitchListTile(
                  activeColor: _primaryColor,
                  contentPadding: EdgeInsets.zero,
                  title: Text("only_favorites".tr(),
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                          fontSize: 16.sp)),
                  secondary: Icon(Icons.star_rounded,
                      color: Colors.amber, size: 28.sp),
                  value: _showOnlyFavorites,
                  onChanged: (val) {
                    setModalState(() => _showOnlyFavorites = val);
                    this.setState(() => _showOnlyFavorites = val);
                    _loadData();
                  },
                ),
                SizedBox(height: 8.h),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("sort_label".tr(),
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                          fontSize: 16.sp)),
                  leading: Icon(
                      _sortNewestFirst
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: _primaryColor,
                      size: 24.sp),
                  trailing: DropdownButton<bool>(
                    value: _sortNewestFirst,
                    underline: Container(),
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: _primaryColor, size: 24.sp),
                    style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp),
                    items: [
                      DropdownMenuItem(
                          value: true, child: Text("sort_newest".tr())),
                      DropdownMenuItem(
                          value: false, child: Text("sort_oldest".tr())),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _sortNewestFirst = val);
                        this.setState(() => _sortNewestFirst = val);
                        _loadData();
                      }
                    },
                  ),
                ),
                SizedBox(height: 20.h),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: _borderColor),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10.r,
                      offset: Offset(0, 4.h)),
                ],
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20.sp, color: _primaryColor),
            ),
          ),
          Column(
            children: [
              Text(
                "myEventsButton".tr().toUpperCase(),
                style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: _secondaryColor),
              ),
              SizedBox(height: 4.h),
              Text(
                "events_title".tr(),
                style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor),
              ),
            ],
          ),
          GestureDetector(
            onTap: _showFilterDialog,
            child: Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: _borderColor),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10.r,
                      offset: Offset(0, 4.h)),
                ],
              ),
              child: Icon(Icons.filter_list_rounded,
                  size: 20.sp, color: _primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot eventDoc, int index) {
    final eventData = eventDoc.data() as Map<String, dynamic>;
    final eventId = eventDoc.id;
    final Timestamp timestamp = eventData['createdAt'] ?? Timestamp.now();
    final date = timestamp.toDate();
    final bool isFavorite = _favoriteEventIds.contains(eventId);
    final String title =
        eventData['eventTitle'] ?? "${"events_prefix".tr()}${index + 1}";

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4.r,
              offset: Offset(0, 2.h))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => QRResultScreen(eventId: eventId)),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.qr_code_2_rounded,
                      color: _primaryColor, size: 24.sp),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                            color: _primaryColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        "${date.day}/${date.month}/${date.year} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(
                            color: _secondaryColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
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
                        size: 24.sp,
                      ),
                      onPressed: () => _toggleFavorite(eventId),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: Colors.red.shade300, size: 22.sp),
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

  // Liste boş ise gösterilecek widget
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 64.sp, color: _borderColor),
          SizedBox(height: 16.h),
          Text(message,
              style: TextStyle(
                  color: _secondaryColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Her sekme için liste oluşturucu
  Widget _buildEventList(List<DocumentSnapshot> events, String emptyMessage) {
    if (events.isEmpty) return _buildEmptyState(emptyMessage);
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      itemCount: events.length,
      itemBuilder: (context, index) {
        return _buildEventCard(events[index], index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 3 Sekmeli yapı için DefaultTabController ekliyoruz
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),

              // --- TAB BAR ---
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Container(
                  height: 45.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: _borderColor),
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: _secondaryColor,
                    labelStyle:
                        TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                    tabs: [
                      // Burada "tr()" anahtarlarını uygun çevirilerle değiştirin
                      Tab(text: "Devam Eden"), // ongoing
                      Tab(text: "Başlamayan"), // upcoming
                      Tab(text: "Geçmiş"), // past
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10.h),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        children: [
                          _buildEventList(
                              _ongoingEvents, "Devam eden etkinlik yok"),
                          _buildEventList(
                              _upcomingEvents, "Planlanmış etkinlik yok"),
                          _buildEventList(_endedEvents, "Geçmiş etkinlik yok"),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
