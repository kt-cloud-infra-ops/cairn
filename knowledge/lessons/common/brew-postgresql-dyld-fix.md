---
tags:
  - type/lesson
  - audience/team
  - domain/devops
aliases: []
---

> 상위: [lessons](../../README.md) · [common](../README.md)

# brew postgresql dyld 에러 해결 (Apple Silicon)

## 증상

`brew install postgresql@14` (또는 다른 버전) 후 initdb / postgres 명령 실행 시:

```
dyld[xxxxx]: Library not loaded: /opt/homebrew/lib/postgresql@14/libpq.5.dylib
  Referenced from: /opt/homebrew/Cellar/postgresql@14/14.22/bin/initdb
  Reason: tried: '/opt/homebrew/lib/postgresql@14/libpq.5.dylib' (no such file), ...
```

또는 initdb 후속 단계에서:

```
initdb: error: file "/opt/homebrew/share/postgresql@14/postgres.bki" does not exist
LOG: could not open directory "/opt/homebrew/share/postgresql@14/timezone"
FATAL: could not access file "$libdir/dict_snowball": No such file or directory
```

## 원인

brew 의 keg-only postgresql 패키지가 `/opt/homebrew/{lib,share}/postgresql@{version}/` 위치에 자동 link 되지 않음. `brew link --force` 만으로 부족.

binary 는 `/opt/homebrew/Cellar/postgresql@14/{version}/{lib,share}/postgresql@14/` 에 있는데 runtime 이 `/opt/homebrew/{lib,share}/postgresql@14/` 를 찾음.

## 해결 — 심볼릭 링크 수동 생성 (lib + share 통째로)

```bash
VER=$(brew list --versions postgresql@14 | awk '{print $2}')   # 예: 14.22
PG_CELLAR="/opt/homebrew/Cellar/postgresql@14/$VER"

# 1) lib 통째 심볼릭 (libpq, dict_snowball 등 전부 포함)
rm -rf /opt/homebrew/lib/postgresql@14
ln -sfn "$PG_CELLAR/lib/postgresql@14" /opt/homebrew/lib/postgresql@14

# 2) share 통째 심볼릭 (postgres.bki, timezone, locale 등 전부 포함)
ln -sfn "$PG_CELLAR/share/postgresql@14" /opt/homebrew/share/postgresql@14

# 3) initdb 재시도
/opt/homebrew/opt/postgresql@14/bin/initdb \
  --locale=en_US.UTF-8 -E UTF-8 \
  -D /opt/homebrew/var/postgresql@14
```

기대: `Success. You can now start the database server using: ...`

## 후속 셋업

```bash
# 서비스 시작
brew services start postgresql@14

# 확인
lsof -i :5432 -P | head

# 사용자 + DB 생성
/opt/homebrew/opt/postgresql@14/bin/psql postgres <<SQL
CREATE USER ktcmon WITH SUPERUSER PASSWORD '<LOCAL_DB_PASSWORD>';
CREATE DATABASE ktcmon OWNER ktcmon;
SQL
```

## 운영 dump 복원 (docker pg → native pg)

```bash
# docker pg 13.5 dump (custom format)
docker exec luppiter-pg pg_dump -U ktcmon -d ktcmon -Fc --no-owner --no-acl > /tmp/ktcmon.dump

# native pg 14 restore — pgcrypto extension 사전 생성
PGPASSWORD='<LOCAL_DB_PASSWORD>' /opt/homebrew/opt/postgresql@14/bin/psql -h 127.0.0.1 -p 5432 -U ktcmon -d ktcmon -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"

# restore
PGPASSWORD='<LOCAL_DB_PASSWORD>' /opt/homebrew/opt/postgresql@14/bin/pg_restore \
  -h 127.0.0.1 -p 5432 -U ktcmon -d ktcmon \
  --no-owner --no-acl --clean --if-exists \
  /tmp/ktcmon.dump
```

13.5 → 14 마이너 업그레이드 dump/restore 호환. PostgreSQL 13 brew disabled 시 14 가 차선.

## 검증 (Luppiter 기준)

```sql
-- 사용자 매핑
SELECT user_id, user_name, user_exception, exception_user_init_login 
FROM cmon_user WHERE user_id IN ('91371126','91395593');

-- 미해소 이벤트 카운트
SELECT COUNT(*) FROM cmon_event_info WHERE event_state IN ('신규','인지','조치중');
```

## 안티패턴

- ❌ `brew link --force postgresql@14` 만 실행하고 initdb 시도 (lib/share 미링크)
- ❌ `brew uninstall && reinstall` 반복 (동일 dyld 에러 재발 가능)
- ❌ `DYLD_LIBRARY_PATH` 환경변수로만 우회 (영구적이지 않음, 매번 export 필요)

## 적용 사례 (2026-04-28)

postgresql@13 brew disabled (upstream 종료) → postgresql@14 설치 → dyld libpq + share/postgres.bki + dict_snowball 3 단계 에러 → 위 절차로 해결, ktcmon DB 운영 dump(139MB) 복원 성공.

## 관련 문서

- [database-optimization.md](../db/database-optimization.md)
- [luppiter-inventory-master-sub-rules.md](../db/luppiter-inventory-master-sub-rules.md)
