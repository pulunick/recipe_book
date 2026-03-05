# Auth 로그인 시스템 명세

> 작성: Planner | 대상: Frontend-QA 구현용

---

## 1. 로그인 페이지 와이어프레임 (`/login`)

```
+--------------------------------------------+
|  [로고 해먹당]              [홈으로 돌아가기] |
+--------------------------------------------+
|                                            |
|                                            |
|         ┌──────────────────────┐           |
|         │                      │           |
|         │    🍳 해먹당 로고     │           |
|         │                      │           |
|         │  "나만의 AI 레시피북"  │           |
|         │                      │           |
|         │  ┌──────────────────┐│           |
|         │  │ [G] Google로 시작 ││           |
|         │  └──────────────────┘│           |
|         │                      │           |
|         │  로그인하면 레시피를   │           |
|         │  저장하고 관리할 수   │           |
|         │  있어요              │           |
|         │                      │           |
|         └──────────────────────┘           |
|                                            |
+--------------------------------------------+
```

### 디자인 가이드
- 배경: `var(--color-paper)` (#FAF8F5)
- 카드: 흰색 배경, `border-radius: 16px`, 미세한 그림자
- Google 버튼: 구글 공식 브랜드 가이드 준수 (흰색 배경, 구글 로고, 검은 텍스트)
- 로고: `/logo.png` 사용 (높이 80px)
- 설명 텍스트: `var(--color-soft-brown)`
- 전체 카드 최대 너비: 400px, 세로 중앙 정렬

---

## 2. 라우트 구조

### 2.1 `/login` — 로그인 페이지

**파일**: `frontend/src/routes/login/+page.svelte`

- Google OAuth 로그인 버튼 1개
- 이미 로그인 상태면 `/my-recipes`로 리디렉트
- 쿼리 파라미터 `?redirect=/my-recipes/3` 지원 (로그인 후 원래 가려던 페이지로 이동)

### 2.2 `/auth/callback` — OAuth 콜백 처리

**파일**: `frontend/src/routes/auth/callback/+page.svelte`

- Supabase OAuth 콜백 URL 해시 파싱 처리
- 성공 시: auth store 업데이트 → redirect 파라미터 또는 `/my-recipes`로 이동
- 실패 시: `/login?error=auth_failed`로 리디렉트

```svelte
<!-- 콜백 페이지 핵심 로직 -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { supabase } from '$lib/supabase';

  onMount(async () => {
    // Supabase가 URL hash에서 세션을 자동 파싱
    const { error } = await supabase.auth.getSession();
    if (error) {
      await goto('/login?error=auth_failed');
      return;
    }
    const redirect = page.url.searchParams.get('redirect') || '/my-recipes';
    await goto(redirect);
  });
</script>
```

---

## 3. Supabase 클라이언트 설정

**파일**: `frontend/src/lib/supabase.ts`

```typescript
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
```

### 환경 변수 (frontend/.env)
```
VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJ...
```

### 패키지 설치
```bash
cd frontend && npm install @supabase/supabase-js
```

---

## 4. Auth Store 설계

**파일**: `frontend/src/lib/stores/auth.svelte.ts`

Svelte 5 runes 기반 반응형 auth store:

```typescript
import { supabase } from '$lib/supabase';
import type { User, Session } from '@supabase/supabase-js';

// 반응형 상태
let user = $state<User | null>(null);
let session = $state<Session | null>(null);
let loading = $state(true);

// 초기화: 앱 시작 시 1회 호출
export async function initAuth() {
  const { data } = await supabase.auth.getSession();
  session = data.session;
  user = data.session?.user ?? null;
  loading = false;

  // 세션 변경 리스너
  supabase.auth.onAuthStateChange((_event, newSession) => {
    session = newSession;
    user = newSession?.user ?? null;
  });
}

// Google 로그인
export async function signInWithGoogle(redirectTo?: string) {
  const callbackUrl = `${window.location.origin}/auth/callback${redirectTo ? `?redirect=${encodeURIComponent(redirectTo)}` : ''}`;
  await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: callbackUrl }
  });
}

// 로그아웃
export async function signOut() {
  await supabase.auth.signOut();
  user = null;
  session = null;
}

// 읽기 전용 접근자
export function getUser() { return user; }
export function getSession() { return session; }
export function isLoading() { return loading; }
export function isLoggedIn() { return !!user; }
```

### +layout.svelte에서 초기화

```svelte
<!-- frontend/src/routes/+layout.svelte 수정 -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { initAuth } from '$lib/stores/auth.svelte';
  // ... 기존 import

  onMount(() => {
    initAuth();
  });
</script>
```

---

## 5. Navbar 변경사항

**파일**: `frontend/src/lib/components/Navbar.svelte`

### 현재 상태
- `로그인` 버튼이 있으나 기능 없음 (정적 버튼)

### 변경 사항

```
비로그인 시:
  [해먹당 로고]                    [내 레시피북] [로그인]

로그인 시:
  [해먹당 로고]                    [내 레시피북] [프로필 아바타 ▾]
                                                  ├─ 이름/이메일
                                                  └─ [로그아웃]
```

- **비로그인**: 기존 `로그인` 버튼 → 클릭 시 `/login`으로 이동
- **로그인**: 프로필 아바타 표시 (Google 프로필 이미지, 32px 원형)
  - 아바타 클릭 시 드롭다운 메뉴:
    - 사용자 이름 (또는 이메일)
    - `로그아웃` 버튼
  - 드롭다운 외부 클릭 시 닫힘

### 구현 요점
```svelte
<script lang="ts">
  import { getUser, isLoggedIn, signOut } from '$lib/stores/auth.svelte';
  // ...
  let showDropdown = $state(false);
  const user = $derived(getUser());
  const loggedIn = $derived(isLoggedIn());
</script>

<!-- 조건부 렌더링 -->
{#if loggedIn && user}
  <button class="avatar-btn" onclick={() => showDropdown = !showDropdown}>
    <img src={user.user_metadata.avatar_url} alt="프로필" class="avatar" />
  </button>
  {#if showDropdown}
    <div class="dropdown">
      <p class="dropdown-name">{user.user_metadata.full_name || user.email}</p>
      <button class="dropdown-item" onclick={signOut}>로그아웃</button>
    </div>
  {/if}
{:else}
  <a href="/login" class="login-btn">로그인</a>
{/if}
```

### 아바타 스타일
- 크기: 32px, `border-radius: 50%`
- 테두리: `2px solid var(--color-light-line)`
- hover: `border-color: var(--color-terracotta)`
- 드롭다운: 흰색 배경, 그림자, `border-radius: 12px`, 우측 정렬

---

## 6. 보호된 라우트 처리

### 보호 대상
- `/my-recipes` — 레시피북 리스트
- `/my-recipes/[id]` — 레시피 상세

### 공개 라우트
- `/` — 홈 (레시피 분석은 비로그인도 가능, 단 저장 시 로그인 필요)
- `/login` — 로그인 페이지
- `/auth/callback` — OAuth 콜백
- `/recipe/[id]` — 공개 레시피 보기 (fallback)

### 구현 방법: Layout 수준 가드

**파일**: `frontend/src/routes/my-recipes/+layout.svelte` (신규)

```svelte
<script lang="ts">
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { isLoggedIn, isLoading } from '$lib/stores/auth.svelte';

  let { children } = $props();

  const loggedIn = $derived(isLoggedIn());
  const authLoading = $derived(isLoading());

  $effect(() => {
    if (!authLoading && !loggedIn) {
      const currentPath = page.url.pathname;
      goto(`/login?redirect=${encodeURIComponent(currentPath)}`);
    }
  });
</script>

{#if authLoading}
  <div class="auth-loading">확인 중...</div>
{:else if loggedIn}
  {@render children()}
{/if}
```

### 홈페이지 저장 흐름 변경

`/` (홈)에서 분석 후 저장 시:
- 로그인 상태: 기존과 동일 (저장 → `/my-recipes/[id]`로 이동)
- 비로그인 상태: 분석은 완료, 저장 시도 시 `/login?redirect=/` 으로 리디렉트
  - 로그인 후 돌아오면 다시 URL 입력 필요 (MVP에서는 세션 유지 미구현)

---

## 7. API 호출 인증 토큰 전달

**파일**: `frontend/src/lib/api.ts` 수정

모든 API 호출에 Supabase 세션 토큰을 `Authorization` 헤더로 전달:

```typescript
import { getSession } from '$lib/stores/auth.svelte';

function getAuthHeaders(): Record<string, string> {
  const session = getSession();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json'
  };
  if (session?.access_token) {
    headers['Authorization'] = `Bearer ${session.access_token}`;
  }
  return headers;
}

// 기존 fetch 호출에서 headers를 getAuthHeaders()로 교체
// user_id 하드코딩 ('00000000-...') 제거 → 백엔드에서 토큰으로 사용자 식별
```

> **참고**: 백엔드 인증 미들웨어는 별도 Backend 팀 태스크로 진행 예정.
> 프론트엔드는 토큰 전달만 구현하면 됨.

---

## 8. 신규/수정 파일 목록

### 신규 파일
| 파일 | 설명 |
|------|------|
| `frontend/src/lib/supabase.ts` | Supabase 클라이언트 초기화 |
| `frontend/src/lib/stores/auth.svelte.ts` | Auth store (Svelte 5 runes) |
| `frontend/src/routes/login/+page.svelte` | 로그인 페이지 |
| `frontend/src/routes/auth/callback/+page.svelte` | OAuth 콜백 처리 |
| `frontend/src/routes/my-recipes/+layout.svelte` | 인증 가드 레이아웃 |

### 수정 파일
| 파일 | 변경 내용 |
|------|-----------|
| `frontend/src/routes/+layout.svelte` | `initAuth()` 호출 추가 |
| `frontend/src/lib/components/Navbar.svelte` | 로그인/로그아웃 UI, 아바타 드롭다운 |
| `frontend/src/lib/api.ts` | Authorization 헤더 추가, user_id 하드코딩 제거 |

### 패키지
```bash
npm install @supabase/supabase-js
```

---

## 9. Frontend-QA 구현 태스크 목록

아래 순서대로 구현 권장:

1. **`@supabase/supabase-js` 패키지 설치**
2. **`supabase.ts` 생성** — Supabase 클라이언트 초기화
3. **`auth.svelte.ts` 생성** — Auth store (initAuth, signInWithGoogle, signOut, 접근자 함수)
4. **`+layout.svelte` 수정** — onMount에서 initAuth() 호출
5. **`/login/+page.svelte` 생성** — 로그인 페이지 UI
6. **`/auth/callback/+page.svelte` 생성** — OAuth 콜백 처리
7. **`Navbar.svelte` 수정** — 로그인/로그아웃 조건부 UI, 아바타 드롭다운
8. **`/my-recipes/+layout.svelte` 생성** — 인증 가드
9. **`api.ts` 수정** — Authorization 헤더, user_id 동적 처리
10. **테스트** — 로그인 흐름 전체 검증

### 참고 사항
- Supabase 프로젝트에서 Google OAuth provider 설정은 사전에 완료되어 있다고 가정
- `.env` 파일에 `VITE_SUPABASE_URL`과 `VITE_SUPABASE_ANON_KEY` 필요
- 환경 변수가 없어도 빌드/타입체크가 깨지지 않도록 방어 코드 작성

---

## 10. 향후 확장 (이번 스코프 제외)

- Apple 로그인 추가 (디자인만 Google 옆에 배치 예정)
- 백엔드 인증 미들웨어 (JWT 검증)
- 프로필 설정 페이지
- 회원 탈퇴
