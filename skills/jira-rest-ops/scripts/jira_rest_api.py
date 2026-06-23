#!/usr/bin/env python3
"""
Jira REST API Helper Class

Jira REST API를 직접 호출합니다 (MCP 의존 없음).
인증 정보는 환경변수(JIRA_*/ATLASSIAN_*) → ${JIRA_CREDENTIALS_FILE:-~/.jira-credentials.json} 순으로 로드됩니다.

Usage:
    from jira_rest_api import JiraRestAPI

    jira = JiraRestAPI()
    jira.create_task(
        project_key='YOUR_PROJECT',
        summary='예시 Task',
        description='배경/범위 요약',
        acceptance_criteria=['구체적 완료 기준 1', '요구사항 분석'],
        reporter_account_id='reporter-id',
        assignee_account_id='assignee-id',
        start_date='2026-05-08',
        due_date='2026-05-15',
        epic_link='YOUR_PROJECT-NNN',
    )
    jira.update_issue('PROJ-123', {'duedate': '2026-02-09'})
    jira.transition_issue('PROJ-123', '4')  # In Progress
"""

import json
import os
import requests
from pathlib import Path
from typing import Optional, Any
from datetime import datetime, timedelta

# Set JIRA_REPORTER_ACCOUNT_ID env var to enforce reporter on task creation.
# If unset, reporter validation is skipped (useful for unconfigured environments).
TEAM_LEAD_REPORTER_ACCOUNT_ID = os.environ.get('JIRA_REPORTER_ACCOUNT_ID', '')
TEAM_LEAD_REPORTER_NAME = os.environ.get('JIRA_REPORTER_NAME', 'reporter')


class JiraRestAPI:
    """Jira REST API 헬퍼 클래스"""

    def __init__(self):
        self._load_auth()

    def _load_auth(self):
        """인증 정보 로드: 환경변수 우선(JIRA_*/ATLASSIAN_*) → ${JIRA_CREDENTIALS_FILE:-~/.jira-credentials.json}. MCP 의존 없음."""
        jira_credentials_path = Path(os.environ.get('JIRA_CREDENTIALS_FILE', str(Path.home() / '.jira-credentials.json')))
        env = os.environ

        if (
            env.get('ATLASSIAN_BASE_URL')
            and env.get('ATLASSIAN_EMAIL')
            and env.get('ATLASSIAN_API_TOKEN')
        ):
            self.base_url = env['ATLASSIAN_BASE_URL'].rstrip('/')
            self.email = env['ATLASSIAN_EMAIL']
            self.token = env['ATLASSIAN_API_TOKEN']
            self.auth_source = 'env:ATLASSIAN_*'
            self.auth = (self.email, self.token)
            self.headers = {'Content-Type': 'application/json'}
            return

        if env.get('JIRA_EMAIL') and env.get('JIRA_API_TOKEN'):
            self.base_url = env.get('JIRA_BASE_URL', env.get('ATLASSIAN_BASE_URL', 'https://yourcompany.atlassian.net')).rstrip('/')
            self.email = env['JIRA_EMAIL']
            self.token = env['JIRA_API_TOKEN']
            self.auth_source = 'env:JIRA_*'
            self.auth = (self.email, self.token)
            self.headers = {'Content-Type': 'application/json'}
            return

        if jira_credentials_path.exists():
            credentials = json.loads(jira_credentials_path.read_text())
            self.base_url = credentials['baseUrl'].rstrip('/')
            self.email = credentials['email']
            self.token = credentials['apiToken']
            self.auth_source = str(jira_credentials_path)
            self.auth = (self.email, self.token)
            self.headers = {'Content-Type': 'application/json'}
            return

        raise RuntimeError(
            "Jira 인증 정보를 찾을 수 없습니다. 환경변수를 설정하세요:\n"
            "  export JIRA_EMAIL='you@kt.com'\n"
            "  export JIRA_API_TOKEN='<id.atlassian.com/manage-profile/security/api-tokens 발급>'\n"
            "  export JIRA_BASE_URL='https://yourcompany.atlassian.net'   # 선택(기본값)\n"
            f"또는 {jira_credentials_path} 에 email/apiToken/baseUrl 작성.\n"
            "(MCP 설정 의존은 제거됨 — REST API 직접 인증만 사용)"
        )

    def _request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        """HTTP 요청 실행"""
        url = f"{self.base_url}{endpoint}"
        response = requests.request(
            method,
            url,
            auth=self.auth,
            headers=self.headers,
            **kwargs
        )
        if response.status_code == 401:
            raise RuntimeError(
                "Jira authentication failed "
                f"(source={self.auth_source}, endpoint={endpoint}). "
                "Run auth-check first and refresh credentials if needed."
            )
        if response.status_code == 403:
            raise RuntimeError(
                "Jira permission denied "
                f"(source={self.auth_source}, endpoint={endpoint}). "
                "Credentials are accepted but this account cannot access the resource."
            )
        response.raise_for_status()
        return response

    # ========== Issue Operations ==========

    def get_issue(self, issue_key: str, fields: str = "*all") -> dict:
        """이슈 조회"""
        response = self._request('GET', f"/rest/api/3/issue/{issue_key}?fields={fields}")
        return response.json()

    def get_myself(self) -> dict:
        """현재 인증 사용자 조회"""
        response = self._request('GET', '/rest/api/3/myself')
        return response.json()

    def validate_auth(self) -> dict:
        """현재 인증 정보의 유효성 확인"""
        return self.get_myself()

    def search_jql(self, jql: str, fields: str = "*all", max_results: int = 50) -> list[dict]:
        """
        JQL 검색

        Args:
            jql: Jira Query Language
            fields: 조회할 필드 목록 (쉼표 구분)
            max_results: 최대 조회 건수
        """
        response = self._request(
            'GET',
            '/rest/api/3/search/jql',
            params={
                'jql': jql,
                'fields': fields,
                'maxResults': max_results,
            }
        )
        return response.json().get('issues', [])

    @staticmethod
    def _has_meaningful_adf_content(value: Any) -> bool:
        """ADF 문서에 실질적인 텍스트 또는 task item이 있는지 확인"""
        if not isinstance(value, dict) or value.get('type') != 'doc':
            return False

        def walk(node: Any) -> bool:
            if isinstance(node, dict):
                node_type = node.get('type')
                if node_type == 'text' and str(node.get('text', '')).strip():
                    return True
                if node_type == 'taskItem':
                    return True
                return any(walk(child) for child in node.values())
            if isinstance(node, list):
                return any(walk(item) for item in node)
            return False

        return walk(value.get('content', []))

    @staticmethod
    def _has_task_list(value: Any) -> bool:
        """ADF에 taskList/taskItem 구조가 포함돼 있는지 확인"""
        if not isinstance(value, dict):
            return False

        def walk(node: Any) -> bool:
            if isinstance(node, dict):
                if node.get('type') in {'taskList', 'taskItem'}:
                    return True
                return any(walk(child) for child in node.values())
            if isinstance(node, list):
                return any(walk(item) for item in node)
            return False

        return walk(value)

    @staticmethod
    def _is_task_issue(fields: dict) -> bool:
        issuetype = fields.get('issuetype') or {}
        name = str(issuetype.get('name', '')).strip().lower()
        return name in {'작업', 'task'}

    def _should_require_epic_link(self, fields: dict, require_epic_link: Optional[bool]) -> bool:
        if require_epic_link is not None:
            return require_epic_link
        project = fields.get('project') or {}
        # Set JIRA_EPIC_REQUIRED_PROJECT to enforce epic link for a specific project key
        epic_required_project = os.environ.get('JIRA_EPIC_REQUIRED_PROJECT', '')
        if not epic_required_project:
            return False
        return project.get('key') == epic_required_project and self._is_task_issue(fields)

    @staticmethod
    def _is_expected_reporter(reporter: Any, expected_account_id: Optional[str]) -> bool:
        if not isinstance(reporter, dict):
            return False
        reporter_account_id = str(reporter.get('accountId', '')).strip()
        if not reporter_account_id:
            return False
        # If expected_account_id is None or empty string, skip reporter enforcement
        if not expected_account_id:
            return True
        return reporter_account_id == expected_account_id

    def validate_create_payload(
        self,
        fields: dict,
        *,
        require_epic_link: Optional[bool] = None,
        expected_reporter_account_id: Optional[str] = TEAM_LEAD_REPORTER_ACCOUNT_ID,
    ) -> None:
        """신규 이슈 생성 payload의 필수 필드를 검증한다"""
        errors = []

        if not (fields.get('project') or {}).get('key'):
            errors.append('project.key is required')
        if not (fields.get('issuetype') or {}).get('name'):
            errors.append('issuetype.name is required')
        if not str(fields.get('summary', '')).strip():
            errors.append('summary is required')

        description = fields.get('description')
        if not self._has_meaningful_adf_content(description):
            errors.append('description must be a non-empty ADF document')

        if self._is_task_issue(fields):
            ac = fields.get('customfield_14516')
            if not self._has_task_list(ac):
                errors.append('customfield_14516 must include taskList/taskItem ADF')
            reporter = fields.get('reporter') or {}
            if not reporter.get('accountId'):
                errors.append('reporter.accountId is required for task creation')
            elif expected_reporter_account_id and not self._is_expected_reporter(reporter, expected_reporter_account_id):
                errors.append(
                    'reporter.accountId must match '
                    f'{TEAM_LEAD_REPORTER_NAME} ({expected_reporter_account_id})'
                )
            if not (fields.get('assignee') or {}).get('accountId'):
                errors.append('assignee.accountId is required for task creation')
            if not str(fields.get('customfield_10015', '')).strip():
                errors.append('customfield_10015 (start date) is required for task creation')
            if not str(fields.get('duedate', '')).strip():
                errors.append('duedate is required for task creation')
            if self._should_require_epic_link(fields, require_epic_link):
                if not str(fields.get('customfield_10014', '')).strip():
                    errors.append('customfield_10014 (Epic Link) is required for this task')

        if errors:
            raise ValueError('Invalid create payload: ' + '; '.join(errors))

    def audit_issue_fields(
        self,
        issue_key: str,
        *,
        require_epic_link: bool = False,
        expected_reporter_account_id: Optional[str] = TEAM_LEAD_REPORTER_ACCOUNT_ID,
    ) -> dict:
        """생성 직후 필수 필드가 실제로 채워졌는지 재조회한다"""
        fields_to_fetch = (
            'summary,description,customfield_14516,reporter,assignee,'
            'customfield_10015,duedate,customfield_10014,issuetype'
        )
        issue = self.get_issue(issue_key, fields=fields_to_fetch)
        issue_fields = issue['fields']
        missing = []
        violations = []

        if not str(issue_fields.get('summary', '')).strip():
            missing.append('summary')
        if not self._has_meaningful_adf_content(issue_fields.get('description')):
            missing.append('description')

        if self._is_task_issue(issue_fields):
            if not self._has_task_list(issue_fields.get('customfield_14516')):
                missing.append('customfield_14516')
            reporter = issue_fields.get('reporter') or {}
            if not reporter:
                missing.append('reporter')
            elif expected_reporter_account_id and not self._is_expected_reporter(reporter, expected_reporter_account_id):
                violations.append(
                    f'reporter.accountId must match {TEAM_LEAD_REPORTER_NAME} '
                    f'({expected_reporter_account_id})'
                )
            if not issue_fields.get('assignee'):
                missing.append('assignee')
            if not str(issue_fields.get('customfield_10015', '')).strip():
                missing.append('customfield_10015')
            if not str(issue_fields.get('duedate', '')).strip():
                missing.append('duedate')
            if require_epic_link and not str(issue_fields.get('customfield_10014', '')).strip():
                missing.append('customfield_10014')

        return {
            'issue_key': issue_key,
            'missing': missing,
            'violations': violations,
            'fields': issue_fields,
        }

    def create_issue(
        self,
        fields: dict,
        *,
        validate: bool = True,
        require_epic_link: Optional[bool] = None,
        expected_reporter_account_id: Optional[str] = TEAM_LEAD_REPORTER_ACCOUNT_ID,
        self_audit: bool = True
    ) -> dict:
        """검증 후 신규 이슈를 생성한다"""
        if validate:
            self.validate_create_payload(
                fields,
                require_epic_link=require_epic_link,
                expected_reporter_account_id=expected_reporter_account_id,
            )

        response = self._request('POST', '/rest/api/3/issue', json={'fields': fields})
        created = response.json()
        result = {
            'key': created['key'],
            'id': created['id'],
        }

        if self_audit:
            audit = self.audit_issue_fields(
                created['key'],
                require_epic_link=self._should_require_epic_link(fields, require_epic_link),
                expected_reporter_account_id=expected_reporter_account_id,
            )
            result['audit'] = audit
            audit_errors = audit['missing'] + audit.get('violations', [])
            if audit_errors:
                raise RuntimeError(
                    f"Created {created['key']} but self-audit failed: {', '.join(audit_errors)}"
                )

        return result

    def create_task(
        self,
        *,
        project_key: str,
        summary: str,
        description: Any,
        acceptance_criteria: Any,
        reporter_account_id: str,
        assignee_account_id: str,
        start_date: str,
        due_date: str,
        epic_link: Optional[str] = None,
        issue_type_name: str = '작업',
        labels: Optional[list[str]] = None,
        require_epic_link: Optional[bool] = None,
        expected_reporter_account_id: Optional[str] = TEAM_LEAD_REPORTER_ACCOUNT_ID,
        self_audit: bool = True
    ) -> dict:
        """팀 표준 필수 필드를 포함한 Task 생성 헬퍼"""
        description_adf = (
            description if isinstance(description, dict) else self.create_text_adf(str(description))
        )
        if isinstance(acceptance_criteria, dict):
            ac_adf = acceptance_criteria
        elif isinstance(acceptance_criteria, str):
            ac_adf = self.create_checkbox_adf([(acceptance_criteria, False)])
        else:
            ac_adf = self.create_checkbox_adf([(str(item), False) for item in acceptance_criteria])

        fields = {
            'project': {'key': project_key},
            'issuetype': {'name': issue_type_name},
            'summary': summary,
            'description': description_adf,
            'customfield_14516': ac_adf,
            'reporter': {'accountId': reporter_account_id},
            'assignee': {'accountId': assignee_account_id},
            'customfield_10015': start_date,
            'duedate': due_date,
        }

        if epic_link:
            fields['customfield_10014'] = epic_link
        if labels:
            fields['labels'] = labels

        return self.create_issue(
            fields,
            validate=True,
            require_epic_link=require_epic_link,
            expected_reporter_account_id=expected_reporter_account_id,
            self_audit=self_audit,
        )

    def update_issue(self, issue_key: str, fields: dict) -> None:
        """
        이슈 필드 업데이트

        Args:
            issue_key: 이슈 키 (예: PROJ-123)
            fields: 업데이트할 필드 딕셔너리

        Examples:
            # 기한 설정
            jira.update_issue('PROJ-123', {'duedate': '2026-02-09'})

            # 에픽 링크 설정
            jira.update_issue('PROJ-123', {'customfield_10014': 'PROJ-100'})

            # 여러 필드 동시 업데이트
            jira.update_issue('PROJ-123', {
                'duedate': '2026-02-09',
                'customfield_10014': 'PROJ-100'
            })
        """
        self._request('PUT', f"/rest/api/3/issue/{issue_key}", json={'fields': fields})

    def add_comment(self, issue_key: str, body: Any) -> dict:
        """
        이슈 댓글 추가

        Args:
            issue_key: 이슈 키
            body: ADF dict 또는 plain text
        """
        adf_body = body if isinstance(body, dict) else self.create_text_adf(str(body))
        response = self._request(
            'POST',
            f"/rest/api/3/issue/{issue_key}/comment",
            json={'body': adf_body}
        )
        return response.json()

    def delete_issue(self, issue_key: str) -> None:
        """이슈 삭제"""
        self._request('DELETE', f"/rest/api/3/issue/{issue_key}")

    # ========== Transitions ==========

    def get_transitions(self, issue_key: str) -> list:
        """
        가능한 상태 전환 목록 조회

        Returns:
            [{'id': '4', 'name': 'In Progress(진행 중)', ...}, ...]
        """
        response = self._request('GET', f"/rest/api/3/issue/{issue_key}/transitions")
        return response.json()['transitions']

    def transition_issue(self, issue_key: str, transition_id: str) -> None:
        """
        이슈 상태 전환

        Args:
            issue_key: 이슈 키
            transition_id: 전환 ID (get_transitions로 확인)

        Examples:
            # In Progress로 전환
            jira.transition_issue('PROJ-123', '4')
        """
        self._request(
            'POST',
            f"/rest/api/3/issue/{issue_key}/transitions",
            json={'transition': {'id': transition_id}}
        )

    def transition_to_status(self, issue_key: str, status_name: str) -> bool:
        """
        상태 이름으로 전환 (편의 메서드)

        Args:
            issue_key: 이슈 키
            status_name: 상태 이름 (부분 매칭, 예: 'Progress', '진행')

        Returns:
            True if successful, False if status not found
        """
        transitions = self.get_transitions(issue_key)
        for t in transitions:
            if status_name.lower() in t['name'].lower():
                self.transition_issue(issue_key, t['id'])
                return True
        return False

    # ========== ADF Helpers ==========

    @staticmethod
    def create_checkbox_adf(items: list[tuple[str, bool]]) -> dict:
        """
        체크박스 목록을 ADF 형식으로 생성

        Args:
            items: [(텍스트, 완료여부), ...] 리스트

        Returns:
            ADF document dict

        Examples:
            adf = JiraRestAPI.create_checkbox_adf([
                ('첫 번째 할 일', False),
                ('두 번째 할 일', True),
            ])
            jira.update_issue('PROJ-123', {'description': adf})
        """
        task_items = []
        for i, (text, done) in enumerate(items):
            task_items.append({
                "type": "taskItem",
                "attrs": {
                    "localId": f"task-{i+1}",
                    "state": "DONE" if done else "TODO"
                },
                "content": [{"type": "text", "text": text}]
            })

        return {
            "type": "doc",
            "version": 1,
            "content": [
                {
                    "type": "taskList",
                    "attrs": {"localId": "task-list-1"},
                    "content": task_items
                }
            ]
        }

    @staticmethod
    def create_text_adf(text: str) -> dict:
        """단순 텍스트를 ADF 형식으로 변환"""
        return {
            "type": "doc",
            "version": 1,
            "content": [
                {
                    "type": "paragraph",
                    "content": [{"type": "text", "text": text}]
                }
            ]
        }

    @staticmethod
    def create_weekly_report_adf(update_date: str, last_week: list[str], next_week: list[str]) -> dict:
        """주간보고 댓글용 ADF 생성"""

        def bullet_list(items: list[str]) -> dict:
            if not items:
                items = ['내용 보완 필요']
            return {
                "type": "bulletList",
                "content": [
                    {
                        "type": "listItem",
                        "content": [
                            {
                                "type": "paragraph",
                                "content": [{"type": "text", "text": item}]
                            }
                        ]
                    }
                    for item in items
                ]
            }

        return {
            "type": "doc",
            "version": 1,
            "content": [
                {
                    "type": "paragraph",
                    "content": [{"type": "text", "text": f"Update Date : {update_date}"}]
                },
                {
                    "type": "paragraph",
                    "content": [
                        {
                            "type": "text",
                            "text": "[지난주 진행 사항]",
                            "marks": [{"type": "strong"}]
                        }
                    ]
                },
                bullet_list(last_week),
                {
                    "type": "paragraph",
                    "content": [
                        {
                            "type": "text",
                            "text": "[금주 진행 예정]",
                            "marks": [{"type": "strong"}]
                        }
                    ]
                },
                bullet_list(next_week),
            ]
        }

    # ========== Bulk Operations ==========

    def copy_issue(
        self,
        source_key: str,
        summary_transform: Optional[callable] = None,
        reset_checkboxes: bool = True
    ) -> str:
        """
        이슈 복사

        Args:
            source_key: 원본 이슈 키
            summary_transform: 제목 변환 함수 (예: lambda s: s.replace('12월', '1월'))
            reset_checkboxes: True면 체크박스를 모두 TODO로 초기화

        Returns:
            새 이슈 키
        """
        source = self.get_issue(source_key)
        fields = source['fields']

        # 새 이슈 생성 데이터
        new_fields = {
            'project': {'key': fields['project']['key']},
            'issuetype': {'name': fields['issuetype']['name']},
            'summary': fields['summary'],
        }

        # 제목 변환
        if summary_transform:
            new_fields['summary'] = summary_transform(new_fields['summary'])

        # 선택적 필드
        if fields.get('assignee'):
            new_fields['assignee'] = {'accountId': fields['assignee']['accountId']}
        if fields.get('priority'):
            new_fields['priority'] = {'name': fields['priority']['name']}
        if fields.get('labels'):
            new_fields['labels'] = fields['labels']

        # 이슈 생성
        result = self.create_issue(
            new_fields,
            validate=False,
            require_epic_link=False,
            self_audit=False,
        )
        new_key = result['key']

        # 에픽 링크 복사
        epic_link = fields.get('customfield_10014')
        if epic_link:
            self.update_issue(new_key, {'customfield_10014': epic_link})

        return new_key

    def set_due_date_from_today(self, issue_key: str, days: int) -> str:
        """
        오늘 기준으로 기한 설정

        Args:
            issue_key: 이슈 키
            days: 오늘부터 며칠 후

        Returns:
            설정된 날짜 (YYYY-MM-DD)
        """
        due_date = (datetime.now() + timedelta(days=days)).strftime('%Y-%m-%d')
        self.update_issue(issue_key, {'duedate': due_date})
        return due_date


# ========== CLI Interface ==========

def main():
    """커맨드라인 인터페이스"""
    import argparse

    parser = argparse.ArgumentParser(description='Jira REST API Helper')
    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # update 명령
    update_parser = subparsers.add_parser('update', help='Update issue fields')
    update_parser.add_argument('issue_key', help='Issue key (e.g., PROJ-123)')
    update_parser.add_argument('--duedate', help='Due date (YYYY-MM-DD)')
    update_parser.add_argument('--epic', help='Epic link issue key')

    # transition 명령
    trans_parser = subparsers.add_parser('transition', help='Transition issue status')
    trans_parser.add_argument('issue_key', help='Issue key')
    trans_parser.add_argument('status', help='Status name (partial match)')

    # transitions 명령 (목록 조회)
    list_parser = subparsers.add_parser('transitions', help='List available transitions')
    list_parser.add_argument('issue_key', help='Issue key')

    # search 명령
    search_parser = subparsers.add_parser('search', help='Search issues by JQL')
    search_parser.add_argument('jql', help='JQL query')
    search_parser.add_argument('--fields', default='summary,status', help='Comma-separated fields')
    search_parser.add_argument('--max-results', type=int, default=20, help='Max results')

    # create-task 명령
    create_parser = subparsers.add_parser('create-task', help='Create task with required field validation')
    create_parser.add_argument('summary', help='Task summary')
    create_parser.add_argument(
        '--project',
        default=os.environ.get('JIRA_PROJECT_KEY', ''),
        help='Project key (e.g., PROJ); set JIRA_PROJECT_KEY env var or pass explicitly'
    )
    create_parser.add_argument('--issue-type', default='작업', help='Issue type name')
    create_parser.add_argument(
        '--reporter-account-id',
        required=True,
        help='Reporter accountId (set JIRA_REPORTER_ACCOUNT_ID to configure expected reporter)'
    )
    create_parser.add_argument('--assignee-account-id', required=True, help='Assignee accountId')
    create_parser.add_argument('--start-date', required=True, help='Start date YYYY-MM-DD')
    create_parser.add_argument('--due-date', required=True, help='Due date YYYY-MM-DD')
    create_parser.add_argument('--epic', help='Epic link issue key')
    create_parser.add_argument('--description-text', required=True, help='Task description plain text')
    create_parser.add_argument('--ac-item', action='append', default=[], help='Acceptance criteria item (repeatable)')
    create_parser.add_argument('--label', action='append', default=[], help='Issue label (repeatable)')
    create_parser.add_argument('--allow-missing-epic', action='store_true', help='Allow missing epic link')

    # auth-check 명령
    subparsers.add_parser('auth-check', help='Validate Jira auth and print current account')

    # comment 명령
    comment_parser = subparsers.add_parser('comment', help='Add plain text comment')
    comment_parser.add_argument('issue_key', help='Issue key')
    comment_parser.add_argument('text', help='Comment text')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    jira = JiraRestAPI()

    if args.command == 'update':
        fields = {}
        if args.duedate:
            fields['duedate'] = args.duedate
        if args.epic:
            fields['customfield_10014'] = args.epic
        if fields:
            jira.update_issue(args.issue_key, fields)
            print(f"Updated {args.issue_key}: {fields}")
        else:
            print("No fields to update")

    elif args.command == 'transition':
        if jira.transition_to_status(args.issue_key, args.status):
            print(f"Transitioned {args.issue_key} to {args.status}")
        else:
            print(f"Status '{args.status}' not found. Available:")
            for t in jira.get_transitions(args.issue_key):
                print(f"  - {t['name']}")

    elif args.command == 'transitions':
        print(f"Available transitions for {args.issue_key}:")
        for t in jira.get_transitions(args.issue_key):
            print(f"  {t['id']}: {t['name']}")

    elif args.command == 'search':
        issues = jira.search_jql(args.jql, fields=args.fields, max_results=args.max_results)
        print(json.dumps(issues, ensure_ascii=False, indent=2))

    elif args.command == 'create-task':
        if not args.ac_item:
            raise ValueError('create-task requires at least one --ac-item')
        result = jira.create_task(
            project_key=args.project,
            summary=args.summary,
            description=args.description_text,
            acceptance_criteria=args.ac_item,
            reporter_account_id=args.reporter_account_id,
            assignee_account_id=args.assignee_account_id,
            start_date=args.start_date,
            due_date=args.due_date,
            epic_link=args.epic,
            issue_type_name=args.issue_type,
            labels=args.label,
            require_epic_link=not args.allow_missing_epic,
        )
        print(json.dumps(result, ensure_ascii=False, indent=2))

    elif args.command == 'comment':
        result = jira.add_comment(args.issue_key, args.text)
        print(f"Added comment to {args.issue_key}: {result.get('id')}")

    elif args.command == 'auth-check':
        me = jira.validate_auth()
        print(json.dumps({
            'auth_source': jira.auth_source,
            'accountId': me.get('accountId'),
            'displayName': me.get('displayName'),
            'emailAddress': me.get('emailAddress'),
            'active': me.get('active'),
        }, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
