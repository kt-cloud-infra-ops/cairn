# Service Mapping (Canonical Source)

이 파일은 Jira 에픽 ↔ 서비스 폴더 매핑의 **단일 소스(Single Source of Truth)**입니다.
`/work-tasks`, `/weekly-report` 등 서비스 매핑이 필요한 모든 커맨드는 이 파일을 참조합니다.

## 서비스 매핑 테이블

Jira 에픽 summary의 **접두사**(파이프`|` 앞 부분)를 파싱하여 서비스에 매핑한다.

| 접두사 패턴 | 서비스 폴더 | 비고 |
|-------------|-------------|------|
| `CMDB` | common/cmdb | |
| `GAIA`, `가이아` | infraops/gaia | |
| `Infra Admin`, `infra-admin` | infraops/infra-admin | 폐기된 infrafe 명칭 변경 |
| `유피테르` | infraops/luppiter | |
| `MessageBridge`, `헤르메스` | infraops/hermes | MessageBridge = Hermes 레거시 |
| `헤라` | infraops/hera | |
| `SSO`, `tech-sso` | tech-sso-admin | Jira 에픽 미생성 (TBD) |
| `infraops-batch`, `배치 중앙 관리` | infraops/infraops-batch | Jira 에픽 미생성 (Phase 0 INIT 진행 중, GATE 1 진입 시 결정) |
| `infraops-api` | infraops/infraops-api | 통합 API 게이트웨이 (운영 중) |
| `infraops-bff` | infraops/infraops-bff | Backend-for-Frontend (운영 중) |
| `infraops-frontend` | infraops/infraops-frontend | 프론트엔드 (운영 중) |
| `infraops-message-bridge`, `MB v2` | infraops/infraops-message-bridge | MessageBridge v2 — Hermes 후속 (TECHIOPS26-405) |
| (TBD) | infraops-jira-bot | Jira 에픽 미생성 (TBD) |
| `Auth Admin`, `auth-admin` | common/auth-admin | 공통 인증/권한 시스템 (1차 26.06) |
| `Infra Config` | infraops/infra-config | TOKEN white list 환경 설정 (1차 26.06) |
| `Infra IP Scanner` | infraops/infra-ip-scanner | Region/Zone IP 스캔 (1차 26.12) |
| `ITSM Jira`, `Jira Workflow` | infraops/itsm-jira | Jira Workflow 기반 작업/인시던트 (1차 26.12) |
| `Platform Admin` | devops/platform-admin | CICD 운영 관리 (DevOps 파트) |
| (template) | demo | 템플릿/예시 전용. 실제 서비스 매핑 아님 |

### 프로젝트별 기본 매핑

| Jira 프로젝트 | 기본 서비스 | 비고 |
|---------------|-------------|------|
| LUPR | luppiter | Luppiter 전용 프로젝트 |
| TECHIOPS26 | (접두사 파싱) | 팀 공통 프로젝트, 접두사로 서비스 판별 |

### 공통 업무 (서비스 매핑 제외)

아래 접두사는 특정 서비스가 아닌 팀 공통 업무로, 서비스 TASKS.md에 반영하지 않는다.

| 접두사 | 설명 |
|--------|------|
| `[공통]`, `공통` | 팀 공통 업무 (리소스 효율성, 점검 등) |
| `표준화` | 표준화 프레임워크 |
| `내제화`, `내재화` | 업무 내재화 |
| `인프라` | 인프라 운영 |
| `SlackBot` | 슬랙봇 프로토타입 |

### 매핑 실패 시

접두사가 매핑 테이블에 없으면 → **"미매핑"** 으로 표시하고 사용자에게 매핑 추가 여부를 질문한다.

**frontmatter 사용**: 프로젝트 `AGENTS.md` frontmatter `service:` 값은 위 매핑 표의 `서비스 폴더` 컬럼을 따른다.

## 팀원 정보

| 이름 | 이메일 ID | 사번 | accountId |
|------|----------|------|-----------|
| 김정남 | bill.kim | 82305524 | 712020:1253fda5-0458-4f4d-836a-2646b0576e3c |
| 김지웅 | jiwoong.kim | 82253890 | 712020:0624eba4-7ed1-4c12-90c2-1c859f9795cb |
| 강기주 | kiju.kang | 82289867 | 712020:3e37b726-8922-4f89-b431-fc1c005ff9e8 |
| 이종혁 | jong-hyuk.lee | 82255337 | 712020:48eac86c-d56b-4063-96e4-3439da50beb4 |
| 이경수 | kyoungsoo.lee | 82253233 | 712020:cb0d5d65-8cfa-4f0b-b512-51095b8e97ca |
| 이경미 | kyoungmi.lee | 82268572 | 712020:648e01a8-d9ec-4bce-839c-7ad49e9ec6ac |
| 김재혁 | jehyuk.kim | 82312411 | [TBD] |

**TASKS.md 담당자 섹션 형식**: `## @{이메일ID} ({표시명})`
- 예: `## @bill.kim (김정남)`

## 매핑 변경 절차

이 파일은 팀 공유 규칙이므로 변경 시 `/review-rules` 프로세스를 따른다.
새 서비스/접두사 추가 시 이 파일만 수정하면 모든 커맨드에 반영된다.
