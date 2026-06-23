# Project AGENTS.md Template

프로젝트 레포 `AGENTS.md` 상단에는 아래 frontmatter를 둔다.

## Frontmatter 스키마 예시

```yaml
---
service: demo
role: backend
related:
  - workspace/demo-frontend
repo: kt-cloud-infra-ops/demo-backend-kt
external: /Users/foo/bar
---
```

- `service`: 필수. `agents/rules/service-mapping.md`의 `서비스 폴더` 컬럼 값 사용
- `role`: 필수. `frontend|backend|scheduler|e2e|shared|batch`
- `related`: 옵션. 같은 서비스 내 관련 프로젝트 목록
- `repo`: 옵션. GitHub 저장소 slug
- `external`: 옵션. `workspace/` 밖 외부 절대경로

## 면제 규칙

아래 경로는 frontmatter 강제 대상에서 제외한다.

- `workspace/test_*`
- `workspace/poc_*`
- `workspace/*-mock`
- `workspace/*-stub`
- `workspace/ref-*`
- `workspace/luppiter-local-env/*`

## 작성 규칙

- frontmatter 뒤 본문은 기존 프로젝트별 가이드를 유지
- `related`는 1:1 pair와 N:M 연관 프로젝트를 모두 이 필드 하나로 표현
- `repo`와 `external`은 필요한 경우에만 기입
- 신규 서비스 frontmatter 작성 전 `service-mapping.md`에 서비스 폴더 값 존재 여부 확인

## Role Templates

### frontend

```yaml
---
service: demo
role: frontend
related:
  - workspace/demo-backend-kt
repo: kt-cloud-infra-ops/demo-frontend
---
```

```md
# Frontend Agent Guidelines

프론트엔드 프로젝트 가이드.

## 기술 스택
- React / TypeScript / Vite

## 핵심 규칙
- 페이지에서 직접 fetch 금지
- 서비스 레이어 경유
- 메뉴 등록 누락 금지
```

### backend

```yaml
---
service: demo
role: backend
related:
  - workspace/demo-frontend
repo: kt-cloud-infra-ops/demo-backend-kt
---
```

```md
# Backend Agent Guidelines

백엔드 프로젝트 가이드.

## 기술 스택
- Spring Boot / Kotlin / PostgreSQL

## 핵심 규칙
- Controller → Service → Repository
- DDL 참조 후 구현
- 트랜잭션 경계 명시
```

### scheduler

```yaml
---
service: demo
role: scheduler
related:
  - workspace/demo-backend-kt
repo: kt-cloud-infra-ops/demo-scheduler
---
```

```md
# Scheduler Agent Guidelines

스케줄러/배치 프로젝트 가이드.

## 핵심 규칙
- 잡 단위 입출력 명시
- 재실행/멱등성 고려
- 운영 스케줄 변경 시 근거 문서화
```

### e2e

```yaml
---
service: demo
role: e2e
related:
  - workspace/demo-frontend
  - workspace/demo-backend-kt
repo: kt-cloud-infra-ops/demo-e2e
---
```

```md
# E2E Agent Guidelines

E2E 테스트 프로젝트 가이드.

## 핵심 규칙
- 운영 데이터 변경 금지
- 테스트 데이터 생성 후 정리
- trace/screenshot 아티팩트 보존
```

### shared

```yaml
---
service: demo
role: shared
related:
  - workspace/demo-backend-kt
  - workspace/demo-frontend
repo: kt-cloud-infra-ops/demo-shared
---
```

```md
# Shared Agent Guidelines

공통 라이브러리/공유 자산 프로젝트 가이드.

## 핵심 규칙
- 하위 소비 프로젝트 영향도 우선 확인
- 하위 호환성 깨짐 여부 명시
- 공통 인터페이스 변경 시 마이그레이션 경로 기록
```

### batch

```yaml
---
service: demo
role: batch
related:
  - workspace/demo-backend-kt
repo: kt-cloud-infra-ops/demo-batch
---
```

```md
# Batch Agent Guidelines

배치 처리 프로젝트 가이드.

## 핵심 규칙
- 입력/출력 파일 형식 명시
- 실패 재처리 기준 명시
- 운영 배포/실행 절차 별도 관리
```
