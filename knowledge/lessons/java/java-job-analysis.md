---
tags:
  - type/automation
  - domain/java/spring
  - service/luppiter
  - audience/claude
---

> 상위: [자동화 패턴](README.md)

# 자동화 패턴: Java Job 클래스 분석 체크리스트

## 날짜
2026-01-28

## 발견된 반복 작업

세션 중 유사한 Job 클래스를 여러 개 분석:
- `CombineEventServiceJob` 분석
- `EventAlarmServiceJob` 분석
- 향후 ObservabilityEventWorker 분석 예정

각 분석마다 동일한 단계 반복:
1. 클래스 구조 파악 (implements, extends)
2. 메서드 서명 추출
3. 외부 호출 식별 (DB, API, 메시지큐)
4. 에러 처리 패턴 검증
5. 루프 구조 분석 (배치 사이즈, 청크 단위)
6. 타이밍 관련 코드 검토 (delay, timeout)
7. 리소스 정리 (finally, try-with-resources) 확인
8. 결과 문서화

## 자동화 방법

### Option A: 체크리스트 템플릿

매번 분석할 때 사용할 표준화된 체크리스트 제공

### Option B: 정적 분석 스크립트

AST(Abstract Syntax Tree) 파싱을 통한 자동 분석:
- 메서드 추출 및 복잡도 계산
- 외부 호출 분석
- 에러 처리 패턴 감지
- 성능 위험 신호 탐지

## 구현

- [x] 분석 템플릿 정의
- [ ] 자바 정적 분석 스크립트 개발
- [ ] IDE 플러그인 또는 CLI 도구 생성
- [ ] `luppiter-web` 프로젝트에 적용

## 분석 체크리스트

```markdown
# Java Job 클래스 분석: [클래스명]

## 1. 클래스 구조
- [ ] Runnable/Callable 구현 확인
- [ ] Scheduled/Job 인터페이스 정의 확인
- [ ] 생성자의 의존성 주입 확인
- [ ] 싱글톤/프로토타입 scope 확인

## 2. 메서드 분석
- [ ] run/execute 메인 메서드 라인 수: ____
- [ ] 메서드 분리 적절한 수준: Y/N
- [ ] 순환 복잡도 계산: ____
- [ ] 깊은 중첩 (>4단계) 확인: Y/N

## 3. 외부 호출
- [ ] DB 쿼리 수: ____ (Mapper 문 개수)
- [ ] API 호출: Y/N (몇 개?)
- [ ] 파일 I/O: Y/N
- [ ] 메시지 발행: Y/N

## 4. 에러 처리
- [ ] try-catch 블록 모두 로깅: Y/N
- [ ] 특정 예외 처리: Y/N (아니면 범용?)
- [ ] 재시도 로직: Y/N
- [ ] 타임아웃 설정: Y/N

## 5. 배치 처리
- [ ] 루프 있음: Y/N
- [ ] 한 번에 처리하는 개수: ____
- [ ] 청크 단위: ____
- [ ] 페이징 처리: Y/N

## 6. 리소스 관리
- [ ] try-with-resources 사용: Y/N
- [ ] finally 블록: Y/N
- [ ] 리소스 정리 코드: Y/N
- [ ] 메모리 누수 위험: Y/N

## 7. 성능 고려사항
- [ ] N+1 쿼리 패턴 확인: Y/N
- [ ] 대량 데이터 처리 안전: Y/N
- [ ] 메모리 사용량 추정: ____ MB
- [ ] 예상 실행 시간: ____ 분

## 8. 모니터링/로깅
- [ ] 시작/종료 로그: Y/N
- [ ] 처리 건수 로그: Y/N
- [ ] 에러율 로그: Y/N
- [ ] 성능 지표: Y/N

## 주요 발견사항
1.
2.
3.

## 개선 제안
1.
2.
3.
```

## 정적 분석 스크립트 프로토타입

```python
#!/usr/bin/env python3
"""
Java Job Class Analyzer
Job 클래스의 구조, 성능, 안전성을 분석
"""

import re
import os
from pathlib import Path
from collections import defaultdict

class JavaJobAnalyzer:
    def __init__(self, filepath):
        self.filepath = filepath
        with open(filepath, 'r') as f:
            self.content = f.read()
        self.classname = Path(filepath).stem

    def extract_methods(self):
        """메서드 추출"""
        pattern = r'(?:public|private|protected)\s+(?:synchronized\s+)?(\w+)\s+(\w+)\s*\([^)]*\)\s*(?:throws[^{]+)?\{'
        return re.findall(pattern, self.content)

    def count_try_catch(self):
        """try-catch 블록 개수"""
        return len(re.findall(r'try\s*\{', self.content))

    def find_db_calls(self):
        """DB 호출 (Mapper/Repository) 식별"""
        patterns = [
            r'(\w+Mapper)\.',
            r'(\w+Repository)\.',
            r'jdbcTemplate\.',
            r'sqlSession\.'
        ]
        results = []
        for pattern in patterns:
            results.extend(re.findall(pattern, self.content))
        return list(set(results))

    def find_loops(self):
        """루프 구조 찾기"""
        for_loops = len(re.findall(r'for\s*\(', self.content))
        while_loops = len(re.findall(r'while\s*\(', self.content))
        return {'for': for_loops, 'while': while_loops}

    def analyze_complexity(self):
        """순환 복잡도 대략 계산"""
        conditions = len(re.findall(r'\bif\b', self.content))
        switches = len(re.findall(r'\bswitch\b', self.content))
        operators = len(re.findall(r'(\?\s*:|&&|\|\|)', self.content))
        return conditions + switches + operators

    def generate_report(self):
        """분석 보고서 생성"""
        methods = self.extract_methods()
        try_catches = self.count_try_catch()
        db_calls = self.find_db_calls()
        loops = self.find_loops()
        complexity = self.analyze_complexity()

        report = f"""# Java Job 분석: {self.classname}

## 구조
- 메서드 수: {len(methods)}
- 주요 메서드: {', '.join(m[1] for m in methods[:5])}

## 복잡도
- 순환 복잡도: {complexity} (높음 주의: >10)
- 루프: for {loops['for']}, while {loops['while']}

## 외부 연동
- DB 호출: {len(db_calls)} ({', '.join(db_calls)})
- try-catch: {try_catches}

## 권고사항
"""

        if complexity > 10:
            report += f"- 순환 복잡도({complexity})가 높음 - 메서드 분리 검토\n"
        if try_catches < 1 and len(db_calls) > 0:
            report += "- DB 호출이 있는데 예외 처리 없음 - 에러 처리 추가\n"
        if loops['for'] + loops['while'] > 2:
            report += "- 중첩 루프가 많음 - 성능 최적화 검토\n"

        return report

if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print("Usage: job_analyzer.py <java_file>")
        sys.exit(1)

    analyzer = JavaJobAnalyzer(sys.argv[1])
    print(analyzer.generate_report())
```

## 예상 효과

- **시간 절약**: 클래스당 10-15분 → 3-5분 (70% 단축)
- **일관성**: 누락 없는 체계적 분석
- **문서화**: 표준화된 분석 결과
- **재사용성**: 동일한 체크리스트로 여러 클래스 분석

## 관련 프로젝트

- `luppiter-web`: Job 클래스 기반 배치 처리
- `luppiter_scheduler`: 스케줄 기반 작업 분석

## 우선순위

**HIGH** - 세션 중 2회 이상 반복되었고, ObservabilityEventWorker 분석 예정
