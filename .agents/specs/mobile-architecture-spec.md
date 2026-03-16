# 모바일 앱 아키텍처 명세 (Flutter)

## 개요

해먹당 Flutter 앱 — 기존 SvelteKit 웹앱과 **동일한 백엔드 API**를 사용하는 Android/iOS 앱.
웹 기능 전체 포팅 후 모바일 전용 기능(쿠킹 모드, 알림, 오프라인 등) 추가 예정.

---

## 기술 스택

| 항목 | 선택 | 이유 |
|------|------|------|
| SDK | Flutter 3.x (stable) | 크로스플랫폼, 기존 설치 확인 |
| 언어 | Dart 3.x | Flutter 기본 |
| 상태관리 | **Riverpod** (riverpod_annotation + hooks_riverpod) | 타입 안전, 의존성 주입 용이 |
| 라우팅 | **go_router** | Flutter 공식 권장, deep link 지원 |
| HTTP | **Dio** | 인터셉터, 취소, 에러 핸들링 용이 |
| 로컬 저장 | **shared_preferences** (간단 키값) + **Hive** (구조화) | 오프라인 캐시 대비 |
| i18n | **easy_localization** | arb 기반, 한국어/영어 분리 |
| 인증 | **supabase_flutter** | 기존 Supabase Auth 연동 |
| 이미지 | **cached_network_image** | 유튜브 썸네일 캐시 |
| 아이콘 | **lucide_icons** 또는 `Icons` 내장 | 웹과 일관성 |

---

## 프로젝트 구조

```
mobile/                          # 모노레포 내 Flutter 프로젝트
├── android/
├── ios/
├── lib/
│   ├── main.dart               # 앱 진입점
│   ├── app.dart                # MaterialApp + GoRouter 설정
│   ├── core/
│   │   ├── constants.dart      # API 베이스 URL, 앱 상수
│   │   ├── theme.dart          # 해먹당 테마 (색상, 타이포)
│   │   ├── dio_client.dart     # Dio 인스턴스 + 인터셉터
│   │   └── router.dart         # go_router 라우트 정의
│   ├── features/               # 기능별 모듈 (feature-first 구조)
│   │   ├── auth/               # 로그인 (Supabase OAuth)
│   │   ├── explore/            # 탐색 탭 (공개 레시피)
│   │   ├── my_recipes/         # 내 레시피
│   │   ├── recipe_detail/      # 레시피 상세
│   │   ├── cart/               # 장바구니
│   │   ├── my/                 # 마이페이지
│   │   ├── write/              # 텍스트 레시피 작성
│   │   ├── fridge/             # 냉장고 파먹기
│   │   └── cooking_mode/       # 쿠킹 모드 (Phase 2)
│   ├── shared/                 # 공통 위젯/유틸
│   │   ├── widgets/
│   │   ├── models/             # 데이터 모델 (freezed)
│   │   └── providers/          # 전역 Riverpod provider
│   └── l10n/                   # 번역 파일
│       ├── ko.json             # 한국어
│       └── en.json             # 영어 (해외판 대비)
├── test/
├── pubspec.yaml
└── README.md
```

---

## 라우팅 구조 (go_router)

| 경로 | 화면 | 비로그인 |
|------|------|----------|
| `/` | 탐색 (공개 레시피) | 허용 |
| `/my-recipes` | 내 레시피 서랍 | 리다이렉트 `/login` |
| `/my-recipes/:id` | 레시피 상세 | 리다이렉트 `/login` |
| `/my-recipes/:id/cook` | 쿠킹 모드 | 리다이렉트 `/login` |
| `/cart` | 장바구니 | 리다이렉트 `/login` |
| `/my` | 마이페이지 | 리다이렉트 `/login` |
| `/write` | 텍스트 레시피 작성 | 리다이렉트 `/login` |
| `/fridge` | 냉장고 파먹기 | 허용 |
| `/login` | 로그인 | — |

---

## 웹 → 모바일 기능 매핑

| 웹 기능 | 모바일 구현 방식 |
|---------|----------------|
| 탐색 탭 (카테고리/검색/필터) | 동일 API, ListView + SliverAppBar |
| 내 레시피북 | 동일 API, GridView |
| 레시피 상세 + 편집 | 동일 API, 전용 페이지 |
| AI FAB (요리 어시스턴트) | DraggableScrollableSheet |
| 장바구니 | 동일 API |
| 텍스트 레시피 작성 | 동일 API |
| 냉장고 파먹기 | 동일 API |
| Google OAuth | `supabase_flutter` SignInWithOAuth |
| 먹당이 채팅 | DraggableScrollableSheet |
| 쿠킹 모드 | 네이티브 WakeLock + 모바일 전용 UI |
| [+] 추가 버튼 | FAB 또는 바텀 모달 |

---

## 인증 흐름

```
앱 시작
  └─ SupabaseClient.auth.currentUser 확인
       ├─ null → /login (Google OAuth or 게스트 허용 라우트만)
       └─ 있음 → 정상 라우팅
           └─ supabase_flutter가 JWT 자동 갱신
```

백엔드 API 호출 시 Dio 인터셉터가 `Authorization: Bearer {jwt}` 자동 주입.

---

## 테마 — 웹 CSS 변수 대응

| CSS 변수 | Dart 색상 |
|----------|-----------|
| `--color-primary` (#E8623C) | `Color(0xFFE8623C)` |
| `--color-paper` (#FFFDF8) | `Color(0xFFFFFDF8)` |
| `--color-cream` (#F5EFE6) | `Color(0xFFF5EFE6)` |
| `--color-soft-brown` (#8B6F5E) | `Color(0xFF8B6F5E)` |
| `--color-dark` (#2C1810) | `Color(0xFF2C1810)` |

---

## 개발 환경

- **Flutter SDK**: 3.38.9 (stable, Windows 설치 확인)
- **Dart SDK**: 3.10.8
- **IDE**: VS Code + Flutter/Dart 플러그인
- **타겟**: Android 6.0+ (API 23+), iOS 13+
- **개발 기기**: Android Emulator / iOS Simulator + 실기기

---

## 구현 로드맵

### Phase 1 — 기본 탐색 + 인증
- [ ] Flutter 프로젝트 생성 (`mobile/`)
- [ ] 테마, 라우터, Dio 클라이언트 설정
- [ ] Supabase Flutter 인증 연동
- [ ] 탐색 탭 (공개 레시피 목록 + 카드)

### Phase 2 — 핵심 기능 포팅
- [ ] 내 레시피 서랍
- [ ] 레시피 상세 + 편집
- [ ] AI FAB (요리 어시스턴트)
- [ ] 장바구니
- [ ] 텍스트 레시피 작성

### Phase 3 — 모바일 전용 기능
- [ ] 쿠킹 모드 (화면 항상 켜짐, WakeLock)
- [ ] 냉장고 파먹기
- [ ] 먹당이 채팅
- [ ] 푸시 알림 (요리 완료 타이머 등)

---

## 담당

- **Mobile-Dev**: `mobile/` 전체 담당 (Flutter/Dart 구현)
- **Backend**: API 변경 필요 시만 (`backend/` 수정)
- **Planner**: 명세 검토, UX 방향 결정
