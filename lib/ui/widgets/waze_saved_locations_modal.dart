import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../app/app_controller.dart';
import '../../domain/demo_data.dart';
import '../../domain/models.dart';
import '../waze_theme.dart';

enum SavedPlaceRole { any, home, work }

class WazeSavedLocationsModal extends StatefulWidget {
  const WazeSavedLocationsModal({
    super.key,
    required this.controller,
    this.initialRole = SavedPlaceRole.any,
    this.onSelectToDrive = true,
  });

  final AppController controller;
  final SavedPlaceRole initialRole;
  final bool onSelectToDrive;

  @override
  State<WazeSavedLocationsModal> createState() =>
      _WazeSavedLocationsModalState();
}

class _WazeSavedLocationsModalState extends State<WazeSavedLocationsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  SavedPlaceRole _targetRole = SavedPlaceRole.any;

  @override
  void initState() {
    super.initState();
    _targetRole = widget.initialRole;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialRole == SavedPlaceRole.any ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _queryController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _applyPlaceToRole(Place p, SavedPlaceRole role) {
    final c = widget.controller;
    switch (role) {
      case SavedPlaceRole.home:
        c.setHome(p);
        break;
      case SavedPlaceRole.work:
        c.setWork(p);
        break;
      case SavedPlaceRole.any:
        c.savePlace(p);
        break;
    }
  }

  void _onChoosePlace(Place p) {
    final c = widget.controller;
    if (_targetRole != SavedPlaceRole.any) {
      _applyPlaceToRole(p, _targetRole);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            c.arabic
                ? 'تم تعيين ${_targetRole == SavedPlaceRole.home ? "المنزل" : "العمل"}: ${p.label(c.arabic)}'
                : 'Set ${_targetRole == SavedPlaceRole.home ? "Home" : "Work"}: ${p.label(c.arabic)}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      if (widget.onSelectToDrive) {
        c.chooseDestination(p);
        Navigator.of(context).pop();
      } else {
        c.savePlace(p);
        Navigator.of(context).pop();
      }
    }
  }

  void _showSetRoleDialog(Place p) {
    final c = widget.controller;
    final arabic = c.arabic;
    final dark = c.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: dark ? WazeColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.label(arabic),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0x2229B6F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.home_rounded,
                    color: Color(0xFF29B6F6),
                  ),
                ),
                title: Text(arabic ? 'تعيين كمنزل' : 'Set as Home'),
                onTap: () {
                  c.setHome(p);
                  Navigator.of(ctx).pop();
                  setState(() {});
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0x22AB47BC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.work_rounded,
                    color: Color(0xFFAB47BC),
                  ),
                ),
                title: Text(arabic ? 'تعيين كعمل' : 'Set as Work'),
                onTap: () {
                  c.setWork(p);
                  Navigator.of(ctx).pop();
                  setState(() {});
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0x22EF5350),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                ),
                title: Text(
                  arabic ? 'إزالة من المحفوظات' : 'Remove from Saved',
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  c.removeSaved(p.id);
                  Navigator.of(ctx).pop();
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveCustomCoordinates() {
    final c = widget.controller;
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final name = _nameController.text.trim();

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            c.arabic
                ? 'يرجى إدخال إحداثيات صالحة'
                : 'Please enter valid coordinates',
          ),
        ),
      );
      return;
    }

    final place = Place(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      name: name.isNotEmpty
          ? name
          : (c.arabic ? 'موقع مخصص' : 'Custom Place'),
      nameAr: name.isNotEmpty ? name : 'موقع مخصص',
      subtitle: '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      subtitleAr: '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      point: LatLng(lat, lng),
    );

    _applyPlaceToRole(place, _targetRole);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final dark = c.dark;
    final arabic = c.arabic;
    final bg = dark ? WazeColors.darkSurface : Colors.white;
    final textColor = dark ? Colors.white : Colors.black87;

    return Material(
      color: bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: dark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _targetRole == SavedPlaceRole.home
                              ? (arabic ? 'تعيين عنوان المنزل' : 'Set Home Location')
                              : (_targetRole == SavedPlaceRole.work
                                  ? (arabic ? 'تعيين عنوان العمل' : 'Set Work Location')
                                  : (arabic ? 'الأماكن المحفوظة' : 'Saved Locations')),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          arabic
                              ? 'اختر من البحث، الخريطة، أو الوجهات السابقة'
                              : 'Select from search, map, or previous places',
                          style: TextStyle(
                            fontSize: 12,
                            color: dark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab bar for options
            TabBar(
              controller: _tabController,
              labelColor: WazeColors.cyan,
              unselectedLabelColor: dark ? Colors.white54 : Colors.black54,
              indicatorColor: WazeColors.cyan,
              tabs: [
                Tab(
                  icon: const Icon(Icons.bookmarks_rounded, size: 20),
                  text: arabic ? 'المحفوظة' : 'Saved',
                ),
                Tab(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  text: arabic ? 'بحث وتعيين' : 'Search & Set',
                ),
                Tab(
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 20),
                  text: arabic ? 'كتابة إحداثيات' : 'Custom Input',
                ),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Current Saved & Favorites
                  _buildSavedListTab(c, dark, arabic, textColor),

                  // Tab 2: Search or choose from Recents
                  _buildSearchAndSetTab(c, dark, arabic, textColor),

                  // Tab 3: Type location name or coordinates
                  _buildCustomInputTab(c, dark, arabic, textColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Current Saved & Favorites ──
  Widget _buildSavedListTab(
    AppController c,
    bool dark,
    bool arabic,
    Color textColor,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      children: [
        // Home Card
        _buildSpecialRoleTile(
          title: arabic ? 'المنزل' : 'Home',
          place: c.home,
          icon: Icons.home_rounded,
          color: const Color(0xFF29B6F6),
          dark: dark,
          arabic: arabic,
          textColor: textColor,
          onSet: () {
            setState(() {
              _targetRole = SavedPlaceRole.home;
              _tabController.animateTo(1);
            });
          },
          onTap: () {
            if (c.home != null) _onChoosePlace(c.home!);
          },
        ),
        const SizedBox(height: 10),

        // Work Card
        _buildSpecialRoleTile(
          title: arabic ? 'العمل' : 'Work',
          place: c.work,
          icon: Icons.work_rounded,
          color: const Color(0xFFAB47BC),
          dark: dark,
          arabic: arabic,
          textColor: textColor,
          onSet: () {
            setState(() {
              _targetRole = SavedPlaceRole.work;
              _tabController.animateTo(1);
            });
          },
          onTap: () {
            if (c.work != null) _onChoosePlace(c.work!);
          },
        ),
        const SizedBox(height: 16),

        Text(
          arabic ? 'جميع المواقع المحفوظة' : 'All Saved Places',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: dark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),

        if (c.saved.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.star_outline_rounded,
                    size: 44,
                    color: dark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    arabic
                        ? 'لا توجد أماكن محفوظة حالياً'
                        : 'No saved places yet',
                    style: TextStyle(
                      color: dark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...c.saved.map(
            (p) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 22,
                ),
              ),
              title: Text(
                p.label(arabic),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              subtitle: Text(
                p.detail(arabic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.white54 : Colors.black54,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () => _showSetRoleDialog(p),
                  ),
                  FilledButton(
                    onPressed: () => _onChoosePlace(p),
                    style: FilledButton.styleFrom(
                      backgroundColor: WazeColors.cyan,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      arabic ? 'انطلق' : 'Drive',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSpecialRoleTile({
    required String title,
    required Place? place,
    required IconData icon,
    required Color color,
    required bool dark,
    required bool arabic,
    required Color textColor,
    required VoidCallback onSet,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? WazeColors.darkCard : const Color(0xFFF2F5F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        subtitle: Text(
          place != null
              ? place.label(arabic)
              : (arabic ? 'اضغط لتعيين هذا العنوان' : 'Tap to set address'),
          style: TextStyle(
            fontSize: 12,
            color: place != null
                ? (dark ? Colors.white70 : Colors.black87)
                : (dark ? Colors.white38 : Colors.black38),
          ),
        ),
        trailing: place != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    onPressed: onSet,
                  ),
                  FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      arabic ? 'انطلق' : 'Drive',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              )
            : OutlinedButton(
                onPressed: onSet,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  arabic ? 'تعيين' : 'Set',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }

  // ── Tab 2: Search or Pick from Previous Places ──
  Widget _buildSearchAndSetTab(
    AppController c,
    bool dark,
    bool arabic,
    Color textColor,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: TextField(
            controller: _queryController,
            style: TextStyle(color: textColor),
            onChanged: (val) {
              if (c.demoMode) {
                c.filterSamples(val);
              }
            },
            onSubmitted: (val) {
              if (!c.demoMode) {
                c.searchPlaces(val);
              }
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: WazeColors.cyan),
              hintText: arabic
                  ? 'ابحث عن اسم مكان أو عنوان...'
                  : 'Search place name or address...',
              filled: true,
              fillColor: dark ? WazeColors.darkCard : const Color(0xFFF0F3F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),

        // Recent / Searched header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Row(
            children: [
              Text(
                c.searchResults.isNotEmpty
                    ? (arabic ? 'نتائج البحث' : 'Search Results')
                    : (arabic ? 'الوجهات والبحوث السابقة' : 'Recent Places & Searches'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Builder(
            builder: (context) {
              final list = c.searchResults.isNotEmpty
                  ? c.searchResults
                  : (c.demoMode ? demoPlaces : c.recent);

              if (list.isEmpty) {
                return Center(
                  child: Text(
                    arabic ? 'لا توجد نتائج سابقة' : 'No recent places',
                    style: TextStyle(
                      color: dark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: list.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: dark ? Colors.white12 : Colors.black12,
                ),
                itemBuilder: (context, i) {
                  final p = list[i];
                  return ListTile(
                    leading: const Icon(
                      Icons.history_rounded,
                      color: WazeColors.cyan,
                    ),
                    title: Text(
                      p.label(arabic),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      p.detail(arabic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: dark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () => _onChoosePlace(p),
                      child: Text(
                        _targetRole == SavedPlaceRole.any
                            ? (arabic ? 'حفظ' : 'Save')
                            : (arabic ? 'تعيين' : 'Set'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Tab 3: Custom Input / Coordinates ──
  Widget _buildCustomInputTab(
    AppController c,
    bool dark,
    bool arabic,
    Color textColor,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          arabic ? 'تحديد وتسمية موقع يدوي' : 'Custom Location & Coordinates',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _nameController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: arabic ? 'اسم المكان (اختياري)' : 'Place Name (Optional)',
            prefixIcon: const Icon(Icons.label_outline_rounded),
            filled: true,
            fillColor: dark ? WazeColors.darkCard : const Color(0xFFF0F3F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: arabic ? 'خط العرض (Lat)' : 'Latitude',
                  hintText: '33.3152',
                  filled: true,
                  fillColor: dark ? WazeColors.darkCard : const Color(0xFFF0F3F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _lngController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: arabic ? 'خط الطول (Lng)' : 'Longitude',
                  hintText: '44.3661',
                  filled: true,
                  fillColor: dark ? WazeColors.darkCard : const Color(0xFFF0F3F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        OutlinedButton.icon(
          onPressed: () {
            _latController.text = c.position.latitude.toStringAsFixed(6);
            _lngController.text = c.position.longitude.toStringAsFixed(6);
            setState(() {});
          },
          icon: const Icon(Icons.my_location_rounded, size: 18),
          label: Text(
            arabic ? 'استخدام موقعي الحالي' : 'Use My Current Location',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 20),

        FilledButton(
          onPressed: _saveCustomCoordinates,
          style: FilledButton.styleFrom(
            backgroundColor: WazeColors.cyan,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            arabic ? 'حفظ وتطبيق الموقع' : 'Save & Set Location',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
