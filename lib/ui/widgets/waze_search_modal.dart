import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../app/app_controller.dart';
import '../../domain/demo_data.dart';
import '../../domain/models.dart';
import '../waze_theme.dart';
import 'waze_voice_search_sheet.dart';

class WazeSearchModal extends StatefulWidget {
  const WazeSearchModal({
    super.key,
    required this.controller,
    this.asStop = false,
  });

  final AppController controller;
  final bool asStop;

  @override
  State<WazeSearchModal> createState() => _WazeSearchModalState();
}

class _WazeSearchModalState extends State<WazeSearchModal> {
  final TextEditingController _input = TextEditingController();
  PlaceCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Default show sample list if demoMode
    if (widget.controller.demoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.demoMode) {
          widget.controller.filterSamples('');
        }
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _onCategory(PlaceCategory category) {
    setState(() {
      if (_selectedCategory == category) {
        _selectedCategory = null;
      } else {
        _selectedCategory = category;
      }
    });
    if (widget.controller.demoMode) {
      widget.controller.filterSamples(
        _input.text,
        category: _selectedCategory,
      );
    } else {
      final query = _categoryQuery(category);
      _input.text = query;
      widget.controller.searchPlaces(query);
    }
  }

  String _categoryQuery(PlaceCategory cat) {
    final ar = widget.controller.arabic;
    switch (cat) {
      case PlaceCategory.fuel:
        return ar ? 'محطة وقود' : 'Gas Station';
      case PlaceCategory.food:
        return ar ? 'مطعم' : 'Restaurant';
      case PlaceCategory.parking:
        return ar ? 'موقف سيارات' : 'Parking';
      case PlaceCategory.charging:
        return ar ? 'شاحن كهربائي' : 'EV Charging';
      case PlaceCategory.landmark:
        return ar ? 'معلم' : 'Landmark';
    }
  }

  IconData _categoryIcon(PlaceCategory cat) {
    switch (cat) {
      case PlaceCategory.fuel:
        return Icons.local_gas_station_rounded;
      case PlaceCategory.food:
        return Icons.restaurant_rounded;
      case PlaceCategory.parking:
        return Icons.local_parking_rounded;
      case PlaceCategory.charging:
        return Icons.ev_station_rounded;
      case PlaceCategory.landmark:
        return Icons.account_balance_rounded;
    }
  }

  void _selectPlace(Place place) {
    widget.controller.chooseDestination(place, asStop: widget.asStop);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final dark = c.dark;
    final arabic = c.arabic;
    final bg = dark ? WazeColors.darkSurface : Colors.white;
    final textColor = dark ? Colors.white : Colors.black87;

    final placesToShow = c.searchResults.isNotEmpty
        ? c.searchResults
        : (c.demoMode ? demoPlaces : c.recent);

    return Material(
      color: bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
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

          // Search header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    autofocus: true,
                    style: TextStyle(color: textColor),
                    onChanged: (val) {
                      if (c.demoMode) {
                        c.filterSamples(val, category: _selectedCategory);
                      }
                    },
                    onSubmitted: (val) {
                      if (!c.demoMode) {
                        c.searchPlaces(val);
                      }
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search,
                        color: WazeColors.cyan,
                        size: 24,
                      ),
                      suffixIcon: _input.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _input.clear();
                                if (c.demoMode) {
                                  c.filterSamples(
                                    '',
                                    category: _selectedCategory,
                                  );
                                }
                                setState(() {});
                              },
                            )
                          : IconButton(
                              icon: const Icon(Icons.mic_rounded, color: WazeColors.cyan, size: 22),
                              tooltip: arabic ? 'بحث صوتي' : 'Voice Search',
                              onPressed: () {
                                Navigator.of(context).pop();
                                WazeVoiceSearchSheet.show(context, widget.controller);
                              },
                            ),
                      hintText: widget.asStop
                          ? (arabic
                              ? 'إضافة محطة توقف في الطريق...'
                              : 'Add a stop along the way...')
                          : (arabic
                              ? 'إلى أين تريد الذهاب؟'
                              : 'Where to? Search address or place'),
                      hintStyle: TextStyle(
                        color: dark ? Colors.white38 : Colors.black38,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: dark
                          ? WazeColors.darkCard
                          : const Color(0xFFF0F3F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    arabic ? 'إلغاء' : 'Cancel',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Category Chips Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: PlaceCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: Icon(
                      _categoryIcon(cat),
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : (dark ? Colors.white70 : Colors.black87),
                    ),
                    label: Text(_categoryQuery(cat)),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (dark ? Colors.white70 : Colors.black87),
                    ),
                    selectedColor: WazeColors.cyan,
                    backgroundColor: dark
                        ? WazeColors.darkCard
                        : const Color(0xFFEAEFF5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? WazeColors.cyan
                            : Colors.transparent,
                      ),
                    ),
                    onSelected: (_) => _onCategory(cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          if (c.searching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: WazeColors.cyan),
              ),
            )
          else ...[
            Expanded(
              child: placesToShow.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off_rounded,
                            size: 48,
                            color: dark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            arabic ? 'لا توجد نتائج' : 'No places found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: dark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            arabic
                                ? 'جرّب البحث باسم آخر'
                                : 'Try searching with another name',
                            style: TextStyle(
                              fontSize: 13,
                              color: dark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      itemCount: placesToShow.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: dark ? Colors.white12 : Colors.black12),
                      itemBuilder: (context, i) {
                        final p = placesToShow[i];
                        final isSaved = c.isSaved(p);
                        final meters = const Distance().as(LengthUnit.Meter, c.position, p.point);
                        final distStr = c.distance(meters.toDouble());

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: WazeColors.cyan.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _categoryIcon(p.category),
                              color: WazeColors.blue,
                              size: 22,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.label(arabic),
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: WazeColors.cyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  distStr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: WazeColors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              p.detail(arabic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: dark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isSaved ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: isSaved ? Colors.amber : (dark ? Colors.white38 : Colors.black38),
                                ),
                                onPressed: () => c.toggleSaved(p),
                              ),
                              FilledButton(
                                onPressed: () => _selectPlace(p),
                                style: FilledButton.styleFrom(
                                  backgroundColor: WazeColors.cyan,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  widget.asStop
                                      ? (arabic ? '+ محطة' : '+ Stop')
                                      : (arabic ? 'انطلق' : 'Drive'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
