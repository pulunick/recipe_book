import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../features/add_recipe/add_recipe_sheet.dart';
import '../providers/analysis_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  OverlayEntry? _popupEntry;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/my-recipes')) return 1;
    if (location.startsWith('/cart')) return 3;
    if (location.startsWith('/my')) return 4;
    return 0;
  }

  void _onAddTap(BuildContext context, bool isAnalyzing) {
    if (isAnalyzing) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withAlpha(80),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: primaryColor,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '분석 중이에요!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: warmBrownColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '얼른 분석해서 보여드릴게요 🍳\n잠시만 기다려주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: softBrownColor, height: 1.5),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: creamColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                          color: warmBrownColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      _showAddSheet(context);
    }
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddRecipeSheet(
        onSaved: (collectionId) => context.push('/my-recipes/$collectionId'),
      ),
    );
  }

  void _showResultPopup(AnalysisState state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final overlay = Navigator.of(context, rootNavigator: true).overlay;
      if (overlay == null) return;

      _popupEntry?.remove();
      _popupEntry = null;

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) => _AnalysisResultPopup(
          success: state.status == AnalysisStatus.done,
          recipeTitle: state.recipeTitle,
          errorMessage: state.errorMessage,
          onDismiss: () {
            entry.remove();
            ref.read(analysisProvider.notifier).dismiss();
          },
          onGoTo: state.status == AnalysisStatus.done && state.collectionId != null
              ? () {
                  entry.remove();
                  ref.read(analysisProvider.notifier).dismiss();
                  context.push('/my-recipes/${state.collectionId}');
                }
              : null,
        ),
      );
      _popupEntry = entry;
      overlay.insert(entry);

      Future.delayed(const Duration(seconds: 5), () {
        if (entry.mounted) {
          entry.remove();
          if (mounted) ref.read(analysisProvider.notifier).dismiss();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 분석 완료/오류 시 팝업 표시
    ref.listen<AnalysisState>(analysisProvider, (prev, next) {
      final prevIdle = prev?.status != AnalysisStatus.analyzing;
      if (!prevIdle && (next.status == AnalysisStatus.done || next.status == AnalysisStatus.error)) {
        _showResultPopup(next);
      }
    });

    final analysisState = ref.watch(analysisProvider);
    final isAnalyzing = analysisState.isAnalyzing;
    final currentIndex = _currentIndex(context);
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        height: 60 + bottomPadding,
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: lightLineColor, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: '탐색',
                isActive: currentIndex == 0,
                onTap: () => context.go('/'),
              ),
              _NavItem(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                label: '내 레시피',
                isActive: currentIndex == 1,
                onTap: () => context.go('/my-recipes'),
              ),
              // 중앙 [+] 버튼
              Expanded(
                child: GestureDetector(
                  onTap: () => _onAddTap(context, isAnalyzing),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -16),
                        child: isAnalyzing
                            ? AnimatedBuilder(
                                animation: _pulseAnim,
                                builder: (context, child) => Transform.scale(
                                  scale: _pulseAnim.value,
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withAlpha(180),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withAlpha(100),
                                          blurRadius: 18,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withAlpha(102),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 22),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.shopping_cart_outlined,
                activeIcon: Icons.shopping_cart,
                label: '장바구니',
                isActive: currentIndex == 3,
                onTap: () => context.go('/cart'),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: '마이',
                isActive: currentIndex == 4,
                onTap: () => context.go('/my'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 22,
                color: isActive ? primaryColor : softBrownColor,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isActive ? primaryColor : softBrownColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 분석 완료/오류 팝업 (Overlay) ────────────────────────────
class _AnalysisResultPopup extends StatefulWidget {
  const _AnalysisResultPopup({
    required this.success,
    this.recipeTitle,
    this.errorMessage,
    required this.onDismiss,
    this.onGoTo,
  });
  final bool success;
  final String? recipeTitle;
  final String? errorMessage;
  final VoidCallback onDismiss;
  final VoidCallback? onGoTo;

  @override
  State<_AnalysisResultPopup> createState() => _AnalysisResultPopupState();
}

class _AnalysisResultPopupState extends State<_AnalysisResultPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _slide = Tween(begin: 12.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: 72 + bottomInset,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Opacity(
          opacity: _fade.value,
          child: Transform.translate(offset: Offset(0, _slide.value), child: child),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(36),
                    blurRadius: 32,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Text(widget.success ? '✅' : '❌',
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.success ? '레시피 분석 완료!' : '분석 실패',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: warmBrownColor),
                      ),
                      if (widget.success && widget.recipeTitle != null)
                        Text(
                          widget.recipeTitle!,
                          style: const TextStyle(fontSize: 12, color: softBrownColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (!widget.success && widget.errorMessage != null)
                        Text(
                          widget.errorMessage!,
                          style: const TextStyle(fontSize: 12, color: softBrownColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.success && widget.onGoTo != null) ...[
                  _popupBtn(label: '닫기', onTap: widget.onDismiss, isPrimary: false),
                  const SizedBox(width: 6),
                  _popupBtn(label: '보러 가기 →', onTap: widget.onGoTo!, isPrimary: true),
                ] else
                  _popupBtn(label: '닫기', onTap: widget.onDismiss, isPrimary: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _popupBtn({
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isPrimary ? primaryColor : Colors.transparent,
            border: isPrimary ? null : Border.all(color: lightLineColor, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Colors.white : softBrownColor,
            ),
          ),
        ),
      );
}
