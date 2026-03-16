# 웹-앱 UI 동기화 가이드

> 작성일: 2026-03-16 | Frontend-QA 에이전트
> 웹(SvelteKit)과 Flutter 앱의 UI 차이점을 페이지/컴포넌트별로 정리하고, 앱에서 수정해야 할 사항을 구체적으로 기술한다.

---

## 1. 탐색 페이지 (Explore)

### 웹 (`frontend/src/routes/+page.svelte`)
- 검색바(height:44px, border-radius:14px, cream 배경) + 우측 "필터" 텍스트 버튼
- **소스 필터 칩** → **카테고리 칩** → **상황 태그 칩** (3단 구조)
- 상황 태그: `#간편식`, `#특별한날`, `#야식`, `#다이어트`, `#해장` (# 접두사, 작은 칩 스타일)
- 활성 필터 배지: 각 필터를 X 버튼으로 개별 해제 가능
- "오늘 뭐먹지" 배너 + **"냉장고 파먹기" 배너** (2개 배너)
- 카드: `border-radius: 14px`, 북마크 버튼 `top:6px right:6px`, `width:30px`
- 카드 메타: 시간 + **난이도** + 칼로리
- 그리드: `grid-template-columns: repeat(auto-fill, minmax(180px, 1fr))`
- 페이지네이션: "더 보기" 버튼 (무한 스크롤 아님)
- 스켈레톤 로딩: 6개 카드 shimmer 애니메이션

### 앱 (`mobile/lib/features/explore/explore_page.dart`)
- 검색바 + 필터 버튼: 거의 동일
- 소스 필터 칩 + 카테고리 칩 (2단 구조)
- **상황 태그 칩 없음**
- 활성 필터 배지: 동일 구현
- "오늘 뭐먹지" 배너만 있음, **냉장고 파먹기 배너 없음**
- 카드: `RecipeCard` 위젯 사용, `borderRadius: 14`
- 카드 메타: 시간 + 칼로리 (**난이도 표시 없음**)
- 그리드: `crossAxisCount: 2`, `childAspectRatio: 0.70`
- 페이지네이션: 무한 스크롤 (스크롤 200px 전 로드)
- 로딩: CircularProgressIndicator (스켈레톤 아님)

### 차이점 및 수정 사항

| # | 차이점 | 우선순위 |
|---|--------|----------|
| 1 | **상황 태그 칩 미구현**: 웹은 소스 칩 아래에 `#간편식 #특별한날 #야식 #다이어트 #해장` 태그 칩이 있음. 앱에는 없음 | **높음** |
| 2 | **냉장고 파먹기 배너 미구현**: 웹은 "오늘 뭐먹지" 아래에 냉장고 파먹기 배너가 있음 | 중간 |
| 3 | **카드에 난이도 미표시**: 웹은 `meta-chip`에 난이도(쉬움/보통/어려움) 표시. 앱 `RecipeCard._MetaChip`에는 시간+칼로리만 있음 | **높음** |
| 4 | **스켈레톤 로딩 미구현**: 웹은 6개 shimmer 카드, 앱은 단순 CircularProgressIndicator | 중간 |
| 5 | **카드 클릭 시 동작 차이**: 웹은 비보관 레시피도 `/recipe/{id}` 상세 이동. 앱은 "내 레시피에 추가한 뒤 볼 수 있어요" 스낵바만 표시 | **높음** |
| 6 | **"더 보기" vs 무한 스크롤**: 웹은 "더 보기" 버튼, 앱은 자동 무한 스크롤. 이건 앱 UX가 더 나으므로 **유지** | - |

#### 구체적 수정 지침

**1. 상황 태그 칩 추가** (`explore_page.dart`)
- `_CategoryChips` 아래에 `_TagChips` 위젯 추가
- 태그 목록: `['간편식', '특별한날', '야식', '다이어트', '해장']`
- `ExploreFilter`에 `List<String> tags` 필드 추가 또는 별도 `StateProvider<List<String>>` 생성
- 칩 스타일: `#태그명`, `borderRadius: 16`, `fontSize: 12.5`, `padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4)`
- 선택 시: `primaryColor` 배경 + 흰 텍스트

**2. 카드에 난이도 표시** (`recipe_card.dart`)
- `RecipePublicItem` 모델에 `difficulty` 필드 확인
- `_MetaChip` Wrap에 난이도 칩 추가:
  ```dart
  if (recipe.difficulty != null)
    _MetaChip(
      icon: Icons.bar_chart,
      label: {'easy': '쉬움', 'medium': '보통', 'hard': '어려움'}[recipe.difficulty] ?? recipe.difficulty!,
    ),
  ```

**3. 탐색 상세 페이지 구현 (비보관 레시피)**
- `/recipe/{id}` 라우트 추가, 공개 레시피 상세 표시
- 또는 임시로 "내 레시피에 추가" 후 자동 이동 처리

---

## 2. 필터 바텀시트 (FilterBottomSheet)

### 웹 (`frontend/src/lib/components/FilterBottomSheet.svelte`)
- 섹션: **정렬** (인기순/최신순/칼로리 낮은순) → **난이도** → **조리시간** → **칼로리** → **상황 태그** (12개) → **저장 숨김 토글**
- 상황 태그 12개: `간편식, 다이어트, 야식, 손님접대, 특별한날, 해장, 도시락, 아이반찬, 혼밥, 술안주, 브런치, 명절`
- 토글: 커스텀 CSS 토글 (44x24px)
- 적용 버튼: "적용하기" (height: 48px)

### 앱 (`mobile/lib/features/explore/filter_bottom_sheet.dart`)
- 섹션: **정렬** (최신순/인기순/평점순) → **난이도** → **조리시간** → **칼로리** → **저장 숨김 Switch**
- **상황 태그 섹션 없음**
- 정렬 옵션 차이: 웹에 "칼로리 낮은순" 있음, 앱에 "평점순" 있음
- Switch: Material Switch 컴포넌트

### 차이점 및 수정 사항

| # | 차이점 | 우선순위 |
|---|--------|----------|
| 1 | **상황 태그 섹션 미구현**: 웹은 12개 태그 선택 가능, 앱에는 없음 | **높음** |
| 2 | **정렬 옵션 차이**: 웹은 `인기순/최신순/칼로리 낮은순`, 앱은 `최신순/인기순/평점순` | 중간 |
| 3 | **적용 버튼 텍스트 차이**: 웹은 "적용하기", 앱은 "적용 (N)" (필터 수 표시) — 앱이 더 나음, **유지** | - |

#### 구체적 수정 지침

**1. 상황 태그 섹션 추가** (`filter_bottom_sheet.dart`)
- 칼로리 섹션과 저장 숨김 사이에 상황 태그 Wrap 추가
- `ExploreFilter`에 `List<String> tags` 필드 추가
- 태그 12개: `['간편식', '다이어트', '야식', '손님접대', '특별한날', '해장', '도시락', '아이반찬', '혼밥', '술안주', '브런치', '명절']`
- 선택/해제 토글 동작

**2. 정렬에 "칼로리 낮은순" 추가**
- `options`에 `('calories', '칼로리 낮은순')` 추가

---

## 3. 내 레시피 페이지 (My Recipes)

### 웹 (`frontend/src/routes/my-recipes/+page.svelte`)
- 검색바: sticky, cream 배경
- **소스 필터 칩** (전체/YouTube/직접 작성)
- **필터 탭**: 전체(N) / 즐겨찾기 / 카테고리별 / **태그별** (가로 스크롤)
- 카드 그리드: `minmax(160px, 1fr)`, RecipeCard 컴포넌트 (즐겨찾기 토글 가능)
- 필터 조건 없을 때: "필터 초기화" 버튼

### 앱 (`mobile/lib/features/my_recipes/my_recipes_page.dart`)
- 검색바: TextField
- **소스 필터 칩** + **즐겨찾기 칩** (한 줄)
- **카테고리 탭 없음, 태그 탭 없음**
- 카드: `_CollectionCard` (별점, 요리 횟수, 카테고리 배지 표시)
- 그리드: `crossAxisCount: 2`, `childAspectRatio: 0.72`

### 차이점 및 수정 사항

| # | 차이점 | 우선순위 |
|---|--------|----------|
| 1 | **카테고리 필터 탭 미구현**: 웹은 한식/양식/분식 등 카테고리로 필터링 가능 | 중간 |
| 2 | **태그 필터 탭 미구현**: 웹은 사용자 태그(손님초대/주말요리 등)로 필터링 가능 | 중간 |
| 3 | **검색 시 재료명 검색 미확인**: 웹은 제목+재료명 동시 검색 | 낮음 |
| 4 | **"전체(N)" 카운트 미표시**: 웹은 전체 탭에 레시피 수 배지 표시 | 낮음 |

#### 구체적 수정 지침

**1. 카테고리/태그 필터 행 추가**
- 소스+즐겨찾기 칩 아래에 카테고리 칩 행 추가
- 태그 API (`/tags`) 호출하여 태그 칩도 표시
- `myRecipesProvider` 필터에 카테고리, 태그 조건 추가

---

## 4. 레시피 상세 페이지 (Recipe Detail)

### 웹 (`frontend/src/routes/my-recipes/[id]/+page.svelte`)
- 유튜브 영상 카드 (VideoCard 컴포넌트)
- **편집 모드**: 재료/단계/꿀팁 인라인 편집 + 원본 복원
- **태그 관리**: TagBadge + TagPopover (태그 부착/제거/생성)
- **별점**: StarRating 컴포넌트 (클릭으로 설정)
- **요리 기록**: "요리했어요" 버튼 → cookedCount 증가
- **재분석**: YouTube 레시피 재분석 기능
- **삭제**: 확인 후 삭제
- **AI FAB**: AiAssistantFab (채팅 패널)
- **재료 담기**: IngredientList 내 장바구니 담기 버튼
- **ScrollToTop**: 스크롤 맨 위로 버튼
- **맛 프로필 차트**: FlavorProfile 컴포넌트 (5축 바 차트)
- 하단: `calc(90px + env(safe-area-inset-bottom))` 패딩

### 앱 (`mobile/lib/features/recipe_detail/recipe_detail_page.dart`)
- SliverAppBar (썸네일 확장형)
- **편집**: EditRecipeSheet (바텀시트)
- **즐겨찾기**: AppBar 아이콘
- **장바구니 담기**: AppBar 아이콘
- **AI FAB**: AiFab (floating action button)
- **"요리 시작" 버튼**: bottomNavigationBar에 고정
- 재료: 카테고리별 그룹핑
- 조리 순서: 번호 원형 + 설명 + 타이머

### 차이점 및 수정 사항

| # | 차이점 | 우선순위 |
|---|--------|----------|
| 1 | **태그 관리 미구현**: 웹은 태그 부착/제거/새 태그 생성 가능. 앱에 없음 | 중간 |
| 2 | **별점 설정 미구현**: 웹은 StarRating으로 클릭 설정. 앱은 읽기 전용 표시만 | **높음** |
| 3 | **요리 기록 버튼 미구현**: 웹은 "요리했어요" 버튼. 앱은 표시만(N회 요리함) | **높음** |
| 4 | **맛 프로필 차트 미구현**: 웹은 FlavorProfile 바 차트(5축). 앱에 없음 | 중간 |
| 5 | **유튜브 영상 카드 미구현**: 웹은 VideoCard(임베드 플레이어). 앱에 없음 | 중간 |
| 6 | **재분석 기능 미구현**: 웹은 YouTube 레시피 재분석 가능. 앱에 없음 | 낮음 |
| 7 | **삭제 기능 미구현**: 웹은 확인 후 삭제. 앱에 없음 | **높음** |
| 8 | **공개/비공개 토글 미구현**: 웹 편집 모드에서 is_public 토글 가능. 앱에 없음 | 낮음 |
| 9 | **"요리 시작" 버튼 앱 고유**: 앱 하단에 고정. 웹에는 쿠킹 모드 미구현. **유지** | - |

#### 구체적 수정 지침

**1. 별점 설정 위젯** (`recipe_detail_page.dart`)
- `_DetailView`에 인터랙티브 StarRating Row 추가
- GestureDetector로 각 별 탭 → `apiService.setRating(collectionId, rating)` 호출
- `ref.invalidate(collectionItemProvider(collectionId))` 갱신

**2. "요리했어요" 버튼 추가**
- 재료/조리순서 사이 또는 하단에 "요리했어요 (N회)" 버튼
- `apiService.recordCooked(collectionId)` 호출

**3. 삭제 기능 추가**
- AppBar actions에 더보기(PopupMenuButton) → "삭제" 옵션
- 확인 다이얼로그 후 `apiService.deleteFromCollection(collectionId)` → 뒤로 이동

**4. 맛 프로필 차트 추가**
- 이미 마이페이지에 `_RadarChart` 있음 → 재사용 또는 별도 바 차트 위젯
- `recipe.flavor` 데이터가 있을 때만 표시

---

## 5. 바텀 네비게이션 (BottomNav / MainShell)

### 웹 (`frontend/src/lib/components/BottomNav.svelte`)
- 5탭: 탐색 / 내 레시피 / [+] / 장바구니 / 마이
- [+] 버튼: 52px 원형, terracotta 배경, 위로 -16px 돌출, box-shadow
- 분석 중: pulsing 애니메이션 + spinner
- 높이: `60px + safe-area`
- 쿠킹 모드/OAuth 콜백에서 숨김

### 앱 (`mobile/lib/shared/widgets/main_shell.dart`)
- 5탭: 동일 구조
- [+] 버튼: 48px 원형 (웹 52px보다 작음), primaryColor 배경
- **분석 중 상태 미구현** (spinner/pulsing 없음)
- 기본 Material BottomNavigationBar 사용
- **돌출 효과 없음** (웹은 margin-top: -16px로 돌출)

### 차이점 및 수정 사항

| # | 차이점 | 우선순위 |
|---|--------|----------|
| 1 | **[+] 버튼 크기**: 웹 52px vs 앱 48px | 낮음 |
| 2 | **[+] 버튼 돌출 효과 없음**: 웹은 -16px 위로 돌출 + 그림자 | 중간 |
| 3 | **분석 중 상태 미구현**: 웹은 pulsing glow + spinner 표시 | 중간 |
| 4 | **아이콘 차이**: 웹은 SVG 커스텀 아이콘, 앱은 Material Icons | 낮음 |

#### 구체적 수정 지침

**1. [+] 버튼 돌출 효과**
- `BottomNavigationBar` 대신 커스텀 위젯으로 교체 고려
- 또는 현재 구조에서 [+] icon을 `Transform.translate(offset: Offset(0, -8))` + `BoxDecoration(boxShadow)` 적용
- 크기: 52x52로 변경

---

## 6. 마이페이지 (My)

### 웹 (`frontend/src/routes/my/+page.svelte`)
- **프로필**: 아바타(80px 원형) + 이름 + 이메일 (중앙 정렬, 세로 배치)
- **입맛 분석**: 수평 바 차트 (5축, 각 축에 색상+수치), 통계 칩 3종(즐겨찾기/총 요리/평균 별점), 자주 만드는 카테고리
- **먹당이 채팅**: 미리보기 카드 (아바타 + 인사말 + "대화 시작하기" 버튼) → MeokdangChatSheet
- **로그아웃**: 전체 폭 아웃라인 버튼

### 앱 (`mobile/lib/features/my/my_page.dart`)
- **프로필**: CircleAvatar(72px) + 이름 + 이메일 (가로 Row 배치)
- **입맛 분석**: 통계 칩 Row (레시피/즐겨찾기/요리함/평균별점) + **레이더 차트** (웹은 바 차트)
- **먹당이 채팅**: ListTile 메뉴 아이템 (카드 아닌 리스트 항목)
- **내 레시피 / 장바구니**: ListTile 바로가기 (웹에 없음, 바텀네비에서 이동)
- **로그아웃**: ListTile (붉은색 텍스트)

### 차이점 및 수정 사항

| # | 차이점 | 우선순위 |
|---|--------|----------|
| 1 | **프로필 레이아웃**: 웹은 중앙 세로, 앱은 좌측 가로 Row | 중간 |
| 2 | **입맛 차트 형태**: 웹은 수평 바 차트(값 표시), 앱은 레이더 차트 — **각각 유지 가능** | 낮음 |
| 3 | **통계 칩 구성**: 웹은 즐겨찾기/총 요리/평균 별점 3개. 앱은 레시피/즐겨찾기/요리함/평균 별점 4개 — 앱이 더 풍부, **유지** | - |
| 4 | **먹당이 채팅 UI**: 웹은 미리보기 카드(인사말+버튼), 앱은 단순 ListTile | 중간 |
| 5 | **"자주 만드는 카테고리" 미구현**: 웹은 top_category 표시. 앱에 없음 | 낮음 |
| 6 | **데이터 부족 시 placeholder**: 웹은 blur 처리된 바 + 안내 텍스트. 앱은 텍스트 안내만 | 낮음 |

#### 구체적 수정 지침

**1. 먹당이 카드 스타일 개선**
- ListTile 대신 `Container`로 카드 형태 (creamColor 배경, borderRadius: 16)
- 먹당이 아바타 + 인사말 + "대화 시작하기" 버튼 배치
- `meokdang.png` 이미지 사용 (없으면 이모지 폴백)

**2. 프로필 레이아웃 (선택적)**
- 웹처럼 중앙 정렬 세로 배치로 변경 또는 현재 Row 유지 (취향)

---

## 7. 장바구니 (Cart)

### 웹 (`frontend/src/routes/cart/+page.svelte`)
- **sticky 헤더**: 제목 + "선택 삭제(N)" + "전체 비우기"
- **요약바**: "총 N개 재료" + 체크 수
- **그룹 접기/펼치기**: 클릭으로 토글, 화살표 아이콘
- **체크박스**: 커스텀 SVG (terracotta 색)
- **재료 카테고리 배지**: 각 항목 우측에 카테고리 칩
- **하단 구매 바**: sticky, "선택만 구매" + "전체 구매" 버튼
- **레시피 링크**: 그룹 헤더에 "레시피 →" 링크

### 앱 (`mobile/lib/features/cart/cart_page.dart`)
- **AppBar**: 제목 + PopupMenuButton (구매한 항목 삭제 / 전체 비우기)
- **요약바 없음**
- **그룹 접기/펼치기 없음**: 항상 펼쳐진 상태
- **체크박스**: Material Checkbox
- **재료 카테고리 배지 없음**
- **하단 구매 바 없음**
- **레시피 링크 없음**

### 차이점 및 수정 사항

| # | 차이점 | 우선순위 |
|---|--------|----------|
| 1 | **그룹 접기/펼치기 미구현**: 웹은 그룹 헤더 클릭으로 토글 | 중간 |
| 2 | **요약바 미구현**: 웹은 총 N개 + 체크 수 표시 | 중간 |
| 3 | **하단 구매 바 미구현**: 웹은 sticky 하단 바 (선택 구매 / 전체 구매) | **높음** |
| 4 | **재료 카테고리 배지 미구현**: 웹은 각 항목에 카테고리 칩 | 낮음 |
| 5 | **레시피 링크 미구현**: 웹은 그룹 헤더에서 레시피 상세로 이동 가능 | 중간 |
| 6 | **체크 시 시각적 차이**: 웹은 이름+수량 opacity 0.4, 앱은 취소선+softBrown 색 | 낮음 |

#### 구체적 수정 지침

**1. 하단 구매 바 추가**
- `Scaffold.bottomNavigationBar`에 구매 바 위젯 배치
- "선택만 구매 (N)" + "전체 구매" 버튼
- terracotta 색 버튼

**2. 그룹 접기/펼치기**
- `ExpansionTile` 또는 직접 상태 관리로 그룹 토글 구현
- 그룹 헤더에 레시피 제목 + 아이템 수 + "레시피 →" 링크

---

## 8. RecipeCard (공유 컴포넌트)

### 웹 (탐색 `.recipe-card`)
- `border-radius: 14px`, `border: 1px solid lightLine`
- hover: `box-shadow + translateY(-1px)`
- 썸네일: 16:9, 카테고리 배지(하단 좌측, 반투명 검정 배경)
- 북마크 버튼: 상단 우측, 30px 원형, 반투명 흰 배경, 보관 시 terracotta 배경
- 제목: 2줄 말줄임, `font-size: 0.85rem`
- 메타 칩: 시간(SVG 시계) + 난이도 + 칼로리(주황)
- 채널명: YouTube 아이콘 + 이름, 텍스트 레시피는 "✏ 직접 작성"

### 앱 (`mobile/lib/shared/widgets/recipe_card.dart`)
- `borderRadius: 14`, `border: lightLineColor` — 동일
- 썸네일: 16:9, 카테고리 배지(하단 좌측) — 동일
- 북마크 버튼: 상단 우측, 30px 원형 — 동일
- 제목: 2줄 말줄임, `fontSize: 13` (웹 0.85rem ≈ 13.6px — 거의 동일)
- 메타 칩: 시간 + 칼로리 (**난이도 없음**)
- 채널명: YouTube "▶" + 이름, "✏ 직접 작성" — 동일

### 수정 사항

| # | 차이점 | 우선순위 |
|---|--------|----------|
| 1 | **난이도 칩 누락** (위 1번 탐색과 동일) | **높음** |
| 2 | **CachedNetworkImage**: 앱은 이미 캐시 사용 — 웹보다 나음, **유지** | - |

---

## 9. 색상/테마 비교

### 웹 CSS 변수 vs 앱 `theme.dart`

| CSS 변수 | 웹 값 | 앱 상수 | 앱 값 | 일치 |
|----------|-------|---------|-------|------|
| `--color-primary` / `--color-terracotta` | 추정 #C4704B~#E8623C | `primaryColor` | `#E8623C` | 확인 필요* |
| `--color-paper` | 추정 #FFFDF8 | `paperColor` | `#FFFDF8` | OK |
| `--color-cream` | 추정 #F5EFE6 | `creamColor` | `#F5EFE6` | OK |
| `--color-soft-brown` | 추정 #8B6F5E | `softBrownColor` | `#8B6F5E` | OK |
| `--color-warm-brown` / `--color-dark` | 추정 #2C1810 | `darkColor` | `#2C1810` | OK |
| `--color-light-line` | 추정 #EAE0D5 | `lightLineColor` | `#EAE0D5` | OK |

> *참고: 웹의 `--color-terracotta`와 `--color-primary`가 동일한지 확인 필요. 앱은 `#E8623C` 하나로 통일됨.

---

## 우선순위 요약

### 높음 (즉시 수정 필요)
1. **탐색 카드에 난이도 표시** — `recipe_card.dart` 수정
2. **상황 태그 칩** — `explore_page.dart` + `filter_bottom_sheet.dart` 수정
3. **탐색 상세 페이지 (비보관)** — 새 라우트 또는 자동 보관 후 이동
4. **레시피 상세: 별점 설정** — `recipe_detail_page.dart` 수정
5. **레시피 상세: 요리 기록 버튼** — `recipe_detail_page.dart` 수정
6. **레시피 상세: 삭제 기능** — `recipe_detail_page.dart` 수정
7. **장바구니: 하단 구매 바** — `cart_page.dart` 수정

### 중간
8. 냉장고 파먹기 배너
9. 스켈레톤 로딩
10. 필터: 정렬에 "칼로리 낮은순" 추가
11. 내 레시피: 카테고리/태그 필터
12. 레시피 상세: 태그 관리, 맛 프로필 차트
13. 바텀네비: [+] 버튼 돌출 효과 + 분석 중 상태
14. 마이페이지: 먹당이 카드 스타일
15. 장바구니: 그룹 접기/펼치기 + 요약바 + 레시피 링크

### 낮음
16. 바텀네비: 아이콘 커스터마이징
17. 마이페이지: 프로필 레이아웃, 자주 만드는 카테고리
18. 장바구니: 재료 카테고리 배지, 체크 시 스타일
