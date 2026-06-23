# Project Structure Standards (DRAFT)

> **status: draft** — 초안 단계. 팀 검토 후 확정 예정.
> 기준 템플릿: `kt-cloud-infra-ops/demo-backend-kt`, `kt-cloud-infra-ops/demo-frontend` (김정남 작성)

## CRITICAL: 에이전트 트리거

아래 상황에서 이 규칙을 자동 적용한다:

1. **새 서비스/프로젝트 생성** — `/create-service`, `/add-project` 실행 시
2. **프로젝트 구조 질문** — "모듈 구조", "패키지 구조", "프로젝트 템플릿" 키워드
3. **코드 스캐폴딩** — 새 Controller/Service/Repository/Entity 생성 시 네이밍 규칙 적용
4. **CI/CD 파이프라인 설정** — GitHub Actions, Docker, Harbor 관련 작업

---

## 표준 템플릿 저장소

| 역할 | 저장소 | 상태 |
|------|--------|------|
| 백엔드 | `kt-cloud-infra-ops/demo-backend-kt` | 활성 (is_template: true) |
| 프론트엔드 | `kt-cloud-infra-ops/demo-frontend` | 활성 (is_template: true) |

새 서비스 생성 시 GitHub "Use this template"으로 저장소를 생성하고 `rename-service.py`로 서비스명을 일괄 치환한다.

```bash
# 템플릿 복제 후 서비스명 치환 (루트에 위치)
python3 rename-service.py <새서비스명>
# "demo" → <새서비스명> 전체 파일/폴더/내용 일괄 치환
```

---

## 멀티모듈 구조 (백엔드)

```
{서비스명}/
├── {서비스명}-application/   # 공통 비즈니스 로직
│   └── src/main/kotlin/com/ktc/infraops/{서비스명}/
│       ├── entity/           # JPA Entity
│       ├── repository/       # Spring Data Repository
│       ├── service/          # 비즈니스 Service
│       └── config/           # JPA, DB 설정
│
├── {서비스명}-api/           # HTTP API 진입점
│   └── src/main/kotlin/com/ktc/infraops/{서비스명}/
│       ├── controller/
│       │   ├── internal/     # /api/v1/** (시스템 간 통신)
│       │   ├── public/       # /public-api/v1/** (공개 API)
│       │   ├── admin/        # /admin-api/v1/** (관리자)
│       │   └── dto/          # 요청/응답 DTO
│       ├── security/         # SecurityConfig, Filter, TokenStore
│       └── filter/           # RequestLoggingFilter 등
│
├── {서비스명}-batch/         # 배치 모듈 (선택)
│   └── src/main/kotlin/com/ktc/infraops/{서비스명}/
│
├── doc/
│   ├── ddl/                  # DB 스키마 DDL
│   ├── dml/                  # 샘플 데이터 DML
│   └── md/                   # 개발 가이드 문서
├── .github/workflows/        # CI/CD
├── Dockerfile
├── rename-service.py         # 서비스명 일괄 치환 스크립트
└── AGENTS.md                 # AI 에이전트 가이드 (필수)
```

### 모듈 의존성 방향 (CRITICAL)

```
{서비스명}-batch ──→ {서비스명}-application ←── {서비스명}-api
```

- `application`이 공통 허브 (Entity, Repository, Service, JPA Config)
- `api`와 `batch`는 `application`에만 의존 (단방향)
- `api` ↔ `batch` 간 직접 의존 금지

---

## 프로젝트 구조 (프론트엔드)

```
{서비스명}-frontend/
├── src/
│   ├── config/               # 환경 설정 (API base URL 등)
│   ├── global/               # 전역 공통
│   │   ├── component/        # 공통 컴포넌트 (PageDefault, PageSplit, TableDefault, TreeDefault)
│   │   ├── page/             # 전역 페이지 (404, 403)
│   │   └── utils/services/   # fetch 래퍼 (apiService.ts — 수정 금지)
│   ├── page/                 # 기능별 페이지 컴포넌트
│   │   └── {그룹}/{기능}/    # 예: sample/sampleUserDefault/
│   ├── services/             # API 서비스 레이어
│   │   └── {serviceName}/    # 서비스별 디렉토리
│   │       ├── {serviceName}.ts       # 서비스 구현
│   │       ├── {serviceName}Type.ts   # 타입 re-export 진입점
│   │       └── types/                 # 타입 정의
│   ├── App.tsx               # 앱 루트 (라우팅)
│   └── menu.tsx              # 사이드바 메뉴 + URL 라우팅 정의
├── doc/
│   └── md/                   # 개발 가이드 문서
├── .env                      # 환경 변수 (VITE_* 접두어)
├── rename-service.py         # 서비스명 일괄 치환 스크립트
└── AGENTS.md                 # AI 에이전트 가이드 (필수)
```

### 프론트엔드 핵심 규칙

| 규칙 | 설명 |
|------|------|
| **fetch 직접 호출 금지** | 페이지에서 직접 fetch 금지 — 반드시 서비스 함수 경유 |
| **타입 진입점** | `types/` 내부 파일 직접 import 금지 — `{serviceName}Type.ts` 경유 |
| **메뉴 등록** | 페이지 추가 후 반드시 `src/menu.tsx`에 등록 |
| **페이지 패턴** | `PageDefault` (단일 테이블) / `PageSplit` (좌측 트리 + 우측 테이블) |
| **apiService.ts** | `global/utils/services/apiService.ts` 수정 금지 |

---

## API URL 분류 (CRITICAL)

새 Controller 생성 시 반드시 아래 분류에 따라 배치한다.

| 분류 | URL prefix | 패키지 위치 | 인증 방식 | 용도 |
|------|-----------|-------------|----------|------|
| **internal** | `/api/v1/**` | `controller/internal/` | 시스템 토큰 (`X-API-TOKEN`) | 서비스 간 통신 |
| **public** | `/public-api/v1/**` | `controller/public/` | JWT (OAuth2) | 외부 공개 API |
| **admin** | `/admin-api/v1/**` | `controller/admin/` | JWT + 관리자 Role | 관리자 전용 |
| **system** | `/health`, `/actuator/**` | `controller/` | 없음 | 헬스체크, 모니터링 |

### 판별 기준

```
새 엔드포인트 생성 시:
├─ 다른 서비스가 호출? → internal (/api/v1)
├─ 외부 사용자/앱이 호출? → public (/public-api/v1)
├─ 관리자만 사용? → admin (/admin-api/v1)
└─ 시스템 운영용? → system (루트 또는 /actuator)
```

---

## 네이밍 규칙

### 클래스 네이밍

| 레이어 | 패턴 | 예시 |
|--------|------|------|
| Controller | `{도메인}Controller` | `AssetsController` |
| Service | `{도메인}Service` | `AssetsService` |
| Repository | `{도메인}Repository` | `AssetsRepository` |
| Entity | `{도메인}Entity` | `AssetsEntity` |
| DTO | `{동작}{도메인}Request/Response` | `CreateAssetsRequest` |
| Facade | `{도메인}Facade` | `AssetsFacade` |

### Facade 패턴 사용 기준

```
Service가 1개 → Controller에서 직접 호출
Service가 2개 이상 조합 → Facade 생성하여 조합 로직 위임
```

### 패키지 네이밍

```
com.ktc.infraops.{서비스명}     # 메인 패키지
com.ktc.infraops.{서비스명}.entity
com.ktc.infraops.{서비스명}.repository
com.ktc.infraops.{서비스명}.service
com.ktc.infraops.{서비스명}.controller.internal
com.ktc.infraops.{서비스명}.controller.public
com.ktc.infraops.{서비스명}.controller.admin
com.ktc.infraops.{서비스명}.config
com.ktc.infraops.{서비스명}.security
```

---

## 인증 체계

### 이중 인증 구조

```
요청 수신
├─ /api/v1/** (internal)
│   → SystemTokenAuthenticationFilter
│   → X-API-TOKEN: Bearer <token> 헤더 검증
│   → 성공 시 ROLE_SYSTEM 부여
│
├─ /public-api/v1/**, /admin-api/v1/**
│   → BearerTokenAuthenticationFilter (OAuth2 Resource Server)
│   → JWT groups 클레임 → ROLE_{서비스명} 검증
│
└─ /health
    → permitAll (인증 없음)
```

### 시스템 토큰 관리

- 설정: `system.tokens` (콤마 구분, 환경변수로 주입)
- `SystemTokenStore`에서 Set으로 관리
- `SystemTokenAuthenticationFilter`가 JWT 필터보다 먼저 실행

---

## 기술 스택 기준

### 백엔드

| 항목 | 표준 | 비고 |
|------|------|------|
| 언어 | Kotlin 2.3+ | JDK 21, `-Xjsr305=strict` |
| 프레임워크 | Spring Boot 3.2+ | |
| 빌드 | Gradle 8.7+ (Kotlin DSL) | `build.gradle.kts` |
| ORM | Spring Data JPA | |
| DB | PostgreSQL | |
| 보안 | Spring Security 6 + OAuth2 Resource Server | |
| 배치 | Spring Batch | 별도 모듈 |
| 모니터링 | Actuator (health, prometheus) | |
| 컨테이너 | Docker (멀티스테이지, Temurin 21) | |
| CI/CD | GitHub Actions → Harbor | GitOps 패턴 |
| 레지스트리 | Harbor (`harbor-cicd.ktcloud.com`) | |

### 프론트엔드

| 항목 | 표준 | 비고 |
|------|------|------|
| 프레임워크 | React 19 | |
| 언어 | TypeScript 5 | |
| 빌드 | Vite 7 | |
| UI 라이브러리 | Ant Design 6 | 추후 KT CDS(디자인시스템) 적용 예정 |
| 라우팅 | React Router DOM 7 | |
| 엑셀 | xlsx (SheetJS) | |
| 린트 | ESLint 9 + Prettier | |

---

## CI/CD 파이프라인

### 브랜치 전략

| 브랜치 | 용도 | CI/CD |
|--------|------|-------|
| `develop` | 개발 | → dev Harbor push (수동 배포) |
| `master` | 운영 | → Harbor push + values repo 자동 업데이트 (GitOps) |

### 이미지 태그 전략

```
{branch}-{yyyymmddhhmm}-{shortsha}   # 배포용 (시간순 정렬 가능)
{branch}-{shortsha}                   # 추적용
```

### GitOps 배포 흐름 (운영)

```
master push
→ GitHub Actions: 빌드 + Harbor push
→ infraops-service-values 레포 values.yaml tag 자동 업데이트
→ Argo CD 감지 → 배포
```

---

## DB 스키마 관리

- DDL 파일: `doc/ddl/` 폴더에 유지
- PK 패턴: `BIGINT GENERATED ALWAYS AS IDENTITY`
- 공통 컬럼: `created_at TIMESTAMP`, `updated_at TIMESTAMP`
- DB 접속: 환경변수 (`DATABASE_URL`, `DATABASE_NAME`, `DATABASE_PW`)
- `.env` 파일 지원: `spring.config.import: optional:file:.env[.properties]`

---

## 개발 가이드 문서 (doc/md/)

각 템플릿 저장소의 `doc/md/`에 AI 에이전트 및 개발자용 가이드가 포함되어 있다.

### 백엔드 (`demo-backend-kt/doc/md/`)

| 파일 | 설명 |
|------|------|
| `backend-structure.md` | 프로젝트 전체 구조, 아키텍처 규칙, 코딩 컨벤션 종합 |
| `developer-crud-guide.md` | DDL 기반 CRUD REST API 신규 개발 전체 흐름 |

### 프론트엔드 (`demo-frontend/doc/md/`)

| 파일 | 설명 |
|------|------|
| `developer-feature-guide.md` | 신규 기능 전체 흐름 (서비스 → 페이지 → 메뉴 등록) |
| `developer-page-guide.md` | 페이지 컴포넌트 생성 (`PageDefault` / `PageSplit` 패턴) |
| `developer-service-guide.md` | API 서비스 레이어 작성 및 타입 정의 |
| `css-structure.md` | CSS 레이아웃 클래스 구조 및 사용 규칙 |

---

## 프로젝트 필수 파일

새 서비스 생성 시 아래 파일이 반드시 포함되어야 한다.

| 파일 | 용도 |
|------|------|
| `AGENTS.md` | AI 에이전트 가이드 (모듈 구조, 네이밍, DDL 참조). frontmatter 필수 — 양식: `agents/templates/project-agents.md` |
| `Dockerfile` | 멀티스테이지 빌드 (백엔드) |
| `.github/workflows/` | CI/CD 파이프라인 |
| `doc/ddl/*.sql` | DB 스키마 DDL (백엔드) |
| `doc/md/` | 개발 가이드 문서 |
| `rename-service.py` | 템플릿 치환 (루트에 위치) |

---

## 레거시 프로젝트 대응

기존 프로젝트(luppiter_web 등)는 이 표준과 다른 구조를 가진다.
레거시 프로젝트 작업 시에는 **해당 프로젝트의 기존 패턴을 따르고**, 이 표준을 강제 적용하지 않는다.

| 구분 | 적용 |
|------|------|
| 신규 서비스 | 이 표준 적용 (템플릿 복제) |
| 레거시 리팩토링 | 점진적 적용 (팀 합의 후) |
| 레거시 유지보수 | 기존 패턴 유지 |

---

## Related Rules

- [coding-style.md](../rules-on-demand/coding-style.md) — 코드 스타일 (포맷, 패턴, 에러 처리)
- [security.md](../rules-on-demand/security.md) — 보안 가이드라인 (전사 기준)
- [impact-analysis.md](../rules-on-demand/impact-analysis.md) — 풀스택 레이어 체크리스트
- [git-workflow.md](../rules/git-workflow.md) — 브랜치/커밋/PR 규칙
