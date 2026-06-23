---
tags:
  - type/lesson
  - audience/team
  - service/luppiter
  - domain/java/spring
aliases: []
---

> 상위: [lessons](../../README.md) · [java](../README.md)

# Luppiter web 환경 분기 표준 (`server.mode` 패턴)

## 날짜
2026-05-28

## 세션/프로젝트
luppiter_web — TECHIOPS26-566 종합대시보드/센터별 대시보드 후속 작업

## 핵심 (CRITICAL)

**luppiter_web 은 Spring profile 을 사용하지 않는다.** 환경 분기는 커스텀 프로퍼티 `server.mode` + Maven profile 조합으로 한다. `environment.getActiveProfiles()` 로 분기하면 어떤 환경에서도 작동하지 않는다.

## 프로젝트 설정 사실

### application.properties

```properties
# spring.profiles.active=dev    ← 주석 처리되어 있음 (사용 안 함)
```

`application.properties:1` 라인이 주석 상태라는 점이 핵심. Spring profile 활성화 자체가 끊겨 있어서 `getActiveProfiles()` 는 빈 배열을 반환한다.

### 환경별 properties 파일과 server.mode 값

| 파일 | server.mode 값 |
|------|-----------------|
| `application-local.properties` | `LOCAL` |
| `application-stg.properties` | `STG` |
| `application-prd.properties` | `PROD` |
| `application-dev.properties` | (파일 없음 — Maven profile `dev` 가 어떤 properties 를 로드하는지 별도 확인 필요) |

### Maven profile

`pom.xml` 에 Maven profile `dev` (activeByDefault) / `prod` 가 정의되어 있다. 빌드 시 어떤 properties 파일을 패키징하는지를 결정하는 용도이며, Spring profile 과는 무관하다.

## 표준 분기 패턴

```java
@Value("${server.mode}")
private String serverMode;

private long resolveSomethingByEnv() {
    if ("STG".equalsIgnoreCase(serverMode) || "PROD".equalsIgnoreCase(serverMode)) {
        return PROD_VALUE;
    }
    return LOCAL_DEFAULT;
}
```

또는 `ServletInitializer` 가 부팅 시 `Constant.SERVER_MODE = serverMode` 로 전역 세팅하므로, 정적 상수로도 접근 가능.

```java
if ("STG".equalsIgnoreCase(Constant.SERVER_MODE)) { ... }
```

## 금지 패턴 (NEVER)

```java
// 작동하지 않음. spring.profiles.active 주석 처리 상태라 항상 빈 배열.
String[] profiles = environment.getActiveProfiles();
if (Arrays.asList(profiles).contains("prod")) { ... }   // ← 절대 실행 안 됨
```

`@Profile("prod")` 같은 Spring annotation 기반 분기도 같은 이유로 미작동.

## 기존 패턴 참조처 (4 + 1곳)

신규 분기 추가 시 아래 코드의 패턴을 그대로 따른다.

- `DatabaseConfiguration` — DB 커넥션 풀 환경 분기
- `ItamDatabaseConfiguration` — ITAM DB 환경 분기
- `DcimDatabaseConfiguration` — DCIM DB 환경 분기
- `ServletInitializer` — `Constant.SERVER_MODE` 전역 세팅 (부팅 시)
- `CtlRestController` — Controller 레벨 분기 사례

## 사고 사례 (TECHIOPS26-566 후속, 2026-05-27~28)

### 1차 오류
센터별 대시보드 autoplay 주기를 환경 분기로 다르게 두려고 `environment.getActiveProfiles()` 사용 → stg 배포 후에도 5초 주기로 동작 (빈 배열 → else 분기 진입).

### 정정
`DashboardController.resolveSpecificAutoplayIntervalMs()` 에서 `@Value("${server.mode}")` + `equalsIgnoreCase("STG"|"PROD")` 비교로 변경.

| 환경 | autoplay 주기 |
|------|---------------|
| STG / PROD | 5분 (300000ms) |
| LOCAL / dev | 5초 (5000ms) |

### 결과
- develop `0a74a80b`, stage `8c51494f`
- stg 배포 후 autoplay 5분 정상 작동 사용자 확인

## 비교 기준 브랜치 주의 (부속 교훈)

- TECHIOPS26-566 본체가 이미 develop 에 머지된 상태였기 때문에 develop 은 더 이상 "기존 대시보드" 가 아니었음
- 회귀 비교 시 진짜 "기존" 은 `production` (또는 `main`) 브랜치
- luppiter_web 회귀 검증 전에 **비교 대상 브랜치를 먼저 확인** 하고, 어떤 변경이 어디까지 들어가 있는지 git log 로 검증한다

## AI 에이전트용 점검 순서

1. 환경 분기 코드 추가/수정 요청이 들어오면 **먼저 `application.properties` 의 `spring.profiles.active` 가 주석인지** 확인
2. 주석이면 `server.mode` 패턴 강제
3. 신규 코드 작성 시 위 "기존 패턴 참조처" 4+1곳 중 1곳을 그대로 따라간다
4. `getActiveProfiles()` / `@Profile` / `@ConditionalOnProperty(name = "spring.profiles.active")` 류를 새로 도입하지 않는다
5. 변경 후에는 stg/prd 중 하나라도 실배포 검증을 거친다 (로컬·dev 만으로는 분기 자체가 확인되지 않음)

## 적용 가능한 상황

- 환경별 autoplay/타이머/배치 주기 분기
- 환경별 외부 API endpoint 분기
- 환경별 로그 레벨/디버그 토글
- 환경별 알림 채널 분기 (Slack 등)
- 환경별 feature toggle (단, 가능한 한 DB 기반 토글로 대체)

## 관련 문서

- [code-review-traps.md](code-review-traps.md)
- [luppiter-permission-cte-zero-row.md](../db/luppiter-permission-cte-zero-row.md) — 같은 luppiter_web 의 회귀 패턴 사례
