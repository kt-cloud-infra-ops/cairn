---
tags:
  - type/automation
  - domain/db/schema
  - audience/claude
---

> 상위: [자동화 패턴](README.md)

# 자동화 패턴: SQL DDL 생성 및 정리 도구

## 날짜
2026-01-28

## 발견된 반복 작업

세션 중 반복되는 SQL DDL 작업:
- 문제가 있는 테이블 식별
- DROP 문 생성
- CREATE 문 재작성
- 인덱스 정의
- 제약 조건 재설정
- 검증 쿼리 작성

이 과정은 구조적이며 자동화 가능한 단계들로 구성됨

## 자동화 방법

### Option A: 슬래시 커맨드 `/generate-ddl`

```bash
/generate-ddl \
  --table cmon_event_info \
  --action cleanup \
  --backup true \
  --output sql
```

### Option B: 웹 UI 도구

대화형 DDL 생성기:
1. 테이블 선택
2. 현재 스키마 분석
3. 개선사항 제안
4. DDL 자동 생성
5. 실행 전 검증

### Option C: Python 스크립트

데이터베이스 연결 후 자동 분석

## 구현

- [x] 워크플로우 정의
- [ ] 파이썬/Go 스크립트 개발
- [ ] DDL 템플릿 라이브러리 구축
- [ ] 검증 쿼리 자동 생성
- [ ] 마이그레이션 스크립트 통합

## Python 스크립트 프로토타입

```python
#!/usr/bin/env python3
"""
SQL DDL Generator & Cleaner
데이터베이스 테이블의 DDL을 분석하고 생성
"""

import re
from typing import Dict, List, Optional
from dataclasses import dataclass

@dataclass
class ColumnDef:
    name: str
    type: str
    nullable: bool
    default: Optional[str] = None
    comment: Optional[str] = None

@dataclass
class Index:
    name: str
    columns: List[str]
    unique: bool = False

@dataclass
class TableSchema:
    name: str
    columns: List[ColumnDef]
    primary_key: Optional[str] = None
    indexes: List[Index] = None
    table_comment: Optional[str] = None

class DDLGenerator:
    """DDL 생성 및 검증 도구"""

    def __init__(self, db_connection=None):
        self.db = db_connection

    def analyze_table(self, table_name: str) -> TableSchema:
        """기존 테이블 스키마 분석"""
        # MySQL INFORMATION_SCHEMA 쿼리
        query = f"""
        SELECT
            COLUMN_NAME,
            COLUMN_TYPE,
            IS_NULLABLE,
            COLUMN_DEFAULT,
            COLUMN_COMMENT
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = '{table_name}' AND TABLE_SCHEMA = DATABASE()
        ORDER BY ORDINAL_POSITION
        """

        # 실제 구현에서는 DB 쿼리
        return TableSchema(name=table_name, columns=[])

    def generate_create_table(
        self,
        schema: TableSchema,
        engine: str = 'InnoDB',
        charset: str = 'utf8mb4'
    ) -> str:
        """CREATE TABLE 문 생성"""

        ddl = f"CREATE TABLE `{schema.name}` (\n"

        # 컬럼 정의
        for col in schema.columns:
            col_def = f"  `{col.name}` {col.type}"
            if not col.nullable:
                col_def += " NOT NULL"
            if col.default:
                col_def += f" DEFAULT {col.default}"
            if col.comment:
                col_def += f" COMMENT '{col.comment}'"
            ddl += col_def + ",\n"

        # PRIMARY KEY
        if schema.primary_key:
            ddl += f"  PRIMARY KEY (`{schema.primary_key}`),\n"

        # INDEXES
        if schema.indexes:
            for idx in schema.indexes:
                col_list = ", ".join(f"`{c}`" for c in idx.columns)
                unique = "UNIQUE" if idx.unique else ""
                ddl += f"  {unique} INDEX `{idx.name}` ({col_list}),\n"

        # 마지막 컬럼 뒤 쉼표 제거
        ddl = ddl.rstrip(",\n") + "\n"
        ddl += f") ENGINE={engine} DEFAULT CHARSET={charset}"

        if schema.table_comment:
            ddl += f" COMMENT='{schema.table_comment}'"

        return ddl + ";"

    def generate_drop_statement(self, table_name: str) -> str:
        """DROP TABLE 문 생성"""
        return f"DROP TABLE IF EXISTS `{table_name}`;"

    def generate_migration_script(
        self,
        old_table: TableSchema,
        new_table: TableSchema
    ) -> str:
        """마이그레이션 스크립트 생성"""

        script = "-- Migration Script\n\n"
        script += "BEGIN;\n\n"

        # 1. 백업
        script += f"-- Backup\n"
        script += f"CREATE TABLE `{old_table.name}_backup` LIKE `{old_table.name}`;\n"
        script += f"INSERT INTO `{old_table.name}_backup` SELECT * FROM `{old_table.name}`;\n\n"

        # 2. 기존 테이블 삭제
        script += f"-- Drop old table\n"
        script += self.generate_drop_statement(old_table.name) + "\n\n"

        # 3. 새 테이블 생성
        script += f"-- Create new table\n"
        script += self.generate_create_table(new_table) + "\n\n"

        # 4. 데이터 마이그레이션 (컬럼 매핑)
        common_cols = [c.name for c in new_table.columns
                      if any(oc.name == c.name for oc in old_table.columns)]
        if common_cols:
            col_list = ", ".join(f"`{c}`" for c in common_cols)
            script += f"-- Restore data\n"
            script += f"INSERT INTO `{new_table.name}` ({col_list}) "
            script += f"SELECT {col_list} FROM `{old_table.name}_backup`;\n\n"

        script += "COMMIT;\n"

        return script

    def generate_cleanup_queries(self, table_name: str) -> Dict[str, str]:
        """테이블 정리 쿼리 생성"""

        return {
            'check_rows': f"SELECT COUNT(*) FROM `{table_name}`;",
            'check_indexes': f"""
                SELECT INDEX_NAME, COLUMN_NAME, SEQ_IN_INDEX
                FROM INFORMATION_SCHEMA.STATISTICS
                WHERE TABLE_NAME = '{table_name}';
            """,
            'check_duplicates': f"""
                SELECT *, COUNT(*) as cnt
                FROM `{table_name}`
                GROUP BY id HAVING cnt > 1;
            """,
            'optimize': f"OPTIMIZE TABLE `{table_name}`;",
            'analyze': f"ANALYZE TABLE `{table_name}`;"
        }

if __name__ == '__main__':
    # 사용 예시
    gen = DDLGenerator()

    # 스키마 정의
    schema = TableSchema(
        name='test_table',
        columns=[
            ColumnDef('id', 'BIGINT', False, comment='Primary Key'),
            ColumnDef('name', 'VARCHAR(255)', False, comment='Name'),
            ColumnDef('created_at', 'TIMESTAMP', False, 'CURRENT_TIMESTAMP'),
            ColumnDef('updated_at', 'TIMESTAMP', False, 'CURRENT_TIMESTAMP'),
        ],
        primary_key='id',
        indexes=[
            Index('idx_name', ['name'], unique=False),
            Index('idx_created', ['created_at'], unique=False),
        ]
    )

    # DDL 생성
    print("=== CREATE TABLE ===")
    print(gen.generate_create_table(schema))

    print("\n=== DROP TABLE ===")
    print(gen.generate_drop_statement('test_table'))

    print("\n=== CLEANUP QUERIES ===")
    for name, query in gen.generate_cleanup_queries('test_table').items():
        print(f"-- {name}")
        print(query)
```

## 슬래시 커맨드 통합

```bash
#!/bin/bash
# ~/.claude/commands/generate-ddl.sh

table="${1}"
action="${2:-info}"
output="${3:-sql}"

case "$action" in
    info)
        echo "Table Schema Analysis for: $table"
        python3 /path/to/ddl_generator.py analyze "$table"
        ;;
    drop)
        python3 /path/to/ddl_generator.py drop "$table" | tee drop_${table}.sql
        ;;
    create)
        python3 /path/to/ddl_generator.py create "$table" "$output"
        ;;
    migrate)
        python3 /path/to/ddl_generator.py migrate "$table" | tee migrate_${table}.sql
        ;;
    cleanup)
        python3 /path/to/ddl_generator.py cleanup "$table"
        ;;
    *)
        echo "Usage: generate-ddl <table> [info|drop|create|migrate|cleanup] [sql|json|md]"
        ;;
esac
```

## 예상 효과

- **시간 절약**: DDL 작성 30분 → 3분 (90% 단축)
- **정확성**: 자동 생성으로 문법 오류 제거
- **재사용성**: 스키마 분석 코드 재사용
- **추적성**: 생성 이력 자동 기록
- **안전성**: 백업 및 검증 자동화

## 관련 프로젝트

- `luppiter-web`: 테이블 구조 변경
- `luppiter_scheduler`: 이벤트 테이블 관리
- `luppiter_inv`: 인벤토리 데이터 모델

## 우선순위

**HIGH** - 세션 중 DDL 작성이 반복되었고, 향후 ObservabilityEventWorker 개발 시 필요

## 관련 문서

- 현재 DDL: `/Users/jiwoong.kim/Documents/ai-team-standards/docs/o11y/02-ddl.sql`
- 성능 분석: `/Users/jiwoong.kim/Documents/ai-team-standards/docs/o11y/03-performance-analysis.md`
