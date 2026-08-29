# Phase 0: 문서 정리 및 baseline 점검

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/prd.md` — 제품 요구사항. "v0 스코프 결정" 섹션이 핵심: tech-critic-lead 게이트를 거쳐 온보딩 캐러셀과 브러시 보정 UI를 다음 버전으로 미뤘다.
- `docs/flow.md` — v0 화면 흐름 5개(메인/사진선택/화면경계확인/처리/결과) + 에러 화면.
- `docs/data-schema.md` — `@AppStorage` 2개뿐, DB 없음.
- `docs/code-architecture.md` — 레이어 구성, `Screen` enum(5-케이스), 서비스 3개, 에러 처리(Vision 예외 + degenerate 둘 다 같은 에러 화면으로).
- `docs/ade.md` — 기술적 결정 근거 전체 (자동 검출 신뢰 안 함, UI 제외 크롭, 기울기 반영 배치, 이미지 방향 처리 주의 등).
- `docs/testing.md` — 테스트 전략과 케이스 목록.
- `docs/user-intervention.md` — 사람이 해야 하는 항목 (소셜 검증, App Store 제출, 아이콘 제작).

이 phase는 "이전 phase 산출물"이 없다 — task의 첫 phase다.

## 작업 내용

위 7개 문서를 다시 훑으면서 아래 기준으로 v0 스코프와 일치하는지 확인하고, 어긋나는 부분이 있으면 **해당 문서를 직접 수정**하라:

1. `docs/prd.md`, `docs/flow.md`, `docs/code-architecture.md`에 "8개 화면"이라는 표현이나 온보딩 캐러셀·브러시 보정을 v0 기능인 것처럼 서술한 부분이 남아있지 않은가. 있다면 "다음 버전" 항목으로 옮기거나 삭제하라.
2. `docs/flow.md`의 화면 목록이 정확히 5개(메인/사진선택/화면경계확인/처리/결과)이고, 에러 화면(재시도 단일 버튼)이 Vision 예외와 degenerate 마스크 두 경우 모두를 처리한다고 명시돼 있는가.
3. `docs/code-architecture.md`의 `Screen` enum이 `main, boundaryConfirm, processing, result, error(String)` 5케이스인가.
4. `docs/testing.md`의 케이스 수가 실제와 맞는가 — ScreenQuad 2, PhoneFrameDetector 2, SubjectSegmenter 7, PopOutCompositor 3, CreationFlowViewModel 5.
5. `docs/user-intervention.md`의 시장 조사 항목이 "경쟁 없음"이 아니라 "경쟁 존재 + Peekpop 차별점(무계정·무료·온디바이스·실사진 보존)"으로 서술돼 있는가.

불일치를 찾으면 그 문서를 고쳐라. 코드는 아직 없으므로(Phase 1부터 시작) 이 phase는 문서만 다룬다.

## Acceptance Criteria

```bash
grep -n "8개 화면\|8화면" docs/prd.md docs/flow.md docs/code-architecture.md
# 위 grep이 매칭되는 줄이 있다면 전부 5개 화면 기준으로 수정한 뒤 재실행 — 최종적으로 매칭 없어야 함(exit code 1)

grep -n "brushRefine\|onboarding" docs/code-architecture.md
# 매칭되는 줄이 있다면 "다음 버전"/"v0 범위 밖" 문맥에서만 등장해야 함 — Screen enum 정의부에는 없어야 함
```

## AC 검증 방법

위 두 grep 커맨드를 실행하라. 첫 번째는 매칭 없음(exit code 1)이 기대값이다. 두 번째는 매칭이 있어도 되지만, 그 줄이 "v0 범위 밖"/"다음 버전" 문맥인지 직접 읽고 확인하라 (`Screen enum` 정의 코드 블록 안에 `brushRefine`이 남아있으면 실패). 두 조건 다 만족하면 `tasks/0-mvp-v0/index.json`의 phase 0 status를 `"completed"`로 변경하라. 문서 수정을 3회 이상 시도해도 두 조건을 못 맞추면 status를 `"error"`로 바꾸고 `error_message`에 어느 문서의 어느 부분이 안 맞는지 기록하라.

## 주의사항

- 이 phase에서 코드를 작성하지 마라 — 문서만 다룬다.
- 문서 내용을 v0 스코프와 다르게(예: 온보딩을 다시 넣는 방향으로) 바꾸지 마라. 목적은 "v0 스코프와 일치시키기"이지 스코프를 재논의하는 게 아니다.
