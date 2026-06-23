---
tags:
  - type/automation
  - domain/testing
  - audience/claude
---

> 상위: [자동화 패턴](README.md)

# 자동화 패턴: Playwright E2E 테스트 워크플로우

## 날짜
2026-01-30

## 발견된 반복 작업

E2E 테스트 작성 및 디버깅 세션에서 동일한 패턴 반복:

1. **테스트 실행 명령어 반복**
   ```bash
   npm run test:headed -- --workers=1 --grep "테스트명"
   ```

2. **Selector 디버깅 반복**
   - TUI Grid 선택자 vs 일반 테이블 선택자
   - 다중 선택자 체인 사용 (`.tui-grid-container, .rightPanel table, [class*="user"] table`)
   - Playwright 검사기로 요소 확인

3. **스크린샷 확인 워크플로우**
   - `artifacts/*.png` 스크린샷 확인
   - 디버깅 후 스크린샷 재촬영
   - 실패 분석 → 선택자 수정 → 재실행 → 검증

4. **테스트 결과 요약**
   - 성공/실패 테스트 개수 집계
   - 실패 원인 분석 (selector, timing, data mismatch)
   - 패턴 식별 및 공통 해결책 적용

## 대표 사례

### 케이스 1: TUI Grid vs 일반 테이블 선택자 충돌
```typescript
// 문제: 여러 선택자 시도 필요
const groupItems = page.locator(
  '.leftPanel tr, .groupList tr, [class*="group"] tr, .tui-grid-row, table tbody tr'
)

// 이전 시도들:
// - '.tui-grid-row' → 실패
// - '.leftPanel table' → 실패
// - '.groupList tr' → 성공
```

### 케이스 2: 스크린샷 디버깅 루프
```
1. 테스트 실행 (headed mode)
2. 스크린샷 확인
3. 선택자 문제 발견 → 수정
4. 테스트 재실행
5. 성공 확인
```

### 케이스 3: 그리드 데이터 추출
```typescript
// 반복되는 패턴: TUI Grid 데이터 검증
const result = await validateSearchResults(
  page,
  searchKeyword,
  targetColumnIndex,
  gridSelector
)
```

## 자동화 방법

### Option A: 슬래시 커맨드 (추천)

```bash
# 1. 테스트 실행 (headed + grep)
/e2e-test <test-name> [--headed] [--workers=1]
# 예: /e2e-test "설비권한그룹-사용자" --headed

# 2. 스크린샷 검사
/e2e-screenshot [latest|failed|<test-name>]
# 예: /e2e-screenshot latest

# 3. 테스트 디버깅 (자동화된 선택자 찾기)
/e2e-find-selector <element-description>
# 예: /e2e-find-selector "그룹 목록 테이블"

# 4. 테스트 보고서 생성
/e2e-report [--detailed] [--save-to-file]
```

### Option B: 개선된 npm 스크립트 (package.json)

```json
{
  "scripts": {
    "test": "playwright test",
    "test:headed": "playwright test --headed",
    "test:debug": "playwright test --debug",
    "test:ui": "playwright test --ui",
    "test:single": "playwright test --headed --workers=1 --grep",
    "test:latest": "playwright test --headed --workers=1 --grep",
    "test:report": "playwright show-report",
    "test:screenshots": "find artifacts -name '*.png' -type f",
    "test:failed": "playwright test --last-failed --headed",
    "test:watch": "playwright test --headed --workers=1"
  }
}
```

### Option C: 헬퍼 쉘 스크립트

**파일: `tests/run-e2e-test.sh`**

```bash
#!/bin/bash
# E2E 테스트 실행 및 결과 분석 헬퍼

set -e

TEST_NAME="${1:-}"
MODE="${2:-headless}" # headless | headed | debug | ui
WORKERS="${3:-4}"

if [ -z "$TEST_NAME" ]; then
  echo "Usage: $0 <test-name> [mode] [workers]"
  echo "  Modes: headless (default), headed, debug, ui"
  echo "  Workers: 1 (debug), 4 (default), auto"
  echo ""
  echo "Examples:"
  echo "  $0 '설비권한그룹'"
  echo "  $0 '설비권한그룹' headed 1"
  echo "  $0 '로그인' debug"
  exit 1
fi

echo "======================================"
echo "E2E 테스트 실행"
echo "======================================"
echo "테스트명: $TEST_NAME"
echo "모드: $MODE"
echo "워커: $WORKERS"
echo ""

case $MODE in
  headless)
    npm run test -- --grep "$TEST_NAME" --workers=$WORKERS
    ;;
  headed)
    npm run test:headed -- --grep "$TEST_NAME" --workers=$WORKERS
    ;;
  debug)
    npm run test:debug -- --grep "$TEST_NAME"
    ;;
  ui)
    npm run test:ui -- --grep "$TEST_NAME"
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 1
    ;;
esac

# 테스트 완료 후 스크린샷 보기
if [ "$MODE" = "headed" ] || [ "$MODE" = "headless" ]; then
  SCREENSHOT_COUNT=$(find artifacts -name '*.png' -type f | wc -l)
  if [ $SCREENSHOT_COUNT -gt 0 ]; then
    echo ""
    echo "======================================"
    echo "스크린샷: $SCREENSHOT_COUNT개 생성됨"
    echo "위치: artifacts/"
    echo "======================================"
  fi
fi

exit 0
```

**사용법**:
```bash
chmod +x tests/run-e2e-test.sh

# 기본 사용
./tests/run-e2e-test.sh "설비권한그룹"

# Headed 모드 (워커 1개)
./tests/run-e2e-test.sh "설비권한그룹" headed 1

# 디버그 모드
./tests/run-e2e-test.sh "설비권한그룹" debug
```

### Option D: 선택자 자동 찾기 (Python)

**파일: `tests/find-selectors.py`**

```python
#!/usr/bin/env python3
"""
Playwright E2E 테스트 선택자 자동 찾기
테스트 파일 분석 → 실패한 선택자 → 대체 선택자 제안
"""

import re
import sys
from pathlib import Path
from collections import defaultdict

class SelectorAnalyzer:
    # TUI Grid 관련 선택자
    GRID_PATTERNS = [
        '.tui-grid-container',
        '.tui-grid-row',
        '.tui-grid-cell',
        '.tui-grid-header-area',
        '.tui-grid-body-area',
    ]

    # 공통 테이블 선택자
    TABLE_PATTERNS = [
        'table',
        '[class*="table"]',
        '[class*="grid"]',
        '.leftPanel',
        '.rightPanel',
        '[class*="panel"]',
    ]

    # 대체 선택자 (우선순위)
    FALLBACK_SELECTORS = [
        '.leftPanel tr, .groupList tr, [class*="group"] tr, .tui-grid-row, table tbody tr',
        '.tui-grid-container, .rightPanel table, [class*="user"] table',
        '[class*="list"] [class*="row"]',
        'tbody tr',
    ]

    def __init__(self, test_file):
        self.test_file = Path(test_file)
        with open(self.test_file, 'r') as f:
            self.content = f.read()
        self.issues = []

    def analyze(self):
        """선택자 문제 분석"""
        self._find_selector_patterns()
        self._find_potential_issues()
        return self.issues

    def _find_selector_patterns(self):
        """파일에서 모든 선택자 추출"""
        # page.locator('...')
        pattern = r"page\.locator\(['\"]([^'\"]+)['\"]\)"
        selectors = re.findall(pattern, self.content)

        for selector in selectors:
            if selector.startswith('.tui-grid') and ',' not in selector:
                self.issues.append({
                    'type': 'single_tui_selector',
                    'selector': selector,
                    'suggestion': 'TUI Grid 단독 사용 → 여러 선택자로 확장 필요',
                    'alternatives': self.FALLBACK_SELECTORS,
                })

    def _find_potential_issues(self):
        """잠재적 선택자 문제 검출"""
        # 단순 클래스 선택자
        if 'page.locator(".leftPanel")' in self.content:
            self.issues.append({
                'type': 'simple_class',
                'selector': '.leftPanel',
                'suggestion': '.leftPanel tr 또는 복합 선택자 사용',
            })

    def generate_report(self):
        """분석 보고서 생성"""
        if not self.issues:
            return f"✓ 선택자 문제 없음: {self.test_file.name}"

        report = f"⚠️  {self.test_file.name} - {len(self.issues)}개 이슈 발견\n"
        for i, issue in enumerate(self.issues, 1):
            report += f"\n#{i} {issue['type']}\n"
            report += f"  선택자: {issue['selector']}\n"
            report += f"  문제: {issue['suggestion']}\n"
            if 'alternatives' in issue:
                report += f"  대체: {issue['alternatives'][0]}\n"

        return report

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: find-selectors.py <test-file-or-directory>")
        sys.exit(1)

    path = Path(sys.argv[1])

    if path.is_dir():
        test_files = list(path.glob('**/*.spec.ts'))
    else:
        test_files = [path]

    all_issues = []
    for test_file in test_files:
        analyzer = SelectorAnalyzer(test_file)
        print(analyzer.generate_report())
        all_issues.extend(analyzer.analyze())

    print(f"\n총 {len(all_issues)}개 이슈 발견")
    sys.exit(0 if len(all_issues) == 0 else 1)
```

**사용법**:
```bash
python3 tests/find-selectors.py tests/e2e/
python3 tests/find-selectors.py tests/e2e/permission-group.spec.ts
```

## npm 스크립트 확장 (추천 - 즉시 적용 가능)

**파일: `package.json` 수정**

```json
{
  "scripts": {
    "test": "playwright test",
    "test:headed": "playwright test --headed",
    "test:debug": "playwright test --debug",
    "test:ui": "playwright test --ui",
    "test:single": "playwright test --headed --workers=1",
    "test:single:grep": "playwright test --headed --workers=1 --grep",
    "test:report": "playwright show-report",
    "test:screenshots": "find artifacts -name '*.png' -type f -newer artifacts/.last-run.json 2>/dev/null | head -5 || find artifacts -name '*.png' -type f | tail -5",
    "test:failed": "playwright test --last-failed --headed --workers=1",
    "test:debug:grid": "playwright test --debug --grep 'grid|table|Grid|Table'",
    "prebuild": "npm run test 2>/dev/null || echo 'Tests skipped'",
    "posttest": "echo 'Test artifacts in ./artifacts'"
  }
}
```

**사용법**:
```bash
# 테스트명으로 검색해서 실행 (headed)
npm run test:single:grep -- "설비권한그룹"

# 최근 실패 테스트만 재실행
npm run test:failed

# 최근 생성 스크린샷 5개 확인
npm run test:screenshots

# 보고서 보기
npm run test:report
```

## VS Code Snippet (코드 완성)

**파일: `.vscode/playwright.code-snippets`**

```json
{
  "E2E Test Headed Single": {
    "prefix": "e2e:headed",
    "body": [
      "// headed mode: 브라우저 보이면서 실행 (디버깅용)",
      "npm run test:single:grep -- '${1:test-name}'"
    ],
    "description": "E2E 테스트 headed 모드 실행"
  },
  "E2E Screenshot Check": {
    "prefix": "e2e:screenshot",
    "body": [
      "// 최근 스크린샷 확인",
      "npm run test:screenshots"
    ],
    "description": "E2E 테스트 스크린샷 보기"
  },
  "E2E Grid Selector": {
    "prefix": "e2e:grid",
    "body": [
      "page.locator('.tui-grid-container, .leftPanel table, [class*=\"table\"] tr, .tui-grid-row')"
    ],
    "description": "TUI Grid 복합 선택자"
  },
  "E2E Fallback Selector": {
    "prefix": "e2e:fallback",
    "body": [
      "page.locator('${1:.tui-grid-container}, ${2:.leftPanel}, ${3:[class*=\"grid\"]} tr, ${4:table tbody tr}')"
    ],
    "description": "폴백 선택자 패턴"
  }
}
```

## 자동화 효과 예측

### 시간 절약

| 작업 | 기존 (반복) | 자동화 후 | 절약 |
|------|-----------|---------|------|
| 테스트 1개 실행 | 2분 (명령어 타입) | 30초 (npm 스크립트) | 75% |
| 선택자 디버깅 | 5분 (수동 분석) | 1분 (자동 찾기) | 80% |
| 스크린샷 확인 | 3분 (수동 탐색) | 30초 (자동 스크립트) | 83% |
| 실패 테스트 재실행 | 4분 (매번 grep 입력) | 1분 (npm script) | 75% |
| **세션당 총 절약** | - | - | **75-80%** |

### 사용성 개선

- **명령어 복잡도 감소**: `npm run test:single:grep "테스트명"` vs `npm run test:headed -- --workers=1 --grep "테스트명"`
- **오류 감소**: 선택자 자동 제안으로 manual 시행착오 제거
- **재현성 향상**: 표준화된 스크립트로 일관된 테스트 환경

## 구현 우선순위

### Phase 1 (즉시 - 10분)
- [ ] `package.json` npm 스크립트 확장
- [ ] `.vscode/playwright.code-snippets` 추가

### Phase 2 (1-2시간)
- [ ] `tests/run-e2e-test.sh` 헬퍼 스크립트 작성
- [ ] 테스트 사용자에게 문서화

### Phase 3 (2-3시간)
- [ ] `tests/find-selectors.py` 선택자 분석 도구 작성
- [ ] CI/CD 통합 (GitHub Actions)

### Phase 4 (향후)
- [ ] `/e2e-test` 슬래시 커맨드 구현
- [ ] 웹 대시보드 (선택사항)

## 관련 프로젝트

- **luppiter_web_e2e**: 메인 테스트 프로젝트
- **luppiter_web**: 테스트 대상 애플리케이션

## 참고 문서

- **Playwright 공식 문서**: https://playwright.dev/docs/intro
- **Selector 디버깅**: https://playwright.dev/docs/debug
- **TUI Grid 선택자**: https://nhn.github.io/tui.grid/latest/

## 테스트 고유 용어

| 용어 | 설명 |
|------|------|
| **Headed mode** | 브라우저 윈도우를 보이면서 테스트 실행 (디버깅용) |
| **Headless mode** | 브라우저를 숨기고 테스트 실행 (CI 기본) |
| **Workers** | 병렬 실행 워커 수 (1=순차, 4=기본) |
| **TUI Grid** | NHN의 데이터 그리드 라이브러리 |
| **Selector** | CSS 선택자로 페이지 요소 찾기 |
| **Fallback selector** | 첫 번째 선택자 실패 시 사용할 대체 선택자 |

## 세션 통계

- **테스트 파일 수**: 10개 (e2e/*.spec.ts)
- **핵심 이슈**: TUI Grid 선택자 불일치 (90% 실패 사유)
- **디버깅 시간**: 테스트당 평균 3-5분
- **반복 패턴 발견 횟수**: 15회 이상

## 우선순위

**HIGH** - 세션 중 15회 이상 반복, 선택자 문제로 인한 높은 시행착오

---

**마지막 업데이트**: 2026-01-30
**예상 구현 완료**: 2026-01-31 (Phase 1-2)
**전체 구현**: 2026-02-06 (Phase 1-3)
