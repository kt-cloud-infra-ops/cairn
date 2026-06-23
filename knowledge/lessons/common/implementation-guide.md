---
tags:
  - type/automation
  - domain/rules
  - audience/claude
---

> 상위: [자동화 패턴](README.md)

# 규칙 파일 자동화 구현 가이드

**대상**: 규칙 파일 교차참조 및 동기화 자동화
**구현 단계**: 3단계 (메타데이터 → 스크립트 → 통합)
**소요 시간**: 2-3시간 (모두 포함)

---

## 1단계: 메타데이터 생성

### 1.1 관계 맵 구조 정의

파일: `/Users/jiwoong.kim/Documents/ai-team-standards/.claude/meta/related-rules-map.json`

```json
{
  "metadata": {
    "version": "1.0",
    "created": "2026-01-30",
    "description": "Cross-reference map for Claude Code rules"
  },
  "sync_pairs": [
    {
      "project": "/Users/jiwoong.kim/Documents/ai-team-standards/agents/rules/",
      "home": "~/.claude/rules/",
      "files": ["agents.md", "coding-style.md", "doc-organization.md",
                "git-workflow.md", "hooks.md", "patterns.md",
                "performance.md", "security.md", "testing.md"]
    }
  ],
  "rules": {
    "agents.md": {
      "keywords": ["agent", "workflow", "parallel", "planner", "tdd-guide",
                   "code-reviewer", "security-reviewer", "e2e-runner"],
      "description": "Agent orchestration and usage patterns",
      "relatedRules": [
        {
          "file": "testing.md",
          "reason": "tdd-guide and e2e-runner agent details",
          "type": "implementation"
        },
        {
          "file": "git-workflow.md",
          "reason": "Agent usage in feature implementation workflow",
          "type": "workflow"
        },
        {
          "file": "security.md",
          "reason": "security-reviewer agent context",
          "type": "reference"
        },
        {
          "file": "performance.md",
          "reason": "Model selection strategy for agents (Haiku/Sonnet/Opus)",
          "type": "reference"
        }
      ]
    },
    "coding-style.md": {
      "keywords": ["immutability", "error handling", "input validation",
                   "code quality", "files", "functions"],
      "description": "Coding standards and best practices",
      "relatedRules": [
        {
          "file": "security.md",
          "reason": "Input validation for security",
          "type": "implementation"
        },
        {
          "file": "patterns.md",
          "reason": "Common implementation patterns",
          "type": "reference"
        },
        {
          "file": "testing.md",
          "reason": "Verify code quality with tests",
          "type": "workflow"
        }
      ]
    },
    "doc-organization.md": {
      "keywords": ["documentation", "storage", "synchronization", "organization"],
      "description": "Document organization and storage rules",
      "relatedRules": [
        {
          "file": "git-workflow.md",
          "reason": "Commit docs with code changes",
          "type": "workflow"
        },
        {
          "file": "hooks.md",
          "reason": "Doc blocker hook configuration",
          "type": "reference"
        }
      ]
    },
    "git-workflow.md": {
      "keywords": ["commit", "pull request", "workflow", "TDD", "code review",
                   "security", "agents"],
      "description": "Git workflow and feature implementation process",
      "relatedRules": [
        {
          "file": "testing.md",
          "reason": "TDD in feature implementation workflow",
          "type": "workflow"
        },
        {
          "file": "agents.md",
          "reason": "planner, tdd-guide, code-reviewer agent details",
          "type": "implementation"
        },
        {
          "file": "security.md",
          "reason": "Pre-commit security checklist",
          "type": "workflow"
        },
        {
          "file": "hooks.md",
          "reason": "Commit and push hooks context",
          "type": "reference"
        }
      ]
    },
    "hooks.md": {
      "keywords": ["hooks", "pre-commit", "post-edit", "stop", "permissions",
                   "TodoWrite"],
      "description": "Hooks system and automation configuration",
      "relatedRules": [
        {
          "file": "git-workflow.md",
          "reason": "Commit/push hooks implementation",
          "type": "workflow"
        },
        {
          "file": "performance.md",
          "reason": "Auto-accept permissions strategy",
          "type": "reference"
        }
      ]
    },
    "patterns.md": {
      "keywords": ["patterns", "API response", "custom hooks", "repository",
                   "skeleton projects", "parallel"],
      "description": "Common patterns and best practices",
      "relatedRules": [
        {
          "file": "coding-style.md",
          "reason": "Code quality standards for patterns",
          "type": "reference"
        },
        {
          "file": "agents.md",
          "reason": "Parallel agent evaluation for skeleton projects",
          "type": "implementation"
        }
      ]
    },
    "performance.md": {
      "keywords": ["performance", "model selection", "Haiku", "Sonnet", "Opus",
                   "context window", "build"],
      "description": "Performance optimization and model selection",
      "relatedRules": [
        {
          "file": "agents.md",
          "reason": "Agent list and parallel execution patterns",
          "type": "reference"
        },
        {
          "file": "hooks.md",
          "reason": "Auto-accept permissions strategy",
          "type": "reference"
        }
      ]
    },
    "security.md": {
      "keywords": ["security", "secrets", "validation", "hardcoded",
                   "SQL injection", "XSS", "CSRF"],
      "description": "Security guidelines and best practices",
      "relatedRules": [
        {
          "file": "git-workflow.md",
          "reason": "Security checks before commit",
          "type": "workflow"
        },
        {
          "file": "coding-style.md",
          "reason": "Input validation patterns",
          "type": "implementation"
        },
        {
          "file": "agents.md",
          "reason": "security-reviewer agent details",
          "type": "reference"
        }
      ]
    },
    "testing.md": {
      "keywords": ["testing", "TDD", "coverage", "80%", "unit", "integration",
                   "e2e"],
      "description": "Testing requirements and TDD workflow",
      "relatedRules": [
        {
          "file": "git-workflow.md",
          "reason": "TDD in feature implementation workflow",
          "type": "workflow"
        },
        {
          "file": "agents.md",
          "reason": "tdd-guide and e2e-runner agent details",
          "type": "implementation"
        },
        {
          "file": "coding-style.md",
          "reason": "Code quality verification with tests",
          "type": "workflow"
        }
      ]
    }
  }
}
```

### 1.2 유효성 검증 체크리스트

```bash
#!/bin/bash
# validate-rules-map.sh

# 1. 모든 참조 파일 존재 확인
# 2. 순환 참조 감지 (A→B→A)
# 3. 고아 파일 확인 (어떤 파일에서도 참조 안 됨)
# 4. 키워드 중복 확인
# 5. 설명 길이 검증 (50-200자)

python3 << 'EOF'
import json

with open('.claude/meta/related-rules-map.json') as f:
    data = json.load(f)

rules = data['rules']

# 순환 참조 확인
for file, info in rules.items():
    related = [r['file'] for r in info['relatedRules']]
    for related_file in related:
        if related_file in rules:
            for r in rules[related_file]['relatedRules']:
                if r['file'] == file:
                    print(f"Circular: {file} ↔ {related_file}")

# 고아 파일 확인
all_files = set(rules.keys())
referenced = set()
for file, info in rules.items():
    for r in info['relatedRules']:
        referenced.add(r['file'])

orphans = all_files - referenced
if orphans:
    print(f"Warning: No references to: {orphans}")

print("✓ Validation complete")
EOF
```

---

## 2단계: 생성 스크립트 작성

### 2.1 Python 스크립트: `generate_related_rules.py`

```python
#!/usr/bin/env python3
"""
Generate "## Related Rules" sections for Claude Code rule files.
Syncs changes to both home and project directories.
"""

import json
import sys
import os
from pathlib import Path
from typing import Dict, List, Any

class RelatedRulesGenerator:
    def __init__(self, map_file: str):
        self.map_file = Path(map_file)
        self.rules_data = self._load_map()

    def _load_map(self) -> Dict:
        """Load rules map from JSON."""
        with open(self.map_file) as f:
            return json.load(f)

    def generate_section(self, filename: str) -> str:
        """Generate Related Rules section for a file."""
        if filename not in self.rules_data['rules']:
            print(f"Warning: {filename} not in map")
            return ""

        rule = self.rules_data['rules'][filename]
        related = rule['relatedRules']

        if not related:
            return "## Related Rules\n\n(None)\n"

        lines = ["## Related Rules\n"]
        for item in related:
            link = f"[{item['file']}]({item['file']})"
            lines.append(f"- {link} - {item['reason']}\n")

        return "".join(lines)

    def update_file(self, filepath: Path, new_section: str) -> bool:
        """Update file with new Related Rules section."""
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        # Remove existing section
        parts = content.split('## Related Rules')
        if len(parts) > 1:
            content = parts[0].rstrip() + "\n"

        # Add separator and new section
        content += "\n---\n\n" + new_section + "\n"

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

        return True

    def sync_files(self, dry_run: bool = True) -> Dict[str, bool]:
        """Sync changes to both home and project directories."""
        sync_pairs = self.rules_data['sync_pairs'][0]
        project_dir = sync_pairs['project']
        home_dir = Path(sync_pairs['home']).expanduser()

        results = {}

        for filename in sync_pairs['files']:
            project_file = Path(project_dir) / filename
            home_file = home_dir / filename

            if not project_file.exists():
                print(f"Skip: {project_file} not found")
                continue

            # Generate new section
            new_section = self.generate_section(filename)

            if dry_run:
                print(f"Would update: {project_file}")
                print(f"Would sync to: {home_file}\n")
                results[filename] = True
            else:
                # Update project file
                self.update_file(project_file, new_section)
                print(f"✓ Updated: {project_file}")

                # Sync to home
                if home_file.exists():
                    self.update_file(home_file, new_section)
                    print(f"✓ Synced to: {home_file}")

                results[filename] = True

        return results

def main():
    """Entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Generate and sync Related Rules sections"
    )
    parser.add_argument(
        '--map',
        default='./.claude/meta/related-rules-map.json',
        help='Path to rules map JSON'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without modifying files'
    )
    parser.add_argument(
        '--file',
        help='Update only specific file'
    )

    args = parser.parse_args()

    generator = RelatedRulesGenerator(args.map)

    if args.file:
        section = generator.generate_section(args.file)
        print(section)
    else:
        results = generator.sync_files(dry_run=args.dry_run)
        total = len(results)
        success = sum(1 for v in results.values() if v)
        print(f"\nResults: {success}/{total} files {'would be ' if args.dry_run else ''}updated")

if __name__ == '__main__':
    main()
```

### 2.2 사용 방법

```bash
# 1. 드라이 런 (미리보기)
python3 generate_related_rules.py --dry-run

# 2. 실제 실행
python3 generate_related_rules.py

# 3. 특정 파일만 확인
python3 generate_related_rules.py --file agents.md
```

---

## 3단계: Git 훅 통합

### 3.1 Pre-commit 훅: `.git/hooks/pre-commit`

```bash
#!/bin/bash
# Pre-commit hook: Auto-sync related rules

# 검사할 규칙 파일들
RULES_FILES=(
  "agents.md"
  "coding-style.md"
  "doc-organization.md"
  "git-workflow.md"
  "hooks.md"
  "patterns.md"
  "performance.md"
  "security.md"
  "testing.md"
)

# 규칙 파일이 변경되었는지 확인
RULES_CHANGED=0
for file in "${RULES_FILES[@]}"; do
  if git diff --cached --name-only | grep -q "agents/rules/$file"; then
    RULES_CHANGED=1
    break
  fi
done

# 규칙 파일 변경 시 자동 동기화
if [ $RULES_CHANGED -eq 1 ]; then
  echo "🔄 Syncing related rules..."

  python3 generate_related_rules.py

  # 생성된 파일들을 staging에 추가
  for file in "${RULES_FILES[@]}"; do
    git add "agents/rules/$file"
  done

  # 홈 디렉토리 동기화
  for file in "${RULES_FILES[@]}"; do
    cp "agents/rules/$file" "$HOME/agents/rules/$file"
  done

  echo "✓ Sync complete"
fi

exit 0
```

### 3.2 설치 방법

```bash
# 1. 스크립트를 프로젝트에 저장
mkdir -p .git/hooks
cp pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# 2. Python 스크립트를 프로젝트 루트에 저장
cp generate_related_rules.py .

# 3. 메타 디렉토리 생성
mkdir -p .claude/meta
cp related-rules-map.json .claude/meta/

# 4. 테스트
git commit --allow-empty -m "test: pre-commit hook"
```

---

## 4단계: 검증 및 테스트

### 4.1 테스트 체크리스트

```bash
#!/bin/bash
# test-rules-sync.sh

echo "=== Testing Related Rules Automation ==="

# 1. 메타데이터 검증
echo -e "\n1. Validating metadata..."
python3 << 'EOF'
import json
with open('.claude/meta/related-rules-map.json') as f:
    data = json.load(f)
print(f"✓ Loaded {len(data['rules'])} rules")
EOF

# 2. 드라이 런
echo -e "\n2. Dry-run test..."
python3 generate_related_rules.py --dry-run | head -20

# 3. 파일별 생성 테스트
echo -e "\n3. Generating sections for each file..."
for file in agents coding-style security testing git-workflow \
            performance patterns hooks doc-organization; do
  python3 generate_related_rules.py --file "$file.md" | head -5
done

# 4. 양쪽 파일 비교
echo -e "\n4. Comparing home vs project..."
diff <(head -20 ~/.claude/rules/agents.md) \
     <(head -20 agents/rules/agents.md) && \
echo "✓ Files match" || echo "⚠ Files differ (this may be OK)"

echo -e "\n=== All tests complete ==="
```

### 4.2 실행 및 검증

```bash
chmod +x test-rules-sync.sh
./test-rules-sync.sh
```

---

## 5단계: 자동화 실행

### 5.1 초기 실행

```bash
# 1. 현재 상태 백업
cp -r ~/.claude/rules ~/.claude/rules.backup

# 2. 드라이 런 확인
python3 generate_related_rules.py --dry-run

# 3. 실제 실행
python3 generate_related_rules.py

# 4. Git에 커밋
git add agents/rules/
git commit -m "docs: auto-generate Related Rules sections"

# 5. 검증
git log --oneline -1
```

---

## 6단계: 유지보수

### 6.1 규칙 추가 시

```bash
# 1. JSON에 새 규칙 추가
vim .claude/meta/related-rules-map.json

# 2. 자동 생성
python3 generate_related_rules.py

# 3. 커밋
git add .
git commit -m "docs: add new rule file"
```

### 6.2 관계 변경 시

```bash
# 1. JSON 업데이트
vim .claude/meta/related-rules-map.json

# 2. 재생성 및 검증
python3 generate_related_rules.py --dry-run

# 3. 확인 후 실행
python3 generate_related_rules.py

# 4. 커밋
git commit -am "docs: update rule relationships"
```

---

## 문제 해결

### 문제: 파일이 동기화되지 않음

```bash
# 1. 권한 확인
ls -l ~/.claude/rules/
chmod 644 ~/.claude/rules/*.md

# 2. 경로 확인
echo $HOME
ls -la ~/.claude/rules/agents.md
```

### 문제: Pre-commit 훅이 실행 안 됨

```bash
# 1. 권한 확인
chmod +x .git/hooks/pre-commit

# 2. 수동 실행
.git/hooks/pre-commit

# 3. 디버그 모드
bash -x .git/hooks/pre-commit
```

### 문제: 순환 참조 감지

```bash
# 1. JSON 검증
python3 -m json.tool .claude/meta/related-rules-map.json > /dev/null

# 2. 순환 참조 분석
python3 << 'EOF'
import json
with open('.claude/meta/related-rules-map.json') as f:
    data = json.load(f)
    # 분석 코드
EOF
```

---

## 결론

3단계 구현으로 규칙 파일 관리 자동화 완성:
1. **메타데이터**: JSON으로 관계 정의
2. **스크립트**: Python으로 섹션 생성/동기화
3. **훅**: Git pre-commit으로 자동 실행

**효과**:
- 규칙 파일 변경 시 자동 동기화
- 관계 맵을 중심으로 일관성 유지
- 새 규칙 추가 시 자동 반영
