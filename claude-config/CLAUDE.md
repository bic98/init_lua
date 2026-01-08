# Claude Code Global Settings

이 파일은 모든 프로젝트에서 적용되는 글로벌 지침입니다.
`~/.claude/CLAUDE.md`에 위치합니다.

## 사용 가능한 에이전트

| 에이전트 | 설명 | 트리거 |
|---------|------|--------|
| `document-organizer` | 문서 정리/변환 | "문서 정리해줘", "PDF를 Word로" |
| `report-generator` | 보고서 자동 생성 | "보고서 만들어줘", "분석해줘" |
| `data-extractor` | 데이터 추출 | "표 추출해줘", "데이터 뽑아줘" |
| `supervisor` | 멀티에이전트 오케스트레이터 | "팀으로 작업해줘" |
| `reviewer` | 검토/피드백 | "검토해줘", "피드백 줘" |
| `writer` | 콘텐츠 작성 | "글 써줘", "작성해줘" |

## MCP 서버 (선택)

문서 작업 강화를 위한 MCP 서버:
- `pdf-reader`: PDF 읽기
- `word`: Word 문서 생성/편집
- `excel`: Excel 파일 처리
- `powerpoint`: PPT 생성/편집

> 설치 방법은 README.md 참고

## 협업 워크플로우

복잡한 작업 시 에이전트들이 협력:

```
[요청] → supervisor (작업 분배)
           ↓
    data-extractor (데이터 추출)
           ↓
    report-generator (분석)
           ↓
        writer (초안 작성)
           ↓
       reviewer (검토/피드백)
           ↓
        writer (수정)
           ↓
       [완성]
```

## 커스터마이징

이 파일을 수정하여 개인 설정을 추가할 수 있습니다:

```markdown
## 나의 설정

### 선호하는 언어
- 한국어로 응답

### 자주 쓰는 프로젝트 경로
- ~/projects/
- ~/work/

### 기타 지침
- ...
```
