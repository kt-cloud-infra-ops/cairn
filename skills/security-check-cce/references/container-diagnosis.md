# 일회용 컨테이너 진단

## 스크립트 확보 우선순위

1. 사용자 제공 로컬 스크립트 디렉터리
2. 조회된 페이지 본문에 노출된 첨부 다운로드 링크 (현재 읽기 전용 세션 사용)
3. 페이지의 fenced code block에 포함된 스크립트 원문
4. 모두 실패 → 스크립트 기반 항목 `Blocked`

`script-manifest.json`에 기록:

```json
{
  "scriptSource": "local|attachment|codeblock",
  "pageId": "1925678414",
  "pageVersion": 8,
  "scripts": [{"name": "script_1.sh", "sha256": "...", "origin": "..."}]
}
```

Confluence API 토큰을 요청·저장하지 않는다. 변경 API는 어떤 경우에도 사용하지 않는다.

## 실행 패턴 (현재 가이드 기준)

```text
pull image (digest 고정)
run image as a temporary keep-alive container
copy script_1.sh, script_2.sh to /tmp
execute both scripts
rename linux-result.txt after each run
copy result_1.txt, result_2.txt to the host
remove the temporary container
```

가이드의 placeholder를 그대로 복사하지 않고 **선택된 런타임에 맞게 명령을 재구성**한다.

## 실행 체크리스트

- [ ] 런타임 선택: 활성 런타임이 `nerdctl`이면 `nerdctl`, 아니면 `docker`
- [ ] digest 고정 pull, 명시적 `--platform <원본 아키텍처>`
- [ ] 컨테이너 이름은 고유값 (예: `cairn-cce-<run-id>-<seq>`)
- [ ] keep-alive 명령: `tail -f /dev/null`
- [ ] shell 탐지: `/bin/sh` → 실패 시 `/bin/bash`. 둘 다 없으면 `Blocked` (이미지 변조 금지)
- [ ] 스크립트를 `/tmp`에 복사하고 실행 권한 부여
- [ ] **기본 실행 컨텍스트 = 이미지 설정 사용자**
- [ ] 결과 파일 실제 위치 확인 — 가이드는 `/tmp`에서 실행하지만 예시는 `/home`에서 복사한다. 실제 생성 경로를 찾아 회수한다
- [ ] 결과를 `evidence/<normalized-image>/<digest>/` 로 복사
- [ ] trap 기반 cleanup — 성공·실패·중단 모두에서 **생성한 컨테이너만** 제거
- [ ] `container-run.json`에 명령, 런타임, 호스트/소스 아키텍처, 에뮬레이션 여부, 설정 사용자, override 사용자, 결과 경로, exit code, cleanup 상태 기록

## root 진단 override

기본은 이미지 설정 사용자로 실행한다. 특정 점검이 권한 있는 파일 읽기를 요구할 때만:

1. [GATE 1]에서 사유와 함께 사용자 승인을 받는다
2. **별도의 일회용 컨테이너**를 root로 기동한다 (원본 실행을 root로 바꾸지 않는다)
3. 실행 컨텍스트가 override되었음을 `container-run.json`과 리포트에 기록한다
4. override로 얻은 결과는 항목별로 override 표시를 남긴다

권한 거부 결과는 `Blocked` 또는 `Needs Review`다. `Good`/`Vulnerable`로 변환하지 않는다.

## 재점검

| 항목 유형 | 재점검 방법 |
|-----------|-------------|
| 이미지·파일시스템 | 조치된 로컬 이미지에 **동일 스크립트 재실행** |
| Kubernetes / Helm | 생성된 `kubernetes-patch.yaml` / `values-cce.yaml` **재파싱** |

워크로드 항목을 이미지 스크립트 결과만으로 `조치 완료`로 표기하지 않는다.

## 오류 처리

| 상황 | 처리 |
|------|------|
| 인증 실패 | 차단된 단계(레지스트리/Kubernetes/Confluence)를 식별. 자격증명 출력 금지 |
| pull 실패 | repository·digest·아키텍처·연결성·credential helper 확인 후에만 재시도. 검증되지 않은 공개 이미지로 조용히 대체 금지 |
| 컨테이너 기동 실패 | 로그 보존 + 컨테이너 제거 + 대상 `Blocked` |
| shell/필수 명령 부재 | 해당 점검 `Blocked`. 진단 패키지 설치 금지 |
| 빌드 실패 | 로그 보존, 성공 형태 산출물 생성 금지 |
