---
name: code-review
description: "코드 리뷰 + 커밋 전 검증. 보안/품질/도메인 정합성 검토 + 언어별 점검 + 커밋 단위 판정 + .harness/review-evidence.json 생성. 모든 git commit 전 의무 호출 (guard-git-commit.sh 강제)."
---

## 스킬 규칙
### ALWAYS
- 도메인 에이전트 먼저 읽기: `agents/subagents/{서비스}/`
- 피처 문서 검색: `docs/features/` — 이미 판정된 항목 재지적 금지
- 보안 체크리스트, Cross-cutting 8항목, Cross-layer 데이터 흐름 추적
- kt cloud 시큐어 코딩 가드레일 (`agents/rules-on-demand/security.md`)
- 언어별 점검: `references/language-checklist.md`
- 리포트 출력: `references/report-template.md` 6단 형식
- 커밋 단위 판정: 목적 단일성 (`agents/rules/git-workflow.md` 기능 단위 분리 기준)
- **commit 전 `.harness/review-evidence.json` 생성 의무** — guard-git-commit.sh가 본 파일 검증
- `git diff --cached` 기준으로 판단 (staged 변경만)
- 검사 중 코드 수정 발생 시 lint/정적분석/테스트 **재실행**

### NEVER
- 피처 문서에서 이미 판정된 항목 재지적 금지
- 오픈소스 라이선스 GPL/AGPL/LGPL 허용 금지
- 검사 실패 무시하고 evidence 생성 금지
- `.harness/review-evidence.json` 없이 commit 진행 금지 (hook 강제 차단)
- lint/포맷 자동 수정은 **사용자 명시 요청 시에만** (기본 OFF, `dev-build-fix` 옵트인)
- 한글 conventional commit type 사용 금지 (영문 `feat/fix/refactor/docs/test/chore/rules/commands` 유지)
- Jira 티켓 키 없는 메시지 제안 금지 (코드/서비스 관련 변경 시)

## 실행 절차

1. **변경 범위 파악**
   - `git status --short` + `git diff --cached`
   - working tree vs staged 다르면 **staged 기준**
   - 파일/라인 변경량 + 영향 영역 식별

2. **도메인/피처 사전 참조**
   - 변경 파일 → 서비스 판별 → `agents/subagents/{서비스}/` 읽기
   - `docs/features/{TICKET}-*.md` 검색 → 이미 판정된 항목 식별
   - **이미 판정된 항목 재지적 금지**

3. **언어별 품질 점검** (`references/language-checklist.md` 참조)
   - Java/JSP/JS/SQL/기타 — 변경 파일 확장자/경로로 섹션 선택
   - lint/정적분석/테스트 도구 존재 시 실행
   - 실패 시 자동 수정 여부 판단:
     - 단순 포맷/타입 누락 → 사용자 명시 요청 시 `dev-build-fix` 옵트인 호출
     - 로직 변경 필요 → 이상 리포트 작성 후 commit 중단

4. **클린코드 점검**
   - 함수 50줄 / 파일 800줄 이내
   - 불변성 (mutation 금지) — CRITICAL
   - 임시 코드/주석/디버그 출력 0건
   - 레이어 경계 위반 없음
   - 리팩터링 커밋이면 동작 변경 0건

5. **보안 점검** (`agents/rules-on-demand/security.md`)
   - 시크릿 노출 (토큰/비밀번호/키/세션)
   - 입력 검증 / 권한 체크 / SQL injection / 경로 조작
   - 에러 응답 내부 구조 노출 금지
   - kt cloud 가드레일 (Pbkdf2/Jasypt/RFC 7807/Tika/Spring Security 6.x)

6. **Cross-cutting 8항목 + Cross-layer 데이터 흐름** (`agents/rules-on-demand/impact-analysis.md`)

7. **커밋 단위 판정**
   - 목적 단일성 검사 (`agents/rules/git-workflow.md` 기능 단위 분리 기준)
   - 혼재 조합 발견 시: 기능+버그수정 / 로직+포맷 / 보안+일반 / 문서+코드
   - 혼재 시 분리안 제시 (`references/report-template.md` "커밋 분리 권고" 양식)

8. **리뷰 결과 작성** (`references/report-template.md`)
   - 정상: 6단 정상 리포트 + 제안 commit 메시지 (영문 + Jira 티켓 + Co-Authored-By)
   - 이상: 6단 이상 리포트 + commit 중단
   - 분리 권고: 커밋 분리 권고 양식

9. **evidence 저장** (정상 시에만)
   - `.harness/review-evidence.json` 생성
   - 스키마: `references/report-template.md` "evidence JSON 형식" 절 참조
   - staged 파일 SHA + 검사 결과 + commitPurpose + timestamp

10. **commit 진행 안내**
    - 사용자에게 정상 리포트 + 제안 메시지 출력
    - 사용자 승인 시 `git commit -m "..."` 실행
    - guard-git-commit.sh가 evidence 검증 → 통과 시 commit 성공

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] CRITICAL/HIGH 이슈 0건 (또는 전부 수정)
- [ ] [MANUAL] 보안 체크리스트 통과
- [ ] [MANUAL] 도메인 에이전트 교차 확인 완료
- [ ] [FILE] `.harness/review-evidence.json` 생성 (스키마 검증 통과)
- [ ] [GATE] 커밋 단위 목적 단일성 확인 (혼재 시 분리 권고)
- [ ] [MANUAL] 제안 commit 메시지 = 영문 conventional + Jira 티켓 + Co-Authored-By

## 참조

- `references/language-checklist.md` — Java/JSP/JS/SQL 언어별 점검 매트릭스
- `references/report-template.md` — 6단 리포트 + 분리 권고 + evidence JSON 스키마
- `agents/rules/git-workflow.md` — 기능 단위 커밋 분리 기준 + Runtime/Non-runtime + Jira 티켓 + 머지 순서
- `agents/rules-on-demand/security.md` — kt cloud 시큐어 코딩 가드레일
- `agents/rules-on-demand/coding-style.md` — 불변성/함수 크기/파일 크기
- `agents/rules-on-demand/impact-analysis.md` — Cross-cutting 8항목 + Cross-layer 데이터 흐름
- `agents/skills/dev-build-fix/SKILL.md` — lint/포맷 자동 수정 (옵트인)
- `.claude/hooks/guard-git-commit.sh` — commit 강제 차단 hook (evidence 검증)

## 스킬 간 관계

```
[코드 변경 완료]
    ↓
harness-orchestrator GATE 0 (dev branch 판정)
    ↓
harness-dev-process Phase 3 VERIFY
    ↓
dev-code-review (이 스킬) — review + evidence 생성
    ↓
.harness/review-evidence.json 저장
    ↓
harness-dev-process Phase 4 SHIP — commit 실행
    ↓
guard-git-commit.sh — evidence 검증 → 통과 시 commit
    ↓
push/PR
```

## Origin

| 항목 | 값 |
|------|----|
| 흡수 시점 | 2026-05-19 |
| 외부 출처 | 팀원 제안 `review-and-commit` SKILL.md |
| 흡수 판정 | MERGE (skill-governance.md Step 2: 60~70% 중복 → 기존 스킬 확장) |
| 흡수 가치 | 언어별 점검 매트릭스 / 6단 리포트 템플릿 / 커밋 단위 판정 / evidence 기반 강제 |
| 우리 룰 보강 | Jira 티켓 필수 / kt cloud 가드레일 / 도메인 에이전트 선행 / 영문 conventional / 자동 수정 옵트인 / Co-Authored-By |
| 제외 | 한글 commit type / 자동 lint 적용 / 무조건 commit 호출 (ADR-008 우회 위험) |
| ADR | [ADR-008](../../../base/guides/decisions/008-orchestrator-mandatory.md) — orchestrator 의무 통과 |
