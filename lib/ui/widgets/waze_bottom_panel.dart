import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../waze_theme.dart';
import 'waze_saved_locations_modal.dart';
import 'waze_live_room_sheet.dart';
import 'waze_developer_sheet.dart';
import 'waze_android_auto_modal.dart';

class WazeBottomPanel extends StatelessWidget {
  const WazeBottomPanel({
    super.key,
    required this.controller,
    required this.onTapSearch,
    required this.onTapSettings,
    required this.onTapAddStop,
    this.onTapVoice,
    this.onOpenLiveRoom,
    this.onFitTrack,
    this.isMinimized = false,
    this.onMinimizedChanged,
  });

  final AppController controller;
  final VoidCallback onTapSearch;
  final VoidCallback onTapSettings;
  final VoidCallback onTapAddStop;
  final VoidCallback? onTapVoice;
  final VoidCallback? onOpenLiveRoom;
  final VoidCallback? onFitTrack;
  final bool isMinimized;
  final ValueChanged<bool>? onMinimizedChanged;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final dark = c.dark;
    final bg = dark ? WazeColors.darkSurface : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 18,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: c.navigating
              ? _buildNavigatingState(context, c)
              : (c.destination != null
                  ? _buildRoutePreviewState(context, c)
                  : (isMinimized
                      ? _buildMinimizedIdleState(context, c)
                      : _buildIdleState(context, c))),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 0. Minimized Bar State (Map maximization)
  // -------------------------------------------------------------
  Widget _buildMinimizedIdleState(BuildContext context, AppController c) {
    final dark = c.dark;
    final arabic = c.arabic;

    return InkWell(
      key: const ValueKey('minimized_panel'),
      onTap: () => onMinimizedChanged?.call(false),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle with subtle expand indicator
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: dark ? Colors.white38 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: dark ? WazeColors.darkCard : const Color(0xFFF0F3F6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: dark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: WazeColors.cyan,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      arabic ? 'إلى أين تريد الذهاب؟' : 'Where to?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  if (onTapVoice != null) ...[
                    IconButton(
                      icon: const Icon(Icons.mic_rounded, size: 21, color: WazeColors.cyan),
                      tooltip: arabic ? 'الملاحة الصوتية' : 'Voice Search',
                      onPressed: onTapVoice,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 26, color: WazeColors.cyan),
                    tooltip: arabic ? 'توسيع القائمة' : 'Expand panel',
                    onPressed: () => onMinimizedChanged?.call(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 1. Idle / Explore State
  // -------------------------------------------------------------
  Widget _buildIdleState(BuildContext context, AppController c) {
    final dark = c.dark;
    final arabic = c.arabic;
    final textColor = dark ? Colors.white : Colors.black87;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Padding(
        key: const ValueKey('idle_panel_landscape'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.parkedLocation != null) ...[
              _buildParkedCarCard(context, c, dark, textColor, arabic),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTapSearch,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: dark ? WazeColors.darkCard : const Color(0xFFF0F3F6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: dark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: WazeColors.cyan, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                arabic ? 'إلى أين تريد الذهاب؟' : 'Where to?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: dark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (onTapVoice != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.mic_rounded, color: WazeColors.cyan, size: 22),
                    tooltip: arabic ? 'الملاحة الصوتية' : 'Voice Search',
                    onPressed: onTapVoice,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
                const SizedBox(width: 6),
                _buildQuickPill(
                  icon: Icons.home_rounded,
                  label: arabic ? 'المنزل' : 'Home',
                  color: const Color(0xFF29B6F6),
                  dark: dark,
                  textColor: textColor,
                  onTap: () {
                    if (c.home != null) {
                      c.chooseDestination(c.home!);
                    } else {
                      showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => WazeSavedLocationsModal(
                          controller: c,
                          initialRole: SavedPlaceRole.home,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickPill(
                  icon: Icons.work_rounded,
                  label: arabic ? 'العمل' : 'Work',
                  color: const Color(0xFFAB47BC),
                  dark: dark,
                  textColor: textColor,
                  onTap: () {
                    if (c.work != null) {
                      c.chooseDestination(c.work!);
                    } else {
                      showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => WazeSavedLocationsModal(
                          controller: c,
                          initialRole: SavedPlaceRole.work,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  color: dark ? Colors.white54 : Colors.black45,
                  onPressed: onTapSettings,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      key: const ValueKey('idle_panel'),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle with tap-to-minimize
          Center(
            child: InkWell(
              onTap: () => onMinimizedChanged?.call(true),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white38 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: dark ? Colors.white54 : Colors.black45,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Search Bar Input Trigger
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTapSearch,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: dark ? WazeColors.darkCard : const Color(0xFFF0F3F6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: dark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: WazeColors.cyan,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        arabic ? 'إلى أين تريد الذهاب؟' : 'Where to?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: dark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    if (onTapVoice != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: WazeColors.cyan.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.mic_rounded, size: 21),
                          color: WazeColors.cyan,
                          tooltip: arabic ? 'الملاحة الصوتية' : 'Voice Search',
                          onPressed: onTapVoice,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, size: 20),
                      color: dark ? Colors.white54 : Colors.black45,
                      onPressed: onTapSettings,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Quick Action Buttons (Home, Work, Saved, Planned, Convoy, Dev, Settings) - Horizontally Scrollable
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                _buildQuickPill(
                  icon: Icons.home_rounded,
                  label: arabic ? 'المنزل' : 'Home',
                  color: const Color(0xFF29B6F6),
                  dark: dark,
                  textColor: textColor,
                  onTap: () {
                    if (c.home != null) {
                      c.chooseDestination(c.home!);
                    } else {
                      showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => WazeSavedLocationsModal(
                          controller: c,
                          initialRole: SavedPlaceRole.home,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickPill(
                  icon: Icons.work_rounded,
                  label: arabic ? 'العمل' : 'Work',
                  color: const Color(0xFFAB47BC),
                  dark: dark,
                  textColor: textColor,
                  onTap: () {
                    if (c.work != null) {
                      c.chooseDestination(c.work!);
                    } else {
                      showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => WazeSavedLocationsModal(
                          controller: c,
                          initialRole: SavedPlaceRole.work,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickPill(
                  icon: Icons.star_rounded,
                  label: arabic ? 'المحفوظات' : 'Saved',
                  color: Colors.amber,
                  dark: dark,
                  textColor: textColor,
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => WazeSavedLocationsModal(
                        controller: c,
                        initialRole: SavedPlaceRole.any,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickPill(
                  icon: Icons.local_parking_rounded,
                  label: c.parkedLocation != null
                      ? (arabic ? 'سيارتي' : 'Parked')
                      : (arabic ? 'ركنت هنا' : 'Park Here'),
                  color: WazeColors.cyan,
                  dark: dark,
                  textColor: textColor,
                  onTap: () {
                    if (c.parkedLocation != null) {
                      c.navigateToParkedCar();
                    } else {
                      c.saveParkingLocation();
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickPill(
                  icon: Icons.groups_rounded,
                  label: c.activeLiveRoom != null
                      ? (arabic ? 'شلّة (${c.activeLiveRoom!.code})' : 'Room (${c.activeLiveRoom!.code})')
                      : (arabic ? 'دَرب شلّة' : 'Convoy'),
                  color: const Color(0xFF00E676),
                  dark: dark,
                  textColor: textColor,
                  onTap: () {
                    if (onOpenLiveRoom != null) {
                      onOpenLiveRoom!();
                    } else {
                      WazeLiveRoomSheet.show(
                        context,
                        controller: c,
                        onFitTrack: onFitTrack,
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickPill(
                  icon: Icons.person_pin_rounded,
                  label: arabic ? 'المطور' : 'Developer',
                  color: const Color(0xFFAB47BC),
                  dark: dark,
                  textColor: textColor,
                  onTap: () {
                    showWazeDeveloperSheet(context, controller: c);
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickPill(
                  icon: Icons.directions_car_filled_rounded,
                  label: arabic ? 'السيارة' : 'Car Auto',
                  color: WazeColors.blue,
                  dark: dark,
                  textColor: textColor,
                  onTap: () {
                    showWazeAndroidAutoModal(context, controller: c);
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickPill(
                  icon: Icons.settings_rounded,
                  label: arabic ? 'الإعدادات' : 'Settings',
                  color: const Color(0xFF78909C),
                  dark: dark,
                  textColor: textColor,
                  onTap: onTapSettings,
                ),
              ],
            ),
          ),

          // Active Live Room Banner if connected
          if (c.activeLiveRoom != null) ...[
            const SizedBox(height: 12),
            _buildActiveLiveRoomBanner(context, c, dark, textColor, arabic),
          ],

          // Saved Parked Car Card
          if (c.parkedLocation != null) ...[
            const SizedBox(height: 12),
            _buildParkedCarCard(context, c, dark, textColor, arabic),
          ],

          // Recent places preview if available
          if (c.recent.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              arabic ? 'الوجهات الأخيرة' : 'Recent Places',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.recent.take(4).length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final place = c.recent[i];
                  return ActionChip(
                    avatar: const Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: WazeColors.cyan,
                    ),
                    label: Text(place.label(arabic)),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    backgroundColor:
                        dark ? WazeColors.darkCard : const Color(0xFFF0F3F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide.none,
                    ),
                    onPressed: () => c.chooseDestination(place),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParkedCarCard(
    BuildContext context,
    AppController c,
    bool dark,
    Color textColor,
    bool arabic,
  ) {
    final parked = c.parkedLocation!;
    final meters = const Distance().as(LengthUnit.Meter, c.position, parked.point);
    final distStr = c.distance(meters.toDouble());

    final elapsed = DateTime.now().difference(parked.savedAt);
    final String timeStr;
    if (elapsed.inMinutes < 1) {
      timeStr = arabic ? 'الآن' : 'Just now';
    } else if (elapsed.inMinutes < 60) {
      timeStr = arabic ? 'منذ ${elapsed.inMinutes} د' : '${elapsed.inMinutes}m ago';
    } else {
      final hours = elapsed.inHours;
      final mins = elapsed.inMinutes % 60;
      timeStr = arabic ? 'منذ $hours س و $mins د' : '${hours}h ${mins}m ago';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E2835) : const Color(0xFFEBF3FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: WazeColors.cyan.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: WazeColors.cyan,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: WazeColors.cyan.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '🅿️',
                style: TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      arabic ? 'موقع سيارتي' : 'My Parked Car',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: WazeColors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: WazeColors.cyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  arabic ? 'على بُعد $distStr من موقعك' : '$distStr from your location',
                  style: TextStyle(
                    fontSize: 12,
                    color: dark ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (parked.note != null && parked.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    parked.note!,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: dark ? Colors.white60 : Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: dark ? Colors.white54 : Colors.black45,
            tooltip: arabic ? 'مسح الموقع' : 'Clear',
            onPressed: () => c.clearParkingLocation(),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.directions_walk_rounded, size: 16),
            label: Text(arabic ? 'انطلق' : 'Go'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WazeColors.cyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            onPressed: () => c.navigateToParkedCar(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLiveRoomBanner(
    BuildContext context,
    AppController c,
    bool dark,
    Color textColor,
    bool arabic,
  ) {
    final room = c.activeLiveRoom!;
    return InkWell(
      onTap: () {
        if (onOpenLiveRoom != null) {
          onOpenLiveRoom!();
        } else {
          WazeLiveRoomSheet.show(
            context,
            controller: c,
            onFitTrack: onFitTrack,
          );
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF10281E) : const Color(0xFFE8F8F0),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF00E676).withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF00E676),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.groups_rounded, color: Colors.black, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        room.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          room.code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00E676),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${room.members.length} ${arabic ? "أصدقاء متصلين • اضغط للعرض والمشاركة" : "members connected • Tap to view"}',
                    style: TextStyle(
                      fontSize: 11,
                      color: dark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF00E676)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPill({
    required IconData icon,
    required String label,
    required Color color,
    required bool dark,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: color, size: 24),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 2. Route Preview State
  // -------------------------------------------------------------
  Widget _buildRoutePreviewState(BuildContext context, AppController c) {
    final dark = c.dark;
    final arabic = c.arabic;
    final textColor = dark ? Colors.white : Colors.black87;
    final target = c.destination!;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Padding(
        key: const ValueKey('preview_panel_landscape'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: WazeColors.cyan, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          target.label(arabic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => c.clearRoute(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                  if (c.route != null) ...[
                    Row(
                      children: [
                        Text(
                          c.duration(c.route!.totalDurationSeconds),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: WazeColors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          c.distance(c.route!.distanceMeters),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: dark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        if (c.routes.length > 1) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              final next = (c.routeIndex + 1) % c.routes.length;
                              c.selectRoute(next);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: WazeColors.cyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${arabic ? 'مسار' : 'Route'} ${c.routeIndex + 1}/${c.routes.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: WazeColors.cyan,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: c.routes.isEmpty ? null : () => c.startNavigation(),
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: Text(
                arabic ? 'انطلق' : 'Drive',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: WazeColors.cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      key: const ValueKey('preview_panel'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Destination header
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: WazeColors.cyan,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.label(arabic),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    Text(
                      target.detail(arabic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: dark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  c.isSaved(target)
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: c.isSaved(target) ? Colors.amber : (dark ? Colors.white70 : Colors.black54),
                ),
                tooltip: arabic ? 'حفظ في المفضلة' : 'Save to Favorites',
                onPressed: () {
                  c.toggleSaved(target);
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => c.clearRoute(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stop info if active
          if (c.stop != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${arabic ? 'محطة توقف:' : 'Stop:'} ${c.stop!.label(arabic)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => c.removeStop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Alternative Routes selector
          if (c.busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: CircularProgressIndicator(color: WazeColors.cyan),
              ),
            )
          else if (c.routes.isNotEmpty) ...[
            Row(
              children: List.generate(c.routes.length, (i) {
                final r = c.routes[i];
                final isSelected = c.routeIndex == i;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 6,
                      right: i == c.routes.length - 1 ? 0 : 6,
                    ),
                    child: InkWell(
                      onTap: () => c.selectRoute(i),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? WazeColors.cyan.withValues(alpha: 0.18)
                              : (dark ? WazeColors.darkCard : const Color(0xFFF0F3F6)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? WazeColors.cyan
                                : Colors.transparent,
                            width: 2.2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: WazeColors.cyan.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Builder(
                          builder: (context) {
                            final rEta = DateTime.now().add(
                              Duration(seconds: r.totalDurationSeconds.round()),
                            );
                            final rEtaStr =
                                '${rEta.hour.toString().padLeft(2, '0')}:${rEta.minute.toString().padLeft(2, '0')}';

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    c.duration(r.totalDurationSeconds),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: isSelected
                                          ? WazeColors.blue
                                          : (dark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$rEtaStr · ${c.distance(r.distanceMeters)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: dark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                if (i == 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: WazeColors.green,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        arabic ? '⚡ الأسرع' : '⚡ Fastest',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (i > 0 && r.totalDurationSeconds > c.routes.first.totalDurationSeconds)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '+${c.duration(r.totalDurationSeconds - c.routes.first.totalDurationSeconds)}',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: dark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (r.hasTraffic) ...[
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: WazeColors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.traffic_rounded, size: 9, color: WazeColors.red),
                                        const SizedBox(width: 2),
                                        Flexible(
                                          child: Text(
                                            arabic
                                                ? '+${(r.trafficDelaySeconds / 60).round()}د ازدحام'
                                                : '+${(r.trafficDelaySeconds / 60).round()}m traffic',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                              color: WazeColors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (r.trafficSegments.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: SizedBox(
                                      height: 3.5,
                                      width: double.infinity,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: (100 - (r.trafficSegments.length * 15)).clamp(30, 90),
                                            child: Container(color: WazeColors.cyan),
                                          ),
                                          ...r.trafficSegments.take(3).map((s) {
                                            Color barCol;
                                            switch (s.level) {
                                              case TrafficCongestionLevel.standstill:
                                                barCol = const Color(0xFF8B0000);
                                                break;
                                              case TrafficCongestionLevel.heavy:
                                                barCol = WazeColors.red;
                                                break;
                                              case TrafficCongestionLevel.moderate:
                                                barCol = const Color(0xFFFF9500);
                                                break;
                                              case TrafficCongestionLevel.free:
                                                barCol = WazeColors.cyan;
                                                break;
                                            }
                                            return Expanded(
                                              flex: 15,
                                              child: Container(color: barCol),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (c.route != null && c.route!.hasTraffic) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: dark ? WazeColors.darkCard : const Color(0xFFFFF6ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.traffic_rounded, color: Color(0xFFFF9500), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        arabic
                            ? 'الوقت الإجمالي للمسار: ${c.duration(c.route!.totalDurationSeconds)} (شامل تأخير الازدحام +${c.duration(c.route!.trafficDelaySeconds)})'
                            : 'Total route time: ${c.duration(c.route!.totalDurationSeconds)} (includes +${c.duration(c.route!.trafficDelaySeconds)} traffic delay)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: dark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],

          // Buttons: Start Drive + Add Stop
          Row(
            children: [
              if (c.stop == null) ...[
                OutlinedButton.icon(
                  onPressed: onTapAddStop,
                  icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                  label: Text(arabic ? '+ محطة' : '+ Stop'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: c.routes.isEmpty ? null : () => c.startNavigation(),
                  icon: const Icon(Icons.navigation_rounded, size: 22),
                  label: Text(
                    arabic ? 'انطلق الآن' : 'Drive Now',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: WazeColors.cyan,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 3. Active Navigating State
  // -------------------------------------------------------------
  Widget _buildNavigatingState(BuildContext context, AppController c) {
    final dark = c.dark;
    final arabic = c.arabic;
    final p = c.progress;

    final route = c.route;
    final remainingSecs = p?.remainingSeconds ?? route?.totalDurationSeconds ?? 0;
    final remainingMeters = p?.remainingMeters ?? route?.distanceMeters ?? 0;

    // Calculate arrival time
    final etaTime = DateTime.now().add(Duration(seconds: remainingSecs.round()));
    final hour = etaTime.hour.toString().padLeft(2, '0');
    final minute = etaTime.minute.toString().padLeft(2, '0');
    final etaString = '$hour:$minute';

    // Calculate remaining traffic delay proportionally to remaining distance
    var remainingDelayMin = 0;
    if (route != null && route.hasTraffic) {
      final totalDist = route.distanceMeters > 0 ? route.distanceMeters : remainingMeters;
      final remainingRatio = totalDist > 0 ? (remainingMeters / totalDist).clamp(0.0, 1.0) : 1.0;
      final remainingDelaySecs = (route.trafficDelaySeconds * remainingRatio).clamp(0.0, remainingSecs);
      remainingDelayMin = (remainingDelaySecs / 60).round();
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Padding(
        key: const ValueKey('nav_panel_landscape'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Duration
            Text(
              c.duration(remainingSecs),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: WazeColors.green,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            // Distance
            Text(
              c.distance(remainingMeters),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 1,
              height: 14,
              color: dark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(width: 10),
            // ETA
            Text(
              '${arabic ? 'الوصول:' : 'ETA:'} $etaString',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white60 : Colors.black54,
              ),
            ),
            if (remainingDelayMin >= 1) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: WazeColors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.traffic_rounded, size: 12, color: WazeColors.red),
                    const SizedBox(width: 3),
                    Text(
                      '+$remainingDelayMin د',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: WazeColors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            // End Navigation Compact Button
            FilledButton.icon(
              onPressed: () => c.stopNavigation(),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: Text(
                arabic ? 'إنهاء' : 'End',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: WazeColors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      key: const ValueKey('nav_panel'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // ETA & Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          c.duration(remainingSecs),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: WazeColors.green,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          c.distance(remainingMeters),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: dark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${arabic ? 'الوصول المتوقع:' : 'ETA:'} $etaString',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: dark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    if (remainingDelayMin >= 1) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.traffic_rounded, size: 14, color: WazeColors.red),
                          const SizedBox(width: 4),
                          Text(
                            arabic
                                ? 'شامل تأخير الازدحام +$remainingDelayMin د'
                                : 'Includes +$remainingDelayMin min traffic delay',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: WazeColors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // End Navigation Red Button
              FilledButton.icon(
                onPressed: () => c.stopNavigation(),
                icon: const Icon(Icons.close_rounded, size: 20),
                label: Text(
                  arabic ? 'إنهاء' : 'End',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: WazeColors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
