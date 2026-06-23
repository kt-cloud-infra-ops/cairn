---
name: cicd-deploy
description: "Git 조직 저장소에서 완료된 브랜치를 develop에 머지하고, 안전하게 푸시한 뒤, GitHub Actions 이미지 빌드/배포 워크플로우 성공과 ArgoCD 동기화까지 끝까지 확인해야 할 때 사용한다."
---

## 스킬 규칙
### ALWAYS
- develop 브랜치에서만 실행
- 머지 결과 로컬 검증 필수
- ArgoCD sync 전 end-to-end SHA 일치 확인
- `harness-service-ops`의 deploy helper로 사용하고 bootstrap prerequisite를 먼저 확인
- **순서**: 머지 점검 → [GATE 1] → 머지/검증 → [GATE 2] → push → 빌드 확인 → [GATE 3] → ArgoCD sync
### NEVER
- force-push 금지 (명시적 요청 없으면)
- 검증 건너뛰기 금지
- 워킹 트리 임의 discard 금지
- repo/chart/value/app mapping 없는 초기 서비스에 직접 적용 금지
- **[GATE 1] 통과 전 머지 진행 금지**
- **[GATE 2] 통과 전 push 금지**
- **[GATE 3] 통과 전 ArgoCD sync 금지**

## 실행 절차

이 스킬은 `${GIT_ORG}` 저장소에서 릴리스 핸드오프 전체 흐름을 처리할 때 사용한다. 전체 경로는 가능하면 `git`, `gh`, `argocd` CLI를 우선 사용한다. 워크플로우를 단순히 실행했다고 작업이 끝난 것이 아니다. `develop`에 의도한 변경이 반영되고, 이미지 빌드/배포 워크플로우 (`${CI_WORKFLOW_FILE}`, 예: `publish_to_dev_harbor.yaml`)가 `develop`에서 실행되어 최신 실행이 성공으로 끝나며, 현재 푸시의 영향을 받는 모든 ArgoCD 애플리케이션을 식별하고 동기화했을 때만 완료다.

## 사전 조건

새 장비나 새 계정에서 이 스킬을 처음 사용할 때는 아래 항목을 모두 확인한다.

- 핵심 도구: `git`, `brew`, `gh`, `argocd`가 설치되어 있다.
- 저장소 접근 권한: 대상 `${GIT_ORG}` 저장소를 클론하고 푸시할 수 있다.
- GitHub SSH: `ssh -T git@github.com`이 의도한 계정으로 성공한다.
- GitHub CLI 인증: `gh auth status`가 `github.com`에 대해 성공한다.
- GitHub 조직 권한: 계정이 대상 저장소에 접근 가능하고 필요한 `${GIT_ORG}` SSO 승인을 끝냈다.
- ArgoCD CLI 인증: `argocd context`가 동작하거나, 사용자가 `argocd login ${ARGOCD_HOST} --sso`를 완료할 수 있다.
- 네트워크 접근: GitHub, Harbor, ArgoCD 및 필요한 사내망/VPN 엔드포인트에 접근 가능하다.
- 로컬 검증 런타임: 머지 검증 전에 저장소 스택별 선행 조건이 설치되어 있다.
  - 백엔드 예시: JDK, Gradle wrapper 실행 권한, 필요한 로컬 환경 파일
  - 프론트엔드 예시: Node.js, npm, 필요한 `.env` 또는 빌드 시점 설정
- bootstrap prerequisite:
  - 서비스 허브와 프로젝트 `docs/`/`AGENTS.md`가 존재한다.
  - `service-charts` / `service-values` 경로와 대응 앱 해석 근거가 있다.
  - 초기 서비스 생성 단계가 아니라 deploy 가능한 repo/app mapping 상태다.
  - `node agents/skills/harness-orchestrator/scripts/service-orchestration.mjs validate {service} --require deploy-ready` 가 성공한다.

사전 조건이 하나라도 비어 있으면 먼저 그것부터 해결한다. 준비가 덜 된 상태로 머지, 워크플로우, ArgoCD 단계를 시작하지 않는다.

초기 서비스인데 사용자가 "CI/CD부터"를 요청하면 이 스킬을 바로 진행하지 않고 `harness-service-bootstrap` 또는 `harness-service-ops PRECHECK`로 되돌린다.

## 필수 순서

1. 저장소와 소스 브랜치를 확정한다.
   - 가능하면 사용자가 저장소나 브랜치를 명시한 값을 우선 사용한다.
   - 그렇지 않으면 현재 git remote에서 저장소를, `git branch --show-current`에서 소스 브랜치를 해석한다.
   - `origin/develop` 대비 앞선 커밋이 없으면 머지할 내용이 없다고 보고 중단한다.

2. 머지 전에 반영 예정 변경을 점검한다.
   - `git fetch origin`을 실행한다.
   - `git status --short`, `git log --oneline origin/develop..<source-branch>`, `git diff --stat origin/develop..<source-branch>`를 확인한다.
   - `origin/develop..<source-branch>`를 현재 릴리스 후보 범위로 취급한다. 즉, 지금 `develop`에 반영하려는 커밋 집합이다.
   - `develop`에 들어갈 내용을 요약한다.
   - 무관한 로컬 변경을 stash, reset, discard 하지 않는다.
   - 워킹 트리가 더러우면 현재 체크아웃 대신 분리된 worktree에서 머지 작업을 수행한다.

#### [GATE 1] 머지 전 변경 범위 사용자 확인
이 GATE를 통과해야 단계 3(머지)으로 진행한다.
- [ ] `origin/develop..<source-branch>` 커밋 집합 확인 완료
- [ ] develop 반영 요약 사용자 동의
- [ ] 무관한 로컬 변경 stash/discard 의도 0건
- [ ] 워킹 트리 dirty 시 worktree 분리 결정 완료

3. 안전하게 `develop`에 머지한다.
   - 워킹 트리가 더러운 경우 현재 작업 디렉터리를 건드리지 않도록 `origin/develop` 기반 분리 worktree를 우선 사용한다.
   - `git worktree add --detach <tmp-path> origin/develop`를 사용한다.
   - `git merge --no-ff <source-branch> -m "Merge branch '<source-branch>' into develop"`로 머지한다.
   - 충돌이 발생하면 추측해서 해결하지 말고 중단 후 충돌 내용을 보고한다.

4. 푸시 전에 머지 결과를 검증한다.
   - `AGENTS.md`, 저장소 문서, 기존 스크립트에 정의된 표준 검증 명령을 실행한다.
   - 프론트엔드 기본값: `npm run build`, `npm run lint`
   - 백엔드 기본값: `./gradlew test` 또는 변경된 백엔드 영역을 충분히 검증하는 가장 좁은 명령
   - 검증이 실패하면 중단한다. 푸시하거나 워크플로우를 실행하지 않는다.
   - 새 검증 없이 성공적으로 머지된 것만으로는 완료로 간주하지 않는다.

#### [GATE 2] 로컬 검증 통과 후 push
이 GATE를 통과해야 단계 5(push)로 진행한다.
- [ ] 표준 검증 명령(npm run build/lint, ./gradlew test 등) PASS
- [ ] 검증 실패 0건 — 실패 시 GATE 미통과 → push 금지
- [ ] 새 검증 결과 확보 (이전 빌드 결과 재사용 금지)

5. 검증된 `develop` 결과를 푸시한다.
   - 머지 결과가 검증을 통과한 뒤에만 푸시한다.
   - `git push origin HEAD:develop`를 사용한다.
   - 사용자가 명시적으로 요청하지 않은 한 force-push 하지 않는다.
   - 푸시 대상이 기능 브랜치가 아니라 `develop`인지 확인한다.

6. CLI 선행 도구를 확인한다.
   - 릴리스 핸드오프를 시작하기 전에 `command -v gh`와 `command -v argocd`를 확인한다.
   - 하나 이상 없고 Homebrew를 사용할 수 있으면 `brew install gh argocd` 또는 빠진 도구만 설치한다.
   - Homebrew를 사용할 수 없으면 브라우저 기반 흐름으로 조용히 우회하지 말고, 누락된 선행 조건을 보고하고 중단한다.

7. GitHub Actions 이미지 빌드/배포 워크플로우를 실행한다.
   - (예: `publish_to_dev_harbor.yaml` — `${CI_WORKFLOW_FILE}` 환경변수에 실제 워크플로우 파일명 설정)
   - CLI를 우선한다. 먼저 `gh auth status`를 확인한다.
   - `git` SSH 인증만으로는 `gh`가 동작하지 않는다. `gh`가 로그인되지 않았다면 `gh auth login --hostname github.com --git-protocol ssh --web`를 실행한다.
   - `gh workflow run ${CI_WORKFLOW_FILE} --repo ${GIT_ORG}/<repo> --ref develop`를 실행한다.
   - 인증 누락, 스코프 부족, 저장소 접근 문제 등으로 dispatch가 실패하면 정확한 오류를 보고하고 중단한다.
   - 현재 환경에서 `gh`를 사용할 수 없거나 로그인 완료가 불가능할 때만 브라우저 자동화를 최후 수단으로 사용한다.

8. 빌드가 성공적으로 끝났는지 확인한다.
   - CLI를 우선한다. `gh run list --repo ${GIT_ORG}/<repo> --workflow ${CI_WORKFLOW_FILE} --branch develop -L 1`로 `develop`의 최신 실행을 찾는다.
   - 기다리기 전에 최신 실행이 기대한 `HEAD` 커밋을 가리키는지 확인한다.
   - `gh run watch <run-id> --repo ${GIT_ORG}/<repo> --exit-status`로 모니터링한다.
   - `gh run view <run-id> --json url`에서 실행 URL을 확보한다.
   - 성공의 정의는 `develop`용 최신 이미지 빌드/배포 워크플로우 (`"${CI_WORKFLOW_NAME}"`) 실행이 초록색 완료 상태로 끝나는 것이다.
   - `queued`, `in progress`, `cancelled`, `failure` 또는 페이지 상태가 모호하면 실패로 취급한다. 이런 경우 성공이라고 보고하지 않는다.
   - 저장소, 소스 브랜치, 머지 요약, 푸시 결과, 가능하면 워크플로우 URL, 최종 빌드 상태를 보고한다.

#### [GATE 3] 이미지 빌드 성공 후 ArgoCD sync
이 GATE를 통과해야 단계 9(ArgoCD sync)로 진행한다.
- [ ] 이미지 빌드/배포 워크플로우 (`"${CI_WORKFLOW_NAME}"`) 최신 실행 status = success
- [ ] 최신 실행 `headSha` = 푸시된 develop SHA 일치
- [ ] queued/in_progress/cancelled/failure 0건 — 미통과 시 ArgoCD sync 금지
- [ ] 워크플로우 URL/실행 ID 확보

9. 빌드 성공 후 대응하는 ArgoCD 애플리케이션을 동기화한다.
   - CLI를 우선한다. 먼저 `argocd context` 또는 `~/.config/argocd/config` 존재 여부를 확인한다.
   - ArgoCD 로그인이 되어 있지 않으면 `argocd login ${ARGOCD_HOST} --sso`를 실행한다. 환경상 필요하면 `--grpc-web`로 재시도한다.
   - 앱 이름을 추측하기 전에 프로젝트 단서를 먼저 조사한다.
   - 앱 이름을 해석하기 전에 스코프 분석 입력값을 고정한다.
     - 소스 저장소 이름
     - 푸시된 `develop` SHA
     - 최신 성공 워크플로우 실행 ID, URL, `headSha`
     - 워크플로우에서 해석한 `IMAGE_NAME`, `IMAGE_BASE`, values 디렉터리/경로
     - `develop` 기준 values 저장소 revision과 values 파일 tag
   - 이 정보가 푸시 전에 수집되지 않았다면, 푸시된 `develop` 상태와 최신 성공 워크플로우 실행으로부터 다시 재구성한다. 오래된 실행의 증거를 섞지 않는다.
   - 로컬 체크아웃에서 저장소 이름을 읽고 `.github/workflows/${CI_WORKFLOW_FILE}`에서 `IMAGE_NAME`, `IMAGE_BASE`, `VALUES_PATH`, values 저장소 하위 경로 같은 배포 단서를 조사한다.
   - 현재 푸시를 단일 진실 원천으로 사용한다. 최소 증거 집합은 다음과 같다.
     - `git ls-remote origin refs/heads/develop`로 확인한 푸시된 `develop` SHA
     - 최신 성공 이미지 빌드/배포 워크플로우 (`"${CI_WORKFLOW_NAME}"`) 실행과 해당 `headSha`
     - 워크플로우가 갱신한 `develop` 기준 values 파일
     - 현재 ArgoCD 앱 source, values revision, 렌더링된 이미지
   - 빠른 확인 명령:
     - `git ls-remote origin refs/heads/develop`
     - `gh run list --repo ${GIT_ORG}/<repo> --workflow ${CI_WORKFLOW_FILE} --branch develop -L 1`
     - `gh api 'repos/${GIT_ORG}/${VALUES_REPO}/contents/<values-dir>/values.yaml?ref=develop' --jq .content | tr -d '\n' | base64 -D`
     - `argocd app list --grpc-web -o name`
     - `argocd app get <app-name> --grpc-web`
     - `argocd app manifests <app-name> --grpc-web`
   - 저장소 이름, 해석된 `IMAGE_NAME`, values 경로 디렉터리 이름을 배포 식별자 후보로 본다.
   - 배포 대상이 하나뿐이라고 가정하지 않는다. 하나의 푸시가 한 앱 또는 여러 앱에 영향을 줄 수 있다.
   - 오래된 가정이 아니라 현재 푸시 기준으로 배포 범위를 결정한다.
   - 현재 푸시된 `develop` 커밋, 워크플로우가 갱신한 values 경로, 프로젝트 배포 단서를 함께 사용해 이번 릴리스가 하나의 ArgoCD 앱에 대응하는지 여러 앱에 대응하는지 판단한다.
   - `argocd app list --grpc-web -o name` 결과에서 식별자 후보와 직접 일치하는 앱을 먼저 찾는다.
   - 직접 이름 매칭이 모호하거나 비어 있으면 `argocd app get <app-name> --grpc-web`, `argocd app manifests <app-name> --grpc-web`로 후보를 추가 조사한다.
   - 해석 우선순위:
     - 가장 강함: app source 또는 렌더링된 values가 같은 `${VALUES_REPO}/<dir>/values.yaml`를 가리킨다.
     - 다음: 렌더링된 manifest 이미지 저장소가 `IMAGE_BASE`와 일치한다.
     - 다음: 렌더링된 manifest 이미지 tag가 워크플로우가 갱신한 values tag와 일치한다.
     - 가장 약함: 앱 이름에 저장소 이름 또는 `IMAGE_NAME`이 포함된다.
   - 선택한 각 앱은 아래와 같은 프로젝트 파생 신호 하나 이상으로 다시 확인한다.
     - 앱 이름에 저장소 이름 또는 `IMAGE_NAME`이 포함된다.
     - 렌더링된 manifest 이미지 저장소가 워크플로우의 `IMAGE_BASE`와 일치한다.
     - 앱 source 또는 렌더링된 values가 같은 `${VALUES_REPO}/<dir>/values.yaml`를 가리킨다.
     - 앱이 현재 푸시에서 생성된 tag 또는 values revision을 참조한다.
   - 프로젝트 증거를 기반으로 최종 앱 목록을 만든다.
   - 일치 앱이 0개면 지금까지 찾은 증거를 보고하고 중단한다.
   - 여러 앱이 일치하더라도 현재 푸시 증거가 모두를 뒷받침할 때만 유효한 다중 앱 배포로 본다.
   - 공유 values 또는 fan-out 규칙:
     - 여러 앱이 현재 푸시가 만든 동일 values 경로나 동일 이미지 저장소/태그를 렌더링하면 함께 범위에 포함한다.
     - 공유 chart나 values 저장소가 바뀌었더라도 푸시된 이미지/values 증거와 일치하는 앱이 하나뿐이면 그 앱만 동기화한다.
   - 가능한 앱이 여러 개인데 현재 푸시 기준 범위가 여전히 모호하면, 후보 목록과 앱별 증거를 보고하고 동기화 전 사용자 확인이 필요하다고 알린다.
   - 동기화 전 각 앱이 현재 푸시와 end-to-end로 일치하는지 확인한다.
     - GitHub 실행의 `headSha`가 푸시된 `develop` SHA와 일치한다.
     - values 파일 tag가 푸시된 이미지 tag와 일치한다.
     - 렌더링된 manifest 이미지가 같은 tag를 사용한다.
   - 현재 푸시 범위에 포함된 모든 앱에 대해 `argocd app sync <resolved-app-name>`을 실행한다.
   - 모든 앱에 대해 `argocd app wait <resolved-app-name> --sync --health --operation`으로 완료를 기다린다.
   - CLI 로그인 흐름이 막히거나 sync 결과가 모호할 때만 브라우저 자동화를 최후 수단으로 사용한다.
   - 앱을 찾지 못했거나, 로그인 실패, sync 명령 오류가 발생하면 정확한 차단 요인을 보고하고 중단한다.

## 완료 체크리스트

아래 항목이 모두 참이 되기 전에는 완료를 보고하지 않는다.

- `origin/develop`가 의도한 머지를 받았다.
- 머지 결과가 로컬 검증을 통과했다.
- 이미지 빌드/배포 워크플로우 (`"${CI_WORKFLOW_NAME}"`)가 `develop`에서 실행되었다.
- `develop`의 최신 워크플로우 실행이 성공으로 끝났다.
- 현재 푸시의 영향을 받는 모든 ArgoCD 애플리케이션이 동기화되었고 `Synced`, `Healthy`가 확인되었다.

## 스코프 분석 출력

배포 범위를 해석했을 때는 sync 결과 전이나 함께 아래 형식으로 간단히 보고한다.

- 푸시된 `develop` SHA
- 워크플로우 실행 ID와 URL
- values 경로와 values tag
- 매칭된 앱
- 제외한 앱과 제외 이유
- 최종 범위가 단일 앱인지 다중 앱인지

## 도구

- git 조사, 머지, 검증, 푸시, `gh` 워크플로우 제어, `argocd` sync에는 `functions.exec_command`를 사용한다.
- GitHub 또는 ArgoCD 웹 로그인 흐름이 CLI로 막힐 때만 chrome-devtools 도구를 대체 수단으로 사용한다.

## 예시

- `$<YOUR_WORKFLOW_ALIAS>`를 사용해서 `<SERVICE>-frontend`의 `develop_<SERVICE>`를 `develop`에 머지하고 이미지 빌드/배포 워크플로우 성공까지 확인해줘.
- `$<YOUR_WORKFLOW_ALIAS>`를 현재 저장소에 적용해서 `develop` 푸시, 이미지 빌드 성공 확인, 대응하는 ArgoCD 앱 동기화까지 진행해줘.

## 완료 조건 (DONE WHEN)
- [ ] [MANUAL] develop 머지 완료
- [ ] [MANUAL] 로컬 검증 PASS
- [ ] [MANUAL] 이미지 빌드/배포 워크플로우 성공
- [ ] [MANUAL] ArgoCD sync Healthy
