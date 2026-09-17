# Security Check Skills — 설계 근거 (CVE / CCE)

> **출처**: `agent_dev/docs/superpowers/specs/2026-09-17-container-cve-cce-skills-design.md`
> **적용 시점**: 2026-09-17
> **현재 구현 범위**: `skills/security-check-cve/`, `skills/security-check-cce/` 의 **SKILL.md + references/ 만** 이식 완료.
> 아래 설계 중 `scripts/*.py`, `tests/` 로 표기된 결정론적 스크립트·TDD 계획은 **미구현**이며,
> 해당 절차는 현재 SKILL.md 절차와 references/ 문서에 따라 AI가 직접 명령을 수행한다.
> 스크립트 구현 계획 원본:
> - `agent_dev/docs/superpowers/plans/2026-09-17-container-cve-remediation-skill.md`
> - `agent_dev/docs/superpowers/plans/2026-09-17-container-cce-audit-skill.md`
>
> **스킬명 매핑**: `container-cve-remediation` → `security-check-cve`, `container-cce-audit` → `security-check-cce`

---


## Goal

Create two independent Claude Code skills:

- `security-check-cve`: analyze and remediate container image CVEs.
- `security-check-cce`: audit and remediate container and Kubernetes security
  configuration against the current internal CCE guidance.

The skills produce repeatable evidence and business-readable reports without
automatically pushing images, replacing tags, changing production workloads, or
modifying Confluence.

## Source and runtime locations

Source definitions are created under:

```text
skills/security-check-cve/
skills/security-check-cce/
```

Deployment to `~/.claude/skills/` is a separate explicit action.

## Shared safety policy

- Never overwrite an existing image tag.
- Never push an image unless the user explicitly requests it.
- Never modify Kubernetes resources during diagnosis.
- Never report a build, remediation, or scan as successful without fresh
  verification evidence.
- Treat scanner `No fix` as missing fix metadata, not automatic proof that a
  vulnerability is unfixable.
- Separate fixable findings, accepted residual findings, false positives, and
  blocked checks.
- Preserve raw command evidence and identify the scanner and vulnerability
  database versions.
- Do not expose registry credentials, kubeconfig content, or application
  secrets in reports.

## Runtime preflight

Both skills run a preflight before touching an image:

- detect `docker` and `nerdctl`, record versions, and select one runtime;
- record host OS and architecture;
- verify the source image architecture and always use an explicit `--platform`;
- detect Trivy and record engine/database versions and update timestamps;
- verify registry connectivity and the configured credential helper;
- resolve the output root from a user argument, defaulting to
  `<current-working-directory>/outputs`;
- create a run ID in `YYYYMMDD-HHMMSS-<short-random>` format;
- never write generated files into the scanned source directory.

Missing required tools block the affected operation. The skill must not install
tools or silently replace a requested scanner/runtime without approval.
Validation performed through CPU emulation is labeled
`emulated / not production-verified` and is not counted as native validation.

## Skill 1: security-check-cve

### Trigger examples

- "CVE 이미지 찾아줘"
- "Harbor 이미지 취약점 조치해줘"
- "PostgreSQL/Redis CVE 처리해줘"
- "패치 Dockerfile 만들어줘"
- "이미지 목록 CVE 엑셀로 정리해줘"
- "CVE 예외 신청 사유 작성해줘"

### Supported inputs

- Harbor artifact URL.
- OCI image reference using a tag or digest.
- TXT or CSV file containing one image URL/reference per row.
- A directory containing Dockerfiles, Compose files, Helm values, or
  Kubernetes YAML from which image references are discovered.

Duplicate references are normalized by registry, repository, tag, and digest.
Digest references take precedence over mutable tags.

### Workflow

1. Collect and normalize image references.
2. Identify architecture, OS, base image, runtime user, entrypoint, command,
   package ecosystem, and application version.
3. Obtain the current vulnerability baseline with Trivy or the available Harbor
   report.
4. Group duplicate package occurrences by CVE and source package.
5. Classify each finding by severity, fix availability, runtime relevance,
   operational impact, and remediation difficulty.
6. Choose the smallest compatible remediation:
   - use a newer patch image in the same supported release line;
   - update Debian/Ubuntu/Alpine packages;
   - update an application dependency;
   - remove an unused package only when runtime checks prove it is unnecessary;
   - document an exception when no compatible remediation is available.
7. Generate a digest-pinned Dockerfile in an image-specific output directory.
8. Build a new local tag for the original architecture. Do not push.
9. Verify application version, runtime user, entrypoint, required commands,
   extensions/modules, and a product-specific smoke test.
10. Re-scan the built image with a fresh vulnerability database and compare it
    to the baseline.
11. Optionally export images as `.tar.gz` files with `SHA256SUMS`.
12. Generate Markdown and Excel reports.

Harbor host and API base are parsed from the artifact URL. Authentication uses
the active Docker/nerdctl credential helper or named robot-account environment
variables supplied by the user. Credentials are never echoed. Custom CA paths
may be supplied explicitly; TLS verification is not disabled by default.
Harbor scan data may be used as the baseline when local Trivy is unavailable,
but the report labels it with the Harbor scanner/database metadata and does not
claim a same-database before/after comparison.

### Product compatibility profiles

The skill includes reusable checks for common products and a generic fallback:

- CloudNativePG PostgreSQL: UID 26, required PostgreSQL executables,
  extensions, Barman, image type, architecture, and base-OS collation risk.
- Redis: entrypoint, command, `/data`, Redis process UID/GID, RDB/AOF, ACL,
  modules, TLS, and PING/SET/GET.
- Generic Java image: JDK version, entrypoint, JAR dependencies, JDBC drivers,
  startup command, and application health command when available.
- Generic image: image config preservation and user-provided smoke command.

### CVE Excel workbook

The workbook contains:

1. `요약`
   - total images and total unique CVEs;
   - Critical, High, Medium, and Low counts;
   - remediated, residual, exception, blocked, and false-positive counts;
   - severity and remediation-status charts;
   - per-image result summary.
2. `이미지별 결과`
   - image source, tag/digest, OS, architecture, application version;
   - before/after severity counts;
   - build, runtime validation, and scan status;
   - output image reference and artifact paths.
3. `CVE 상세`
   - image, CVE ID, package, installed/fixed versions, severity, description;
   - remediation, difficulty, operational impact, status, and evidence URL;
   - every CVE remains an atomic filterable row and repeats the image fields;
   - alternating image-group banding and borders provide visual grouping;
   - no data cells inside the autofilter range are merged.
4. `조치 결과`
   - generated Dockerfile, package/application changes, build result, test
     result, before/after counts, and residual risk.
5. `예외 신청`
   - fields ordered as `CVE ID/OS/패키지/심각도`;
   - reason category and concise non-technical reason;
   - excludes severities outside the requested exception scope.

The workbook freezes headers, enables filters, uses bounded formatting, applies
severity colors, and contains formulas for all summary counts. A merged title or
section header is allowed only outside filtered tables.

Workbook generation is implemented by
`skills/security-check-cve/scripts/build_report.py` using `openpyxl`.
The script performs a preflight import and blocks with an explicit dependency
message when `openpyxl` is unavailable; it does not auto-install packages.

The generator consumes `report-input.json`:

```json
{
  "run": {
    "id": "20260917-142500-a1b2",
    "generatedAt": "2026-09-17T14:25:00+09:00",
    "scanner": {"name": "Trivy", "version": "0.74.0", "dbUpdatedAt": "..."}
  },
  "images": [
    {
      "source": "registry/repository@sha256:...",
      "output": "local/repository:patched",
      "os": "debian",
      "architecture": "amd64",
      "application": "PostgreSQL",
      "applicationVersionBefore": "16.14",
      "applicationVersionAfter": "16.15",
      "validation": "passed|failed|blocked|emulated",
      "findings": [
        {
          "cveId": "CVE-...",
          "package": "libxml2",
          "installedVersion": "...",
          "fixedVersion": "",
          "severity": "CRITICAL",
          "description": "...",
          "status": "remediated|residual|exception|false-positive|blocked",
          "remediation": "...",
          "difficulty": "low|medium|high",
          "impact": "low|medium|high",
          "exceptionReason": "",
          "evidenceUrl": ""
        }
      ]
    }
  ]
}
```

Summary values are formulas over bounded table ranges. The generator validates
required keys, sheet names, filters, freeze panes, formulas, merged ranges, and
formula-error cells before saving the workbook.

### CVE outputs

```text
outputs/<run-id>/cve/
  summary.md
  container-cve-report.xlsx
  images/<normalized-image>/
    Dockerfile
    metadata.json
    scan-before.json
    scan-after.json
    validation.txt
  exports/
    <image>.tar.gz
    SHA256SUMS
```

## Skill 2: security-check-cce

### Trigger examples

- "CCE 진단해줘"
- "컨테이너 이미지 CCE 조치"
- "POD CCE 점검"
- "Kubernetes 보안 설정 점검"
- "CCE 미조치 사유 작성해줘"

### Authoritative references

Every run fetches these pages again because they are continuously updated:

- Diagnostic guide:
  <https://ktcloud.atlassian.net/wiki/spaces/TECHFoundation/pages/1925678414/CCE>
- POD CCE item list:
  <https://ktcloud.atlassian.net/wiki/spaces/SECC/pages/1925088343/-+POD+CCE>

Confluence is strictly read-only. The skill may use only retrieval or search
operations. It must never create, update, comment on, attach to, publish, or
otherwise modify a Confluence page.

Allowed Atlassian operations are limited to:

- `atlassian-getConfluencePage`
- `atlassian-getConfluencePageDescendants`
- `atlassian-searchConfluenceUsingCql`
- `atlassian-fetch`

Explicitly prohibited operations include:

- `atlassian-createConfluencePage`
- `atlassian-updateConfluencePage`
- `atlassian-createConfluenceFooterComment`
- `atlassian-createConfluenceInlineComment`

Before fetching the pages, the skill records:

```text
Confluence mode: READ ONLY. No page, comment, attachment, or metadata changes
will be made.
```

A verification script scans the CCE `SKILL.md`, run log, and saved tool-call
evidence for prohibited operation names. Detection is a failed run.

If Confluence cannot be read, the skill stops or marks the CCE baseline as
blocked. It must not silently use a stale embedded copy as current guidance.

### Current baseline interpretation

The skill parses the fetched pages rather than hard-coding them as permanent.
At design time, the POD list applies U-05 through U-36 with these container
N/A/removed items: U-01, U-02, U-03, U-04, U-18, and U-35.

### Workflow

1. Fetch and timestamp the two Confluence references.
2. Parse current diagnostic commands, applicable item codes, N/A rules, and
   attached-script references.
3. Resolve the Harbor artifact URL or image reference to an immutable digest,
   repository, tag, OS, and architecture.
4. Confirm that Docker or nerdctl is available and authenticate to Harbor using
   the existing credential mechanism. Never print, store, or request plaintext
   credentials in a report.
5. Pull the selected Harbor image by digest when available.
6. Start an isolated temporary container using the command pattern from the
   latest Confluence guide. Prefer `nerdctl` when that is the active runtime;
   otherwise substitute `docker`.
7. Acquire the current CCE diagnostic scripts, copy them into the container,
   set executable permissions, run them, rename each result file, and copy the
   result files back to the run evidence directory.
8. Remove the temporary container on both success and failure while preserving
   copied logs and result files.
9. Collect additional image, Dockerfile, Kubernetes workload, Helm, and
   security-context evidence.
10. Check Kubernetes manifests without applying changes.
11. Map script and manifest evidence to the current CCE item codes.
12. Classify each item as Good, Vulnerable, N/A, Blocked, or Needs Review.
13. Generate the smallest safe remediation in copied output files:
   Dockerfile, Kubernetes YAML patch, or Helm values override.
14. Build a new local image tag when Dockerfile remediation is required, then
    run the same CCE scripts against that local image.
15. Produce Markdown, Excel, exception-list, and raw-evidence outputs.

### Harbor pull and container diagnosis

The skill supports Harbor artifact URLs, image references, TXT/CSV lists, and
references discovered from Dockerfile, Helm, or Kubernetes files.

Diagnostic scripts are acquired in this order:

1. A user-supplied local script directory.
2. Downloadable attachment links exposed in the fetched Confluence page body,
   using the current authenticated read-only session.
3. Script source contained directly in fenced code blocks on the fetched page.

The skill records `scriptSource`, page ID, page version, attachment URL or
content hash, and local SHA-256. If no script can be acquired, script-based
items are `Blocked`; the skill may still perform manifest-only checks. It does
not request or persist a Confluence API token and does not use mutation APIs.

For each target it:

1. Parses a Harbor UI URL into project, repository, and artifact digest.
2. Uses the Harbor API to confirm tags, digest, architecture, and scan metadata.
3. Selects `nerdctl` or `docker` by checking the active local runtime.
4. Pulls by digest to avoid diagnosing a tag that changes during the run.
5. Generates a unique container name and starts the container with a harmless
   keep-alive command such as `tail -f /dev/null`.
6. Uses the shell available in the image (`/bin/sh`, then `/bin/bash` as a
   fallback). A distroless or shell-less image is reported as blocked and is
   not modified to force the scripts to run.
7. Copies and executes the exact diagnostic script versions referenced or
   attached by the currently fetched Confluence page.
8. Copies all result files to
   `evidence/<normalized-image>/<digest>/`.
9. Removes only the uniquely named temporary container created by the skill.

Image/filesystem CCE items are rechecked by rerunning the scripts against the
remediated local image. Kubernetes and Helm items are rechecked by parsing the
generated manifest or values override; they are never marked remediated based
only on an image script result.

Scripts first run as the image's configured user. When an applicable check
requires privileged file reads, the skill may run a second disposable
diagnostic container as root only after recording that the execution context
was overridden. Permission-denied results are `Blocked` or `Needs Review`, not
Good or Vulnerable.

The current guide's operational pattern is:

```text
pull image
run image as a temporary keep-alive container
copy script_1.sh and script_2.sh to /tmp
execute both scripts
rename linux-result.txt after each run
copy result_1.txt and result_2.txt to the host
remove the temporary container
```

The skill reconstructs commands for the selected runtime rather than blindly
copying placeholders from Confluence. It verifies actual result-file locations
inside the image because the current guide executes under `/tmp` but shows
example copies from `/home`.

### CCE checks

Checks include the current page-defined list, presently:

- password and account-file protection;
- root path and home permissions;
- file ownership and permissions;
- SUID, SGID, sticky-bit, and world-writable files;
- startup and environment files;
- cron files;
- unnecessary network services such as Finger, FTP, r-services, NFS, RPC,
  NIS, TFTP, Talk, Sendmail, and DNS;
- log review controls;
- container and Kubernetes controls such as root user, privilege escalation,
  capabilities, privileged mode, host namespaces, host paths, seccomp,
  read-only root filesystem, resource limits, and secret handling when these
  are included in the current guidance or requested scope.

### CCE Excel workbook

The workbook contains:

1. `요약`: total/applicable/Good/Vulnerable/N/A/Blocked counts, compliance
   percentage, severity distribution, image/workload summary, and charts.
2. `진단 결과`: target, CCE code, item name, result, risk, evidence,
   remediation, difficulty, impact, and reference link.
3. `조치 결과`: original value, changed value, output file, re-check result,
   and residual risk.
4. `예외 신청`: `CCE 코드/대상/항목/위험도`, reason category, and concise
   exception reason.
5. `기준 정보`: Confluence URLs, page titles, page version numbers, fetched
   timestamps, applicable items, and N/A rules.

CCE workbook generation is implemented by
`skills/security-check-cce/scripts/build_report.py`, consuming a documented
JSON structure parallel to the CVE report. It uses `openpyxl`, permits merges
only in dashboard/title areas outside filtered tables, and validates formulas,
filters, merged ranges, and rendered readability before export.

### CCE outputs

```text
outputs/<run-id>/cce/
  summary.md
  container-cce-report.xlsx
  remediation/
    Dockerfile
    kubernetes-patch.yaml
    values-cce.yaml
  exceptions.md
  evidence/
    confluence-baseline.json
    harbor-artifact.json
    pull-and-container-log.txt
    <normalized-image>/<digest>/
      result_1.txt
      result_2.txt
    raw-command-output/
```

## Error handling

- Authentication failure: identify the blocked registry, scanner, Kubernetes,
  or Confluence step without printing credentials.
- Harbor pull failure: retry only after checking the resolved repository,
  digest, architecture, registry connectivity, and existing credential helper.
  Do not fall back silently to an unverified public image.
- Container startup failure: preserve logs, remove the temporary container, and
  mark the target blocked.
- Missing shell or required script command: mark the affected checks blocked;
  do not install diagnostic packages into the original image.
- Unsupported OS/package manager: produce analysis and request a product
  profile or smoke command rather than applying speculative changes.
- Build failure: preserve logs and do not produce a success-shaped output tag.
- Runtime regression: reject the remediated image and report the failed check.
- Scanner failure or stale database: mark the security result unverified.
- Missing CCE script attachment: report the missing attachment and use only
  checks that can be reconstructed from the fetched page content.

## Dispatch boundary

- Container image CVE analysis, image patching, Trivy comparison, export, and
  Excel reporting use `security-check-cve`.
- Source-code SAST, general dependency CVE analysis without a container image,
  and repository-wide security review remain the responsibility of the
  `보안전문가` agent.
- Container/Kubernetes configuration diagnosis against the two internal pages
  uses `security-check-cce`.

The new skill descriptions include these boundaries. The existing
`보안전문가` agent description is updated only if needed to make the
container-image boundary explicit.

## Parameters

The CVE exception severity scope is explicit. Its default is residual
Critical, High, and Medium findings after remediation; Low is excluded unless
the user requests it.

The CCE report includes all applicable items by default. Exception output
includes Vulnerable and Blocked items selected by the user.

## Verification

The skills are tested with fixture inputs and dry-run examples:

- one Harbor URL;
- one digest-pinned image reference;
- a TXT/CSV image list with duplicates;
- a directory containing Dockerfile, Helm, and Kubernetes references;
- Debian/Ubuntu and Alpine patch Dockerfiles;
- PostgreSQL, Redis, Java, and generic compatibility profiles;
- CVE workbook with multiple images and multiple CVEs per image;
- CCE page parsing with page-version metadata;
- a guard proving no Confluence mutation tool is permitted;
- blocked registry, scanner, Kubernetes, and Confluence scenarios.

Generated workbooks are inspected for formulas, error cells, merged ranges,
filters, sheet names, and readable rendered previews before export.
