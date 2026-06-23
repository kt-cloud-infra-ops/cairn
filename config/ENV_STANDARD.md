# Cairn 환경변수 / 플레이스홀더 표준

> 모든 정제 작업은 이 표준을 따른다. 사내 하드코딩을 아래 토큰으로 치환한다.

## 환경변수 (런타임 주입 — 스크립트/연동값)

| 변수 | 의미 | 예시값 |
|------|------|--------|
| `${ATLASSIAN_BASE_URL}` | Jira/Confluence 테넌트 호스트 | https://yourcompany.atlassian.net |
| `${JIRA_PROJECT_KEY}` | Jira 프로젝트 키 | PROJ |
| `${JIRA_ACCOUNT_ID}` | Jira 계정 ID (담당자/보고자) | (사용자 본인 accountId) |
| `${JIRA_CREDENTIALS_FILE}` | Jira 인증 파일 경로 | ~/.jira-credentials.json |
| `${CONFLUENCE_SPACE_KEY}` | Confluence 스페이스 키 | TEAM |
| `${CONFLUENCE_PAGE_ID}` | Confluence 페이지 ID | 123456 |
| `${GIT_ORG}` | Git 조직/오너 | your-org |
| `${REPO_NAME}` | 대상 레포명 | your-repo |
| `${VAULT_PATH}` | Vault secret 경로 | secret/your-app |
| `${ARGOCD_APP}` | ArgoCD 애플리케이션명 | your-app |
| `${HARBOR_REGISTRY}` | 컨테이너 레지스트리 호스트 | registry.example.com |
| `${JENKINS_JOB}` | Jenkins job 이름 | your-job |
| `${DB_HOST}` / `${DB_PORT}` | DB 접속 | localhost / 5432 |
| `${SLACK_CHANNEL_ID}` / `${SLACK_BOT_TOKEN}` | Slack 연동 | C0XXXX / xoxb-... |
| `${SERVICE_BASE_URL}` | 서비스 외부 URL | https://your-service.example.com |
| `${CLAUDE_HOME}` | Claude 설정 홈 | `${CLAUDE_HOME:-$HOME/.claude}` |
| `${CODEX_HOME}` | Codex 설정 홈 | `${CODEX_HOME:-$HOME/.codex}` |

## 플레이스홀더 (문서 내 표기 — 사용자가 자기 값으로 치환)

| 토큰 | 의미 |
|------|------|
| `<YOUR_ORG>` | 조직/회사명 |
| `<YOUR_TEAM>` | 팀명 |
| `<YOUR_SERVICE>` | 서비스/제품명 |
| `<YOUR_REPO>` | 레포명 |
| `<YOUR_USER_ID>` | 사용자 ID (이메일 prefix) |
| `<YOUR_NAME>` | 표시 이름 |
| `<YOUR_EMPLOYEE_ID>` | 사번 |
| `<YOUR_DB_URL>` / `<YOUR_TABLE>` | DB 접속/테이블 예시 |

## 원칙

1. **개인 식별자**(사번/실명/accountId/홈경로) → 제거 또는 플레이스홀더. 절대 실값 잔존 금지.
2. **조직 식별자**(spaceKey/pageId/프로젝트키/org/서비스명) → 환경변수 또는 플레이스홀더.
3. **인프라 종속**(URL/DB/Vault/ArgoCD) → 환경변수.
4. **제품명**(PostgreSQL/Slack/Confluence 자체) → 범용이므로 유지. 단 사내 tenant와 결합된 문맥은 예시화.
5. 치환 후 의미가 깨지면 → 주변에 `(예: ...)` 형태 예시 1개 첨부.
6. 사내 전용 절차(특정 Jenkins job, 특정 Vault 트리)는 **범용 skeleton + "사용자 환경에 맞게 설정" 안내**로 대체.
