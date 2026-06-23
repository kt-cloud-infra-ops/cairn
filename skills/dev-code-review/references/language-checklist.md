# 언어별 코드 리뷰 체크리스트

`dev-code-review` 스킬의 보조 참조. staged 변경 파일의 확장자/경로로 해당 언어 섹션을 로드.

> Origin: 팀원 제안 `review-and-commit` 스킬에서 흡수 (MERGE — `agents/rules/skill-governance.md` Step 2). 우리 룰 정합성을 위해 kt cloud 가드레일 / Jira 티켓 / Runtime 분리 + 영문 conventional commit으로 재작성.

## 공통 (모든 언어)

- [ ] lint 도구 존재 여부 확인 → 있으면 실행
- [ ] 정적 분석 도구 존재 여부 확인 → 있으면 실행
- [ ] 테스트 명령 존재 여부 확인 → 있으면 실행
- [ ] 실패한 검사 무시하고 커밋 금지
- [ ] 자동 수정(lint/포맷)은 **사용자 명시 요청 시에만** 적용 (`dev-build-fix` 옵트인)
- [ ] 검사 미실행 / 결과 불명확 → 이상 리포트 작성 후 commit 중단

---

## Java / Spring Boot

### 빌드/정적 분석
- [ ] Gradle 기준: `./gradlew build test` 통과
- [ ] `ktlint`/`detekt`/`spotbugs`/`checkstyle` 도구 존재 시 실행
- [ ] 컴파일 경고 0건

### 코드 품질
- [ ] 함수 50줄 이내 (`agents/rules-on-demand/coding-style.md`)
- [ ] 파일 200~400줄 권장, 800줄 MAX
- [ ] 불변성 — 새 객체 생성, mutation 금지 (CRITICAL)
- [ ] null 안전성 — `Optional` 또는 `@Nullable` 명시
- [ ] 예외 처리 — try-catch 필수, user-friendly 메시지
- [ ] 트랜잭션 범위 — `@Transactional` 위치 + propagation 확인
- [ ] JPA 지연 로딩 영향 — N+1 query 위험 검토
- [ ] 컬렉션 처리 — `Stream` 남용 vs for 가독성 trade-off

### 보안 (kt cloud 가드레일 — `agents/rules-on-demand/security.md`)
- [ ] 패스워드 암호화 = `Pbkdf2PasswordEncoder` (BCrypt 금지)
- [ ] 시크릿 = Jasypt + 환경변수 (하드코딩 금지)
- [ ] 에러 응답 = `@ControllerAdvice` + RFC 7807 (스택트레이스 노출 금지)
- [ ] 파일 업로드 = Apache Tika MIME 검증 (확장자만 검사 금지)
- [ ] Spring Security 6.x (Jakarta EE) + CSRF 명시적 활성화
- [ ] 로그에 토큰/세션/비밀번호 노출 없음

### SRE
- [ ] 외부 호출 타임아웃 설정
- [ ] 재시도 = Transient 에러만, Exponential Backoff
- [ ] Health Check 엔드포인트 존재

---

## JSP / jQuery (Luppiter)

### 코드 품질
- [ ] XSS — 사용자 입력 렌더링 시 `<c:out>` 또는 escape 적용
- [ ] hidden field 신뢰 금지 (서버 사이드 검증 필수)
- [ ] AJAX 응답 처리 — 에러 분기 누락 없음
- [ ] TUI Grid / AG Grid 셀렉터 정확성
- [ ] `$.ajax` 타임아웃 명시
- [ ] include popup — caller 화면 의존성 확인 (`agents/rules-on-demand/current-state-analysis-harness.md`)

### 도메인 정합성
- [ ] 도메인 준수 규칙 사전 확인 (`agents/rules-on-demand/luppiter/`; 도메인 에이전트 본체는 [미생성])
- [ ] 피처 문서 사전 확인 (`docs/features/{TICKET}-*.md`)
- [ ] **이미 판정된 항목 재지적 금지**

---

## JavaScript / TypeScript

### 빌드/정적 분석
- [ ] `eslint` 실행 → 0 error
- [ ] `tsc --noEmit` 실행 → 0 error
- [ ] 테스트 명령 (jest/vitest) 통과
- [ ] 번들 빌드 가능 여부

### 코드 품질
- [ ] `any` 남용 없음 — unknown + type narrowing 우선
- [ ] 타입 단언(`as Foo`) 남용 없음 — type guard 우선
- [ ] dead code 없음
- [ ] 비동기 예외 — try/catch 또는 `.catch()` 누락 없음
- [ ] 미처리 Promise 없음
- [ ] 자동 수정(`eslint --fix`/`prettier --write`)은 옵트인만

### 프론트엔드
- [ ] 사용자 입력 렌더링 → XSS 방지 (React: `dangerouslySetInnerHTML` 사용 시 sanitize)
- [ ] 권한 조건 누락 없음
- [ ] CSRF 토큰 포함

---

## SQL / DB 변경

### 실행 안전성
- [ ] 실행 순서 명시 (DDL → DML → 권한)
- [ ] rollback 스크립트 작성
- [ ] 대량 갱신/삭제 조건 누락 없음 (`WHERE` 절 검증)
- [ ] 인덱스 영향 분석 (EXPLAIN 결과)
- [ ] 락 범위 — long transaction 회피

### Cross-cutting (`agents/rules-on-demand/impact-analysis.md`)
- [ ] 기존 JOIN 패턴 — 새 데이터가 기존 조회에서 누락되지 않음
- [ ] 공통코드/매핑 테이블 등록
- [ ] 권한 체계 필터 포함
- [ ] 엑셀/리포트/대시보드 집계 쿼리 반영
- [ ] 빈 문자열 vs NULL 구분 (`nvl()`, `COALESCE()`)
- [ ] UNION ALL 상수 컬럼 출력 검증

### 운영 적용
- [ ] **운영 데이터 직접 영향 → 별도 커밋 분리 필수**
- [ ] Luppiter inventory_master 변경 시 `inventory_master_sub` 동반 검토 (`agents/knowledge/lessons/db/luppiter-inventory-master-sub-rules.md`)

---

## 출처

- 외부 제안: `review-and-commit` 스킬 (팀원 작성, 2026-05-19)
- 흡수 결정: ADR-008 정합 + skill-governance.md Step 2 (60~70% 중복 → MERGE)
- 핵심 가치: 언어별 점검 매트릭스 (우리 기존 자산 부재)
- 우리 룰 보강: Jira 티켓 필수 / kt cloud 가드레일 / 도메인 에이전트 선행 참조 / 자동 수정 옵트인
