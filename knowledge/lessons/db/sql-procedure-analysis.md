---
tags:
  - type/automation
  - domain/db/query
  - service/luppiter
  - audience/claude
---

> 상위: [자동화 패턴](README.md)

# 자동화 패턴: SQL 프로시저 분석 워크플로우

## 날짜
2026-01-28

## 발견된 반복 작업

세션 중 유사한 SQL 프로시저를 여러 개 분석:
- `p_combine_event_zabbix.sql` 분석
- `p_combine_event_zenius.sql` 분석
- `p_combine_event_obs.sql` 분석 (예정)

각 분석마다 동일한 단계 반복:
1. SQL 파일 읽기
2. CREATE 블록 파싱
3. INSERT 블록에서 매핑 패턴 추출
4. 외부 테이블 참조 매핑
5. XML Mapper 파일과 상관관계 검증
6. 성능 영향 분석

## 자동화 방법

### Option A: 슬래시 커맨드 `/analyze-sql-proc`

```bash
/analyze-sql-proc <proc_name> [--type event|job|batch] [--format md|json]
```

### Option B: 파이썬 스크립트 (recommend)

SQL 프로시저 분석 자동화 스크립트 작성:
- SQL 파일 파싱 (정규표현식)
- 테이블 의존성 추출
- 성능 특성 분석 (loop count, join 수 등)
- Markdown 보고서 자동 생성

## 구현

- [x] 슬래시 커맨드 개념 정의
- [ ] 파이썬 분석 스크립트 개발
- [ ] 프로시저 분석 템플릿 생성
- [ ] `luppiter_scheduler` 프로젝트에 추가

## 스크립트 프로토타입

```python
#!/usr/bin/env python3
"""
SQL Procedure Analyzer
프로시저의 성능 특성과 의존성을 분석
"""

import re
import os
import sys
from pathlib import Path

class SQLProcedureAnalyzer:
    def __init__(self, filepath):
        self.filepath = filepath
        with open(filepath, 'r') as f:
            self.content = f.read()
        self.proc_name = Path(filepath).stem

    def extract_tables(self):
        """INSERT, UPDATE, DELETE 문에서 테이블 추출"""
        pattern = r'(?:INSERT INTO|UPDATE|DELETE FROM)\s+(\w+)'
        return re.findall(pattern, self.content, re.IGNORECASE)

    def count_loops(self):
        """LOOP 문의 개수 세기"""
        return len(re.findall(r'LOOP\s', self.content, re.IGNORECASE))

    def extract_joins(self):
        """JOIN 연산 개수 세기"""
        return len(re.findall(r'\s+JOIN\s', self.content, re.IGNORECASE))

    def analyze(self):
        """전체 분석 실행"""
        return {
            'name': self.proc_name,
            'tables': self.extract_tables(),
            'loop_count': self.count_loops(),
            'join_count': self.extract_joins(),
            'total_lines': len(self.content.split('\n'))
        }

    def generate_report_md(self):
        """Markdown 보고서 생성"""
        analysis = self.analyze()

        md = f"""# SQL Procedure Analysis: {analysis['name']}

## 기본 정보
- 파일: {self.filepath}
- 총 라인: {analysis['total_lines']}

## 의존성
### 접근 테이블
{chr(10).join(f'- `{t}`' for t in sorted(set(analysis['tables'])))}

## 성능 특성
- LOOP 블록: {analysis['loop_count']}
- JOIN 연산: {analysis['join_count']}
- 예상 영향도: {'높음' if analysis['loop_count'] > 0 else '낮음'}

## 권고사항
"""

        if analysis['loop_count'] > 0:
            md += "- LOOP 블록 최적화 검토 필요\n"
        if analysis['join_count'] > 5:
            md += "- 많은 JOIN으로 인한 성능 저하 가능성 높음\n"

        return md

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: sql_analyzer.py <procedure_file>")
        sys.exit(1)

    analyzer = SQLProcedureAnalyzer(sys.argv[1])
    print(analyzer.generate_report_md())
```

## 예상 효과

- **시간 절약**: 프로시저당 5-10분 → 1-2분 (80% 단축)
- **일관성**: 동일한 분석 틀로 누락 방지
- **재사용성**: 매번 같은 명령어로 분석 가능
- **문서화**: 자동으로 Markdown 보고서 생성

## 관련 프로젝트

- `luppiter_scheduler`: 프로시저 기반 배치 작업 분석
- `luppiter-web`: 데이터 처리 로직 분석

## 우선순위

**HIGH** - 세션 중 2회 이상 반복되었고, 향후 `p_combine_event_obs` 분석 예정
