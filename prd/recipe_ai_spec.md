# 입맛 저격 레시피 AI (가칭) 프로젝트 명세서

## 🥗 프로젝트: 입맛 저격 레시피 AI (가칭)

## 🛠 1. 최종 기술 스택 (Updated)

| 구분         | 추천 기술         | 이유                                                                         |
| :----------- | :---------------- | :--------------------------------------------------------------------------- |
| **Frontend** | Flutter (Web/App) | 추후 앱 출시까지 고려 + 협업하기 좋은 크로스 플랫폼.                         |
| **Backend**  | FastAPI (Python)  | Gemini API 호출 및 입맛 패턴 분석 로직 구현에 최적화.                        |
| **Database** | Supabase (Cloud)  | Auth(로그인), DB, 스토리지 통합 제공. `pgvector`로 향후 맛 유사도 검색 가능. |
| **AI 모델**  | Gemini 1.5 Flash  | 유튜브 멀티모달 분석(영상/오디오) 및 레시피 구조화 성능 탁월.                |
| **Library**  | yt-dlp, Pydantic  | 유튜브 추출 및 레시피 데이터 규격화(Validation)용.                           |

---

## 📋 2. 상세 요구사항 (Requirements)

### 1단계: 레시피 수집 및 AI 구조화

- **유튜브 파싱**: URL 입력 시 `yt-dlp`를 통해 영상 정보 및 자막/오디오 추출.
- **원본 레시피 생성**: Gemini가 추출된 정보를 바탕으로 `[재료, 용량, 단계, 기본 맛 지표]` JSON 생성.

### 2단계: 사용자 커스텀 및 검증 (New!)

- **레시피 편집**: AI가 가져온 원본 레시피의 재료 용량이나 순서를 사용자가 UI에서 직접 수정 가능.
- **맛있는 레시피 등록**: 요리 후 만족스러운 레시피를 **[맛있는 레시피 🌟]**로 등록.
- **Ground Truth 확보**: 사용자가 커스텀하여 '맛있음'을 찍은 데이터는 개인 입맛 분석의 핵심 지표로 활용.

### 3단계: 입맛 패턴화 및 제안 (핵심 지능)

- **패턴 분석**: '맛있는 레시피'들의 공통된 간(짠맛, 단맛 등)의 특징을 분석하여 사용자 프로필 업데이트.
- **자동 최적화**: 새로운 유튜브 URL 입력 시, 사용자의 패턴에 맞춰 *"진형님 입맛에는 간장 1스푼을 빼는 게 맛있어요"*라고 자동 제안.

---

## 🗄 3. 데이터베이스 설계 (Supabase 스키마)

```sql
-- 1. 원본 레시피 저장 (AI 추출본)
CREATE TABLE recipes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text,
  source_url text,
  base_recipe jsonb, -- {ingredients: [], steps: [], flavor: {}}
  created_at timestamp with time zone DEFAULT now()
);

-- 2. 사용자 커스텀 및 맛 보관함 (핵심 테이블)
CREATE TABLE user_recipes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id),
  recipe_id uuid REFERENCES recipes(id),
  custom_recipe jsonb, -- 사용자가 수정한 레시피 버전
  is_delicious boolean DEFAULT false, -- '맛있는 레시피' 체크 여부
  my_tip text, -- 나만의 꿀팁 메모
  updated_at timestamp with time zone DEFAULT now()
);

-- 3. 사용자 입맛 프로필
CREATE TABLE taste_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id),
  preferred_saltiness float, -- 1.0 ~ 5.0
  preferred_sweetness float,
  preferred_spiciness float,
  dislike_ingredients text[] -- 기피 재료
);
```

---

## 🎯 4. 실행 계획 (Action Plan)

1.  **DB 뼈대 만들기**: 위 SQL을 Supabase SQL Editor에 실행하여 테이블 생성.
2.  **AI 로직 개발 (Python)**: 유튜브 오디오 추출 → Gemini 전달 → 규격화된 JSON 수신 로직 완성.
3.  **UI 개발 (Flutter/Web)**: 커스텀 에디터(수정 가능한 리스트 형태)와 '맛있는 레시피' 등록 버튼 구현.
4.  **패턴 매칭 구현**: 사용자의 `taste_profiles`와 레시피의 `flavor` 지표를 비교해 증감 수치를 계산하는 알고리즘 작성.

---

## 💡 다음 단계!

이제 설계도는 완벽하게 업데이트되었습니다. 바로 코딩에 들어가신다면, **유튜브 URL에서 레시피를 JSON으로 뽑아주는 파이썬 백엔드 코드**를 먼저 짜보시는 게 어떨까요?

원하신다면 **FastAPI와 Gemini를 연동한 첫 번째 API 코드**를 작성해 드릴 수 있습니다. 시작해 볼까요? 마우마우! 🐭🦾
