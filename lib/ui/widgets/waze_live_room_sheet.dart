import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/app_controller.dart';
import '../../domain/demo_data.dart';
import '../../domain/models.dart';
import '../waze_theme.dart';
import 'waze_search_modal.dart';

class WazeLiveRoomSheet extends StatefulWidget {
  const WazeLiveRoomSheet({
    super.key,
    required this.controller,
    this.onFitTrack,
  });

  final AppController controller;
  final VoidCallback? onFitTrack;

  static Future<void> show(
    BuildContext context, {
    required AppController controller,
    VoidCallback? onFitTrack,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      isScrollControlled: true,
      builder: (_) => WazeLiveRoomSheet(
        controller: controller,
        onFitTrack: onFitTrack,
      ),
    );
  }

  @override
  State<WazeLiveRoomSheet> createState() => _WazeLiveRoomSheetState();
}

class _WazeLiveRoomSheetState extends State<WazeLiveRoomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  int _selectedDurationMinutes = 120;
  String _selectedMode = 'convoy';
  bool _loading = false;
  String? _errorMsg;
  Timer? _localTicker;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final c = widget.controller;
    _displayNameController.text = c.userDisplayName ?? '';
    _nameController.text = c.arabic ? 'طلعة الشباب' : 'Friends Convoy';

    _sheetController.addListener(_onSheetSizeChanged);

    _localTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.controller.activeLiveRoom != null) {
        setState(() {});
      }
    });
  }

  void _onSheetSizeChanged() {
    if (!_sheetController.isAttached) return;
    final size = _sheetController.size;
    final collapsed = size <= 0.28;
    if (collapsed != _isCollapsed && mounted) {
      setState(() => _isCollapsed = collapsed);
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    _localTicker?.cancel();
    _tabController.dispose();
    _nameController.dispose();
    _displayNameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _collapseSheet() {
    if (!_sheetController.isAttached) return;
    widget.onFitTrack?.call();
    _sheetController.animateTo(
      0.22,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _expandSheet() {
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      0.62,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  String _formatRemaining(int seconds) {
    if (seconds <= 0) return '00:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF00E676);
    }
  }

  Future<void> _handleCreate() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final c = widget.controller;
    final room = await c.createLiveRoom(
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
      mode: _selectedMode,
      durationMinutes: _selectedDurationMinutes,
      displayName: _displayNameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (room == null) {
      setState(() {
        _errorMsg = c.arabic ? 'تعذر إنشاء الغرفة. تحقق من الاتصال بالإنترنت.' : 'Could not create room. Check connection.';
      });
    } else {
      widget.onFitTrack?.call();
    }
  }

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() {
        _errorMsg = widget.controller.arabic
            ? 'الرجاء إدخال رمز الغرفة المكون من 6 خانات'
            : 'Please enter the 6-digit room code';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final c = widget.controller;
    final room = await c.joinLiveRoom(
      code,
      displayName: _displayNameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (room == null) {
      setState(() {
        _errorMsg = c.arabic
            ? 'رمز الغرفة غير صحيح أو أن الغرفة انتهت صلاحيتها'
            : 'Invalid room code or room has expired';
      });
    } else {
      widget.onFitTrack?.call();
    }
  }

  void _pickConvoyDestination(BuildContext context, AppController c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WazeSearchModal(controller: c),
    ).then((_) {
      if (c.destination != null) {
        widget.onFitTrack?.call();
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final dark = c.dark;
    final arabic = c.arabic;
    final activeRoom = c.activeLiveRoom;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.62,
      minChildSize: 0.22,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.22, 0.62, 0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: dark ? WazeColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 28, spreadRadius: 2),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              GestureDetector(
                onTap: _isCollapsed ? _expandSheet : _collapseSheet,
                child: Container(
                  width: double.infinity,
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: dark ? Colors.white30 : Colors.black26,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),

              // Main Content (Scrollable or Collapsed Preview)
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isCollapsed
                      ? _buildCollapsedPeekBar(context, c, activeRoom, dark, arabic)
                      : _buildExpandedContent(context, scrollController, c, activeRoom, dark, arabic),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Low-profile bottom peek bar when sheet is collapsed (allowing full view of map track)
  Widget _buildCollapsedPeekBar(
    BuildContext context,
    AppController c,
    LiveRoom? activeRoom,
    bool dark,
    bool arabic,
  ) {
    final destLabel = activeRoom?.destinationName ?? c.destination?.label(arabic);

    return InkWell(
      onTap: _expandSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups_rounded, color: Color(0xFF00E676), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        activeRoom != null
                            ? '${activeRoom.name} (${activeRoom.code})'
                            : (arabic ? 'إعداد موكب الشلّة' : 'Convoy Setup'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: dark ? Colors.white : Colors.black87,
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
                          arabic ? 'معاينة المسار 🗺️' : 'Map Track 🗺️',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destLabel != null
                        ? '${arabic ? "الوجهة:" : "Goal:"} $destLabel • ${arabic ? "اضغط للعودة للإعدادات ☝️" : "Tap to expand ☝️"}'
                        : (arabic ? 'اضغط أو اسحب للأعلى للعودة للغرفة ☝️' : 'Tap or drag up to expand ☝️'),
                    style: TextStyle(
                      fontSize: 11,
                      color: dark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Full scrollable content when expanded
  Widget _buildExpandedContent(
    BuildContext context,
    ScrollController scrollController,
    AppController c,
    LiveRoom? activeRoom,
    bool dark,
    bool arabic,
  ) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 32),
      physics: const BouncingScrollPhysics(),
      children: [
        if (activeRoom != null) ...[
          _buildActiveRoomView(context, c, activeRoom, dark, arabic),
        ] else ...[
          _buildNewRoomTabs(context, c, dark, arabic),
        ],
      ],
    );
  }

  Widget _buildActiveRoomView(
    BuildContext context,
    AppController c,
    LiveRoom room,
    bool dark,
    bool arabic,
  ) {
    final remainingSecs = room.remainingSeconds;
    final isCreator = room.creatorId == c.userId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.groups_rounded, color: Color(0xFF00E676), size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: dark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          room.mode == 'family'
                              ? (arabic ? 'أمان عائلي 🛡️' : 'Family Track 🛡️')
                              : (arabic ? 'موكب شلّة 🚗' : 'Convoy 🚗'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${room.members.length} ${arabic ? "أعضاء" : "members"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Big 6-character Code Showcase Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF101726) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00E676).withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              Text(
                arabic ? 'رمز الغرفة للمشاركة الفورية (6 خانات)' : '6-Digit Room Share Code',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    room.code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF00E676)),
                    tooltip: arabic ? 'نسخ الرمز' : 'Copy Code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: room.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(arabic ? 'تم نسخ رمز الغرفة: ${room.code}' : 'Room code copied: ${room.code}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${arabic ? "الوقت المتبقي:" : "Expires in:"} ${_formatRemaining(remainingSecs)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Convoy Destination & Track Preview Card
        _buildConvoyTrackCard(
          context: context,
          c: c,
          dark: dark,
          arabic: arabic,
          destinationLabel: room.destinationName ?? (c.destination != null ? c.destination!.label(arabic) : null),
          isCreator: isCreator,
          onChangeDestination: () {
            if (c.destination != null) {
              c.setLiveRoomDestination(c.destination!);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(arabic ? 'تم تعيين وجهتك الحالية للشلّة!' : 'Current destination set for convoy!')),
              );
            } else {
              _pickConvoyDestination(context, c);
            }
          },
        ),
        const SizedBox(height: 12),

        // Quick Share Buttons: WhatsApp & Web Link
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(
                  arabic ? 'مشاركة عبر واتساب' : 'WhatsApp Share',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final shareText = arabic
                      ? 'انضم إلى غرفتي المباشرة على تطبيق دَرب (رمز: ${room.code}):\n${room.shareUrl}'
                      : 'Join my live location room on Darb (Code: ${room.code}):\n${room.shareUrl}';
                  Clipboard.setData(ClipboardData(text: shareText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(arabic ? 'تم نسخ نص المشاركة للحافظة!' : 'Share text copied!'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.link_rounded),
              tooltip: arabic ? 'نسخ الرابط المباشر' : 'Copy Web Link',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: room.shareUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(arabic ? 'تم نسخ رابط الويب للمتابعة المباشرة' : 'Live tracking link copied'),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Active Members List
        Text(
          arabic ? 'الأصدقاء في الغرفة:' : 'Friends in Room:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: dark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),

        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: room.members.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final m = room.members[index];
              final color = _parseHexColor(m.avatarColor);
              final isMe = m.memberId == c.userId;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color,
                      child: Text(
                        (m.displayName.isNotEmpty ? m.displayName[0] : '؟'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                m.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: dark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E676).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    arabic ? 'أنا' : 'You',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                              if (m.isCreator) ...[
                                const SizedBox(width: 6),
                                const Text('★', style: TextStyle(color: Colors.amber, fontSize: 13)),
                              ],
                            ],
                          ),
                          Text(
                            m.isOnline
                                ? (arabic ? '🟢 متصل الآن' : '🟢 Online')
                                : (arabic ? '⚪ غير متصل' : '⚪ Offline'),
                            style: TextStyle(
                              fontSize: 11,
                              color: dark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${m.speedKmh.round()} ${arabic ? "كم/س" : "km/h"}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: WazeColors.cyan,
                          ),
                        ),
                        if (m.batteryPercent != null)
                          Text(
                            '${m.batteryPercent}% 🔋',
                            style: TextStyle(
                              fontSize: 10,
                              color: dark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // End / Leave Room Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: Icon(isCreator ? Icons.stop_circle_rounded : Icons.logout_rounded),
          label: Text(
            isCreator
                ? (arabic ? 'إنهاء الغرفة للجميع' : 'End Room for Everyone')
                : (arabic ? 'مغادرة الغرفة' : 'Leave Room'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () async {
            if (isCreator) {
              await c.endLiveRoom();
            } else {
              await c.leaveLiveRoom();
            }
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildNewRoomTabs(
    BuildContext context,
    AppController c,
    bool dark,
    bool arabic,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.groups_rounded, color: Color(0xFF00E676), size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    arabic ? 'دَرب شلّة — مشاركة الموقع المباشر' : 'Darb Convoy — Live Share',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: dark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    arabic ? 'للمشاوير الجماعية ومشاركة مسار الخريطة' : 'For group convoys and shared map tracks',
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
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 14),

        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00E676),
          unselectedLabelColor: dark ? Colors.white54 : Colors.black54,
          indicatorColor: const Color(0xFF00E676),
          tabs: [
            Tab(text: arabic ? 'إنشاء غرفة جديدة' : 'Create Room'),
            Tab(text: arabic ? 'الانضمام برمز (6 خانات)' : 'Join by 6-Char Code'),
          ],
        ),
        const SizedBox(height: 14),

        if (_errorMsg != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _errorMsg!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // User Display Name Field
        TextField(
          controller: _displayNameController,
          decoration: InputDecoration(
            labelText: arabic ? 'اسمك الذي يظهر للأصدقاء' : 'Your Display Name',
            hintText: arabic ? 'مثال: علي المنصوري' : 'e.g. Ali',
            prefixIcon: const Icon(Icons.person_rounded),
            filled: true,
            fillColor: dark ? const Color(0xFF141C2B) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),

        // Tabs Content
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            if (_tabController.index == 0) {
              return _buildCreateRoomForm(context, c, dark, arabic);
            } else {
              return _buildJoinRoomForm(context, c, dark, arabic);
            }
          },
        ),
      ],
    );
  }

  Widget _buildCreateRoomForm(
    BuildContext context,
    AppController c,
    bool dark,
    bool arabic,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: arabic ? 'اسم الغرفة أو المشوار' : 'Room Name',
            hintText: arabic ? 'مثال: موكب المنصور' : 'e.g. Mansour Convoy',
            prefixIcon: const Icon(Icons.drive_eta_rounded),
            filled: true,
            fillColor: dark ? const Color(0xFF141C2B) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),

        // Mode selector
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Center(child: Text(arabic ? '🚗 موكب شلّة' : '🚗 Convoy')),
                selected: _selectedMode == 'convoy',
                onSelected: (val) => setState(() => _selectedMode = 'convoy'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: Center(child: Text(arabic ? '🛡️ أمان العائلة' : '🛡️ Family Safety')),
                selected: _selectedMode == 'family',
                onSelected: (val) => setState(() => _selectedMode = 'family'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 🌟 Convoy Destination & Live Route Track Card
        _buildConvoyTrackCard(
          context: context,
          c: c,
          dark: dark,
          arabic: arabic,
          destinationLabel: c.destination?.label(arabic),
          isCreator: true,
          onChangeDestination: () => _pickConvoyDestination(context, c),
        ),
        const SizedBox(height: 12),

        // Duration Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              arabic ? 'مدة صلاحية الغرفة:' : 'Room Duration:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: dark ? Colors.white70 : Colors.black87),
            ),
            DropdownButton<int>(
              value: _selectedDurationMinutes,
              dropdownColor: dark ? WazeColors.darkCard : Colors.white,
              items: [
                DropdownMenuItem(value: 30, child: Text(arabic ? '30 دقيقة' : '30 mins')),
                DropdownMenuItem(value: 60, child: Text(arabic ? 'ساعة واحدة' : '1 hour')),
                DropdownMenuItem(value: 120, child: Text(arabic ? 'ساعتان' : '2 hours')),
                DropdownMenuItem(value: 240, child: Text(arabic ? '4 ساعات' : '4 hours')),
                DropdownMenuItem(value: 360, child: Text(arabic ? '6 ساعات' : '6 hours')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedDurationMinutes = val);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E676),
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _loading ? null : _handleCreate,
          child: _loading
              ? const CircularProgressIndicator(color: Colors.black)
              : Text(
                  arabic ? 'إنشاء الغرفة وبدء المشاركة 🚀' : 'Create Room & Start Share 🚀',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
        ),
      ],
    );
  }

  Widget _buildJoinRoomForm(
    BuildContext context,
    AppController c,
    bool dark,
    bool arabic,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: arabic ? 'رمز الغرفة (6 خانات أرقام وحروف)' : '6-Digit Code (Letters & Numbers)',
            hintText: 'K9X2B4',
            filled: true,
            fillColor: dark ? const Color(0xFF141C2B) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          arabic
              ? 'أدخل الرمز المكون من 6 أرقام أو حروف (سيتم رسم المسار المشترك فور الانضمام)'
              : 'Enter the 6-character room code (shared convoy track will sync automatically)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: dark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: WazeColors.cyan,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _loading ? null : _handleJoin,
          child: _loading
              ? const CircularProgressIndicator(color: Colors.black)
              : Text(
                  arabic ? 'انضمام للغرفة الآن 🚗' : 'Join Room Now 🚗',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
        ),
      ],
    );
  }

  /// Interactive Convoy Track & Destination Preview Card
  Widget _buildConvoyTrackCard({
    required BuildContext context,
    required AppController c,
    required bool dark,
    required bool arabic,
    required String? destinationLabel,
    required bool isCreator,
    required VoidCallback onChangeDestination,
  }) {
    final hasDest = destinationLabel != null && destinationLabel.isNotEmpty;
    final route = c.route;

    if (hasDest) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF0F251E) : const Color(0xFFEDFAF2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF00E676).withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.navigation_rounded, color: Color(0xFF00E676), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              arabic ? 'مسار الشلّة المشترك 🚗' : 'Shared Convoy Track 🚗',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        destinationLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: dark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (route != null)
                        Text(
                          '${(route.distanceMeters / 1000).toStringAsFixed(1)} ${arabic ? "كم" : "km"} • ${c.duration(route.durationSeconds)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: dark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isCreator)
                  TextButton(
                    onPressed: onChangeDestination,
                    child: Text(
                      arabic ? 'تغيير' : 'Change',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: WazeColors.cyan),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // "Peek Track on Map" button (collapses sheet to 22% so user can inspect live OpenGL map)
            InkWell(
              onTap: _collapseSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map_rounded, size: 16, color: Color(0xFF00E676)),
                    const SizedBox(width: 6),
                    Text(
                      arabic
                          ? 'معاينة المسار على الخريطة (تصغير اللوحة) 🗺️'
                          : 'Peek Track on Map (Minimize) 🗺️',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF00E676),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // No destination set yet -> Provide picker and quick Baghdad landmark chips
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF141E2E) : const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: WazeColors.cyan.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: WazeColors.cyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_location_alt_rounded, color: WazeColors.cyan, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arabic ? 'وجهة الموكب المشتركة' : 'Shared Convoy Destination',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: dark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      arabic ? 'حدد وجهة لرسم المسار لجميع أعضاء الغرفة' : 'Set a goal to draw the shared track for all members',
                      style: TextStyle(fontSize: 11, color: dark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Primary Search Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: WazeColors.cyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 9),
            ),
            icon: const Icon(Icons.search_rounded, size: 16),
            label: Text(
              arabic ? 'اختيار وجهة من البحث أو المحفوظات 🔍' : 'Pick Destination from Search 🔍',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
            onPressed: onChangeDestination,
          ),
          const SizedBox(height: 8),

          // Quick Baghdad Landmark Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                if (c.home != null) ...[
                  _buildQuickPlaceChip(context, c, c.home!, arabic ? '🏠 المنزل' : '🏠 Home'),
                  const SizedBox(width: 6),
                ],
                if (c.work != null) ...[
                  _buildQuickPlaceChip(context, c, c.work!, arabic ? '💼 العمل' : '💼 Work'),
                  const SizedBox(width: 6),
                ],
                if (c.saved.isNotEmpty) ...[
                  _buildQuickPlaceChip(context, c, c.saved.first, c.saved.first.label(arabic)),
                  const SizedBox(width: 6),
                ],
                ...demoPlaces.take(3).map((p) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildQuickPlaceChip(context, c, p, p.label(arabic)),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPlaceChip(
    BuildContext context,
    AppController c,
    Place place,
    String label,
  ) {
    return ActionChip(
      avatar: const Icon(Icons.place_rounded, size: 14, color: WazeColors.cyan),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      onPressed: () {
        c.chooseDestination(place);
        widget.onFitTrack?.call();
        if (mounted) setState(() {});
      },
    );
  }
}
