# Sparrow 스캔 실행

## 1. 자식 프로젝트 키 해석

부모 키(`SPARROW_PROJECT_KEY`) 하위에서 저장소명과 일치하는 자식 키를 찾는다.

우선순위:

| 순위 | 소스 | 비고 |
|------|------|------|
| PRIMARY | `.cairn/profile/` 의 저장소↔프로젝트 키 매핑 | 조직 값. 있으면 그대로 사용 |
| SECONDARY | `scripts/resolve_subproject.sh <저장소명>` | REST `/api/1/login`(force) → `/api/1/projects` 로 부모 키 하위 매칭. 종료코드 3 = 못 찾음 |
| FORBIDDEN | 키 추측·임의 생성 | 금지. 못 찾으면 사용자에게 질문 |

> `sparrow-mkproj.sh -PL`(프로젝트 목록)은 계정에 `/api/1/checkers/groups` 권한이 없으면 403이라 사용할 수 없다. REST 조회를 쓴다.

## 2. `-SD` (스캔 소스 경로) 해석 규칙

빌드 산출물 없이 소스만 올리기 위해 아래 순서로 결정한다.

1. 입력이 `:`로 이어진 다중 경로 → **그대로** 사용
2. `<대상>/src` 가 있으면 → `<대상>/src`
3. 멀티모듈(`<대상>/*/src`)이면 → 모듈 `src` 들을 `:`로 연결
4. 위 어느 것도 아니면 → 대상 디렉터리 자체

결정된 경로를 [GATE 1]에서 사용자에게 보여준다. 각 경로가 실제 존재하는지 먼저 확인한다.

## 3. 스캔 실행

번들 래퍼를 사용한다. 직접 클라이언트를 호출하지 않는다.

```bash
# 먼저 dry-run 으로 -SD 경로와 명령을 확인
bash skills/security-check-sparrow/scripts/run_sparrow.sh <대상DIR> <자식키> --dry-run

# 실제 실행
bash skills/security-check-sparrow/scripts/run_sparrow.sh <대상DIR> <자식키>
```

래퍼가 보장하는 것:

- 비밀번호를 `umask 077` 임시파일로만 전달하고(`-PW <파일>`) `trap`으로 삭제 — 명령행·로그에 값이 남지 않는다
- `SPARROW_NOUPDATE=true`(기본)이면 `-NU` 를 붙이고 클라이언트 경로의 잔재 `err_update` 를 먼저 제거한다
  (로컬 macOS는 서버의 linux 엔진 자동업데이트가 404로 실패 → update 실패가 스캔을 스킵시킨다)
- `-SD` 를 2절 규칙대로 해석하고 각 경로 존재를 사전 검증한다
- `SPARROW_URL` / 자격증명 / 프로젝트 키 / 클라이언트가 없으면 **실행 전에 중단**한다

조직에 별도 검증된 래퍼가 있으면 그것을 써도 된다. 단 위 4개 보장과 `result-reporting.md` 집계 규칙을 반드시 만족해야 한다.

## 4. 대형 저장소 / 다중 저장소

- 대형 저장소는 수십 분이 걸린다 → 백그라운드 실행 + 로그 파일 tail로 추적
- `nohup ... &` 의 즉시 `exit 0`은 **런처 리턴**이다. 완료로 판단하지 않는다
- 완료 판정은 `ps`로 프로세스 종료 확인 + 로그 마지막 줄 확인
- **다중 저장소는 순차 실행.** 단일 계정/클라이언트라 동시 실행 시 `[-140]` 충돌이 난다

## 5. 실행 옵션

| 변수 | 기본 | 의미 |
|------|------|------|
| `SPARROW_LEVEL` | `all` | 분석 레벨. 조직 룰셋이 있으면 그 값 사용 |
| `SPARROW_NOUPDATE` | `true` | `-NU` 자동업데이트 우회 |
| `IS_FORCE_EXIT` | `false` | true면 위험 1건 이상에서 exit 1 (CI 게이트용) |
