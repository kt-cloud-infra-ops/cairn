# Coding Style

## 핵심 규칙

| 규칙 | 설명 |
|------|------|
| **불변성 (CRITICAL)** | 새 객체 생성, 기존 객체 mutation 금지 |
| 파일 크기 | 200-400줄 권장, 800줄 MAX. feature/domain별 구성 |
| 함수 크기 | 50줄 이내 |
| 에러 처리 | try-catch 필수, user-friendly 메시지 |
| 입력 검증 | 모든 사용자 입력 validation 필수 |

## Java Code Style

| 항목 | 규칙 |
|------|------|
| 인코딩/새줄 | UTF-8, LF |
| 들여쓰기 | 하드탭 (4 spaces) |
| 최대 줄 너비 | 120자 |
| 중괄호 | K&R 스타일 |
| Naming | 클래스: PascalCase, 메서드/변수: camelCase, 상수: UPPER_SNAKE_CASE |
| 접두사 | Enum: E, Interface: I |
| 접미사 | Entity, Configuration, Aspect |

## SRE Coding Rules

- 타임아웃: 모든 외부 호출에 필수
- 재시도: Transient 에러만, Exponential Backoff
- 로깅: 작업 시작/완료, 외부 API 호출, 에러 스택트레이스
- Health Check: 필수 구현

## Code Quality Checklist

- [ ] Code is readable and well-named
- [ ] Functions are small (<50 lines)
- [ ] Files are focused (<800 lines)
- [ ] No deep nesting (>4 levels)
- [ ] Proper error handling
- [ ] No console.log statements
- [ ] No hardcoded values
- [ ] No mutation (immutable patterns used)
