# Service Mapping (Canonical Source)

이 파일은 Jira 에픽 ↔ 서비스 폴더 매핑의 **단일 소스(Single Source of Truth)**입니다.
`/work-tasks`, `/weekly-report` 등 서비스 매핑이 필요한 모든 커맨드는 이 파일을 참조합니다.

> **사용자 설정**: 실제 매핑 테이블과 팀원 정보는 `config/services.example.json` 및
> `config/team.example.json` 스키마를 참고하여 팀 환경에 맞게 정의하세요.

---

## 서비스 매핑 구조

Jira 에픽 summary의 **접두사**(파이프`|` 앞 부분)를 파싱하여 서비스 폴더에 매핑합니다.

매핑 정의 방법:

| 접두사 패턴 | 서비스 폴더 | 비고 |
|-------------|-------------|------|
| `<YOUR_SERVICE_A>` | `<your-group>/<your-service-a>` | 예: 데이터 관리 서비스 |
| `<YOUR_SERVICE_B>`, `<ALIAS_B>` | `<your-group>/<your-service-b>` | 레거시 명칭 포함 시 aliases 추가 |
| `<YOUR_SERVICE_C>` | `<your-group>/<your-service-c>` | 예: API 게이트웨이 |
| (TBD) | `<your-group>/<your-service-d>` | Jira 에픽 미생성 (TBD) |
| (template) | `demo` | 템플릿/예시 전용. 실제 서비스 매핑 아님 |

실제 매핑은 `config/services.example.json`의 `mappings` 배열을 참고하여 이 테이블에 채운다.

### 프로젝트별 기본 매핑

| Jira 프로젝트 | 기본 서비스 | 비고 |
|---------------|-------------|------|
| `${JIRA_PROJECT_KEY}` | `<YOUR_PRIMARY_SERVICE>` | 팀 전용 프로젝트, 접두사로 서비스 판별 |

Jira 프로젝트 키는 `${JIRA_PROJECT_KEY}` 환경변수 또는 `~/.jira-credentials.json`에서 참조한다.

### 공통 업무 (서비스 매핑 제외)

아래 접두사는 특정 서비스가 아닌 팀 공통 업무로, 서비스 TASKS.md에 반영하지 않는다.

| 접두사 | 설명 |
|--------|------|
| `[공통]`, `공통` | 팀 공통 업무 (리소스 효율성, 점검 등) |
| `표준화` | 표준화 프레임워크 |
| `내제화`, `내재화` | 업무 내재화 |
| `인프라` | 인프라 운영 |

팀 환경에 맞게 공통 업무 접두사를 추가하거나 변경한다.

### 매핑 실패 시

접두사가 매핑 테이블에 없으면 → **"미매핑"** 으로 표시하고 사용자에게 매핑 추가 여부를 질문한다.

**frontmatter 사용**: 프로젝트 `AGENTS.md` frontmatter `service:` 값은 위 매핑 표의 `서비스 폴더` 컬럼을 따른다.

---

## 팀원 정보

팀원 정보(이름, 이메일 ID, 사번, Jira accountId)는 **이 파일에 직접 기입하지 않습니다**.

- 스키마: `config/team.example.json` 참조
- 실제 값: 환경변수(`${JIRA_ACCOUNT_ID}`, `${JIRA_REPORTER_ACCOUNT_ID}`) 또는 로컬 전용 파일로 관리

**TASKS.md 담당자 섹션 형식**: `## @{이메일ID} ({표시명})`
- 예: `## @<YOUR_USER_ID> (<YOUR_NAME>)`

---

## 매핑 변경 절차

이 파일은 팀 공유 규칙이므로 변경 시 `/review-rules` 프로세스를 따른다.
새 서비스/접두사 추가 시 이 파일만 수정하면 모든 커맨드에 반영된다.
