# 제품별 런타임 검증 프로파일

패치 이미지는 빌드 성공만으로 통과시키지 않는다. 아래 항목을 **실제 실행**해 확인하고 결과를 `validation.txt`에 남긴다.

## 공통 (모든 프로파일)

- [ ] 이미지 config 보존: `USER`, `ENTRYPOINT`, `CMD`, `WORKDIR`, 주요 `ENV`
- [ ] 아키텍처가 원본과 동일
- [ ] 컨테이너가 정상 기동하고 즉시 종료되지 않음
- [ ] 애플리케이션 버전 문자열이 기대 범위 내

검증 결과는 `passed` / `failed` / `blocked` / `emulated` 중 하나로 기록한다.

## CloudNativePG PostgreSQL

- [ ] 실행 UID = 26
- [ ] PostgreSQL 메이저·마이너 버전 (`postgres --version`)
- [ ] CNPG 필수 실행 파일 존재: `postgres`, `pg_ctl`, `pg_basebackup`, `pg_rewind`, `pg_controldata`
- [ ] 필요한 확장(extension) 파일 존재
- [ ] Barman(`barman-cloud-*`) 명령 존재
- [ ] 이미지 타입(표준/PostGIS 등) 일치
- [ ] base OS collation 변경 위험 없음 — OS 메이저가 바뀌면 `needs review`

## Redis

- [ ] `ENTRYPOINT` / `CMD` 보존
- [ ] `/data` 디렉터리 존재 및 권한
- [ ] Redis 프로세스 실행 UID/GID
- [ ] RDB/AOF 설정 보존
- [ ] ACL 설정 보존
- [ ] 로드되는 모듈 목록 동일
- [ ] TLS 설정 보존
- [ ] 스모크: `PING` → `SET` → `GET` 왕복 성공

## Generic Java

- [ ] JDK 버전 (`java -version`)
- [ ] `ENTRYPOINT` 보존
- [ ] 애플리케이션 JAR 및 의존 JAR 존재
- [ ] JDBC 드라이버 존재 (사용하는 경우)
- [ ] 기동 명령 정상 동작
- [ ] 사용자 제공 health 명령 성공 (있는 경우)

## Generic (그 외 전부)

- [ ] 이미지 config 보존
- [ ] **사용자 제공 스모크 명령 필수** — 없으면 검증을 `blocked`로 기록하고 "검증됨"으로 보고하지 않는다

## 회귀 처리

검증 항목이 하나라도 실패하면:

1. 해당 패치 이미지를 **거부**한다
2. 실패 항목과 원본 대비 차이를 리포트에 기록한다
3. 조치 상태를 `remediated`로 올리지 않는다
4. 더 작은 조치안(개별 패키지 고정 등)으로 되돌아가 GATE 1부터 다시 진행한다
