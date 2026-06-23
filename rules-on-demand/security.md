# Security Guidelines

## CRITICAL: 시큐어 코딩 가드레일

조직 보안 가이드 + 행안부 SW개발보안 가이드 + OWASP Top 10 기준.
AI 코드 생성 시 아래 규칙을 **강제 적용**한다.

> 근거: 조직 내 안전한 AI 코드 생성 가이드라인 (팀 Confluence/위키에서 참조)

### 패스워드 암호화

- **금지**: BCrypt, 단순 SHA-256 1회 해시
- **강제**: `Pbkdf2PasswordEncoder` (SHA-256 이상, Iteration 1만 회 이상)
- 근거: KISA 공인 알고리즘. BCrypt는 해외 통용이나 일부 보안 인증 심사에서 미인정될 수 있음

### 중요정보 보호 (Secret Management)

- **금지**: 소스코드 내 DB/API Key 평문 삽입 (하드코딩)
- **강제**: Jasypt 라이브러리 사용 (Secret Manager / 환경변수 연동)
- 모든 키 값은 소스코드에서 분리하고 암호화

```java
// NEVER: 하드코딩
String dbPassword = "mypassword123";

// ALWAYS: Jasypt + 환경변수
@Value("${db.password}")
private String dbPassword;  // application.yml에서 ENC(암호화값) 사용
```

### 에러 및 예외 처리

- **금지**: `e.printStackTrace()` (서버 경로, DB 구조, SQL 쿼리 노출)
- **강제**: `@ControllerAdvice` + RFC 7807 (Problem Details for HTTP APIs)
- 스택 트레이스 노출 원천 차단

### 파일 업로드 보안

- **금지**: 확장자 문자열만 단순 비교 (위장 파일 업로드 가능)
- **강제**: Apache Tika로 실제 MIME Type + Magic Number 교차 검증
- 웹셸 등 악성 실행 파일 업로드 차단

### 보안 프레임워크

- **금지**: Spring Security 5.x 이하 레거시 문법
- **강제**: Spring Security 6.x (Jakarta EE) + JWT 128bit 이상 + CSRF 방어 명시적 활성화

### 대외 오픈 탐지 게이트 (EXTERNAL GATE)

- AI 코드 생성은 **내부망/폐쇄망 전용 시스템** 구축을 전제로 허용
- 요구사항에 "대외 오픈", "공인 IP 연동", "외부 웹서버 구축" 문맥이 감지되면 **코드 생성 즉시 중단**
- 조직 내 보안성 검토 절차(보안팀) 안내 후 진행

### 오픈소스 라이선스

- **금지 (Anti-GPL)**: GPL, AGPL, LGPL — 소스코드 공개 의무 발생
- **허용 (화이트리스트)**: MIT, Apache 2.0, BSD
- 라이브러리 추가 시 라이선스 확인 필수
- `LATEST`, `RELEASE` 등 동적 버전 태그 금지 — 고정 버전만 사용

---

## Security Checklist (커밋 전 필수)

- [ ] No hardcoded secrets — Jasypt 또는 환경변수로 키 관리
- [ ] All user inputs validated
- [ ] SQL injection prevention (파라미터화 쿼리)
- [ ] XSS prevention (입력 새니타이징)
- [ ] CSRF protection enabled
- [ ] Authentication/authorization verified
- [ ] Rate limiting on all endpoints
- [ ] Error messages don't leak sensitive data (`e.printStackTrace()` 금지)
- [ ] 파일 업로드 시 Apache Tika MIME 검증
- [ ] 오픈소스 라이선스: MIT, Apache 2.0, BSD만 허용

## Security Response Protocol

If security issue found:
1. STOP immediately
2. Use **security-reviewer** agent
3. Fix CRITICAL issues before continuing
4. Rotate any exposed secrets
5. Review entire codebase for similar issues

