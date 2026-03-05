# 패치노트 작성

최근 git 커밋 내역을 기반으로 사용자용 패치노트를 생성한다.

## 실행 절차

### 1. 최근 커밋 내역 조회
```bash
git -C /c/Users/user/Desktop/mini-project/recipe log --oneline -20
```

### 2. 변경 파일 분석
```bash
git -C /c/Users/user/Desktop/mini-project/recipe diff HEAD~5..HEAD --name-only
```

### 3. 패치노트 생성

조회된 커밋 내역을 분석하여 다음 형식으로 작성한다:

```
## 해먹당 업데이트 — vX.X (YYYY-MM-DD)

### 새 기능
- ...

### 개선
- ...

### 버그 수정
- ...
```

규칙:
- 사용자 관점에서 이해할 수 있는 한국어로 작성
- 기술적 내부 변경(리팩토링, DB 마이그레이션 등)은 생략
- 사용자에게 영향 있는 변경만 포함
- 완료 후 `docs/CHANGELOG.md`에 추가 (없으면 생성)

## 주의
- 배포 전 `docs/CHANGELOG.md`에 기록해두면 Render 배포 시 참조 가능
- 버전 번호는 major(기능 대거 추가).minor(기능 추가).patch(버그수정) 규칙
