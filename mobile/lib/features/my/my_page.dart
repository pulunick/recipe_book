import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../shared/providers/auth_provider.dart';
import 'meokdang_chat_sheet.dart';

final tasteProfileProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(apiServiceProvider).getTasteProfile();
});

class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('마이')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline, size: 64, color: lightLineColor),
                const SizedBox(height: 12),
                const Text('로그인이 필요해요',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: warmBrownColor)),
                const SizedBox(height: 8),
                const Text(
                  '로그인하면 입맛 분석, 요리 통계 등\n다양한 기능을 이용할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: softBrownColor, height: 1.7),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/login'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('로그인하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final avatarUrl = user.userMetadata?['avatar_url'] as String?;
    final fullName = user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String? ??
        '사용자';

    // 이름에서 성 제거 (한국어)
    String displayName() {
      final parts = fullName.split(RegExp(r'\s+'));
      return parts.length > 1 ? parts.last : fullName;
    }

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 28),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
        children: [
          // 프로필 섹션 (중앙 정렬 - 웹과 동일)
          Column(
            children: [
              // 아바타
              CircleAvatar(
                radius: 40,
                backgroundColor: lightLineColor,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        fullName.isNotEmpty ? fullName[0] : '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Text(fullName,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: warmBrownColor)),
              const SizedBox(height: 4),
              Text(user.email ?? '',
                  style: const TextStyle(fontSize: 13, color: softBrownColor)),
            ],
          ),

          const SizedBox(height: 28),

          // 입맛 분석 섹션
          _SectionHeader(title: '내 입맛 취향'),
          const SizedBox(height: 10),
          _TasteProfileCard(ref: ref),

          const SizedBox(height: 20),

          // 먹당이 채팅 카드
          _SectionHeader(title: '먹당이와 대화하기'),
          const SizedBox(height: 10),
          _MeokdangCard(
            displayName: displayName(),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const MeokdangChatSheet(),
              );
            },
          ),

          const SizedBox(height: 20),

          // 로그아웃 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/');
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: lightLineColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('로그아웃',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: softBrownColor)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 섹션 헤더 ──────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: warmBrownColor));
  }
}

// ── 입맛 프로필 카드 (바 차트 - 웹과 동일) ────────────────
class _TasteProfileCard extends ConsumerWidget {
  const _TasteProfileCard({required this.ref});
  final WidgetRef ref;

  static const _axes = [
    ('saltiness', '짠맛', Color(0xFF6B9E6B)),
    ('sweetness', '단맛', Color(0xFFE8623C)),
    ('spiciness', '매운맛', Color(0xFFD94040)),
    ('sourness', '신맛', Color(0xFFF5C542)),
    ('oiliness', '기름진 맛', Color(0xFFA67C5B)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(tasteProfileProvider);

    return profileAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: creamColor,
          border: Border.all(color: lightLineColor, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: List.generate(5, (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 56, height: 10,
                  decoration: BoxDecoration(color: lightLineColor, borderRadius: BorderRadius.circular(5)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(color: lightLineColor, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ],
            ),
          )),
        ),
      ),
      error: (e, st) => const SizedBox.shrink(),
      data: (data) {
        final hasData = data['has_data'] as bool? ?? false;
        final profile = data['profile'] as Map<String, dynamic>? ?? {};
        final favoriteCount = data['favorite_count'] as int? ?? 0;
        final totalCooked = data['total_cooked'] as int? ?? 0;
        final avgRating = data['avg_rating'];
        final topCategory = data['top_category'] as String?;
        final recipeCount = data['recipe_count'] as int? ?? 0;

        if (!hasData) {
          // 데이터 부족 안내 카드
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: creamColor,
              border: Border.all(color: lightLineColor, width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // 흐릿한 바 차트
                ...List.generate(5, (i) {
                  final widths = [0.6, 0.45, 0.75, 0.3, 0.5];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(_axes[i].$2,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, color: softBrownColor)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: creamColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              widthFactor: widths[i],
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _axes[i].$3.withAlpha(64),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),
                const Text(
                  '레시피를 3개 이상 저장하고\n별점 또는 즐겨찾기를 남기면\n내 입맛을 분석해드릴게요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: softBrownColor, height: 1.7),
                ),
                if (recipeCount > 0) ...[
                  const SizedBox(height: 4),
                  Text('현재 $recipeCount개 저장됨',
                      style: TextStyle(fontSize: 12, color: softBrownColor.withAlpha(178))),
                ],
              ],
            ),
          );
        }

        // 데이터 있음: 실제 바 차트
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: lightLineColor, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // 바 차트
              ...List.generate(5, (i) {
                final key = _axes[i].$1;
                final value = (profile[key] as num?)?.toDouble() ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(_axes[i].$2,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12, color: softBrownColor)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: creamColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: (value / 5).clamp(0, 1),
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _axes[i].$3,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text(
                          value.toStringAsFixed(1),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: warmBrownColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // 통계 칩 3종 (웹과 동일)
              Row(
                children: [
                  _StatChip(label: '즐겨찾기', value: '$favoriteCount개', emoji: '⭐'),
                  const SizedBox(width: 8),
                  _StatChip(label: '총 요리', value: '$totalCooked회', emoji: '🍳'),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: '평균 별점',
                    value: avgRating != null
                        ? (avgRating as num).toDouble().toStringAsFixed(1)
                        : '-',
                    emoji: '★',
                  ),
                ],
              ),

              // 자주 만드는 카테고리
              if (topCategory != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withAlpha(50)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('자주 만드는 카테고리',
                          style: TextStyle(fontSize: 12.5, color: softBrownColor)),
                      Text(topCategory,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: primaryColor)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.emoji});
  final String label;
  final String value;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: creamColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 10.5, color: softBrownColor)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: warmBrownColor)),
          ],
        ),
      ),
    );
  }
}

// ── 먹당이 채팅 카드 (웹과 동일) ────────────────────────────
class _MeokdangCard extends StatelessWidget {
  const _MeokdangCard({required this.displayName, required this.onTap});
  final String displayName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: creamColor,
        border: Border.all(color: lightLineColor, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 먹당이 아바타
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF5E6C8),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/meokdang.png',
                fit: BoxFit.cover,
                errorBuilder: (ctx, e, st) => const Center(
                  child: Text('🥘', style: TextStyle(fontSize: 32)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('"$displayName~ 나랑 놀쟈 마우!!"',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: warmBrownColor)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('대화 시작하기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
