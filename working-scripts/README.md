# MVE Working Scripts

MVE 서버 API 문서 생성 및 언리얼 엔진 프로젝트 동기화를 위한 스크립트 모음입니다.

## 📋 목차

- [스크립트 목록](#스크립트-목록)
- [사용법](#사용법)
- [워크플로우](#워크플로우)
- [출력 파일](#출력-파일)

## 📦 스크립트 목록

### 1. `sync-api-to-unreal.js` (통합 워크플로우)
**목적**: API 문서 생성부터 변경사항 분석까지 전체 프로세스를 한 번에 실행

**실행 방법**:
```bash
npm run sync
# 또는
node sync-api-to-unreal.js
```

**수행 작업**:
1. `generate-and-copy-docs.js` 실행
2. `analyze-swagger-changes.js` 실행

---

### 2. `generate-and-copy-docs.js`
**목적**:
- Login/Resource 서버의 API 문서(Swagger Spec) 생성
- 생성된 문서를 언리얼 프로젝트 `ApiSpecs` 폴더로 복사

**실행 방법**:
```bash
npm run copy-docs
# 또는
node generate-and-copy-docs.js
```

**수행 작업**:
1. `mve-login-server/scripts/analyze-response-codes.js` 실행
2. `mve-login-server/scripts/generate-api-docs.js` 실행
3. `mve-resource-server/scripts/analyze-response-codes.js` 실행
4. `mve-resource-server/scripts/generate-api-docs.js` 실행
5. 생성된 JSON 파일을 언리얼 프로젝트로 복사:
   - `login-server-api-spec.json`
   - `login-server-response-codes.json`
   - `resource-server-api-spec.json`
   - `resource-server-response-codes.json`

---

### 3. `analyze-swagger-changes.js`
**목적**:
- 기존 Swagger Spec과 새로운 Swagger Spec 비교
- 변경사항을 분석하여 언리얼 C++ 코드 변경 힌트 생성

**실행 방법**:
```bash
npm run analyze
# 또는
node analyze-swagger-changes.js
```

**수행 작업**:
1. 언리얼 프로젝트의 기존 Swagger Spec 읽기
2. 서버 프로젝트의 최신 Swagger Spec 읽기
3. 엔드포인트별 변경사항 비교:
   - 새로 추가된 API
   - 삭제된 API
   - 수정된 API (Request/Response 스키마 변경)
4. 언리얼 C++ 코드 변경 힌트 JSON 생성

**출력 파일**:
- `working-scripts/output/unreal-api-change-hints.json`

---

## 🔄 워크플로우

### 전체 동기화 프로세스

```
┌─────────────────────────────────────────────────────┐
│ 1. API 문서 생성 (generate-and-copy-docs.js)       │
├─────────────────────────────────────────────────────┤
│ - Login Server 응답 코드 분석                       │
│ - Login Server Swagger Spec 생성                    │
│ - Resource Server 응답 코드 분석                    │
│ - Resource Server Swagger Spec 생성                 │
│ - 언리얼 프로젝트 ApiSpecs 폴더로 복사              │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 2. 변경사항 분석 (analyze-swagger-changes.js)      │
├─────────────────────────────────────────────────────┤
│ - 기존 Spec vs 새 Spec 비교                         │
│ - 엔드포인트 추가/삭제/수정 감지                    │
│ - Request/Response 스키마 변경 감지                 │
│ - 언리얼 C++ 코드 변경 힌트 생성                    │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 3. AI 코드 에이전트 작업                            │
├─────────────────────────────────────────────────────┤
│ - unreal-api-change-hints.json 읽기                 │
│ - MVE_API_ResponseData.h 업데이트                   │
│   * USTRUCT 추가/수정/삭제                          │
│   * DECLARE_DELEGATE 추가                           │
│ - MVE_Http_Client.h/cpp 업데이트                    │
│   * API 함수 선언/구현 추가/수정                    │
└─────────────────────────────────────────────────────┘
```

---

## 📄 출력 파일

### 언리얼 프로젝트 복사 파일
위치: `c:\Users\user\Documents\Unreal Projects\MVE\ApiSpecs\`

- `login-server-api-spec.json` - Login Server Swagger Spec
- `login-server-response-codes.json` - Login Server 응답 코드 통계
- `resource-server-api-spec.json` - Resource Server Swagger Spec
- `resource-server-response-codes.json` - Resource Server 응답 코드 통계

### 변경사항 힌트 파일
위치: `working-scripts/output/`

- `unreal-api-change-hints.json` - 언리얼 C++ 코드 변경 힌트

**힌트 파일 구조**:
```json
{
  "metadata": {
    "generatedAt": "2024-01-01T00:00:00.000Z",
    "version": "1.0.0",
    "description": "Swagger Spec 변경사항 기반 언리얼 C++ 코드 변경 힌트"
  },
  "servers": [
    {
      "serverName": "Login Server",
      "summary": {
        "totalEndpoints": 10,
        "addedEndpoints": 2,
        "removedEndpoints": 0,
        "modifiedEndpoints": 1,
        "unchangedEndpoints": 7
      },
      "changes": {
        "newEndpoints": [
          {
            "endpoint": "POST /api/auth/new-feature",
            "path": "/api/auth/new-feature",
            "method": "POST",
            "summary": "새 기능",
            "unrealCode": {
              "functionName": "NewFeature",
              "responseStructName": "FNewFeatureResponseData",
              "delegateName": "FOnNewFeatureComplete",
              "actions": [
                {
                  "file": "MVE_API_ResponseData.h",
                  "action": "ADD_STRUCT",
                  "details": "USTRUCT FNewFeatureResponseData을 추가..."
                }
              ]
            }
          }
        ],
        "modifiedEndpoints": [
          {
            "endpoint": "POST /api/auth/login",
            "responseChanges": {
              "added": [
                {
                  "name": "newField",
                  "type": "string",
                  "cppType": "FString",
                  "description": "새로 추가된 필드"
                }
              ]
            },
            "unrealCode": {
              "actions": [
                {
                  "file": "MVE_API_ResponseData.h",
                  "action": "ADD_RESPONSE_FIELDS",
                  "details": "FLoginResponseData에 다음 필드 추가:",
                  "fields": [...]
                }
              ]
            }
          }
        ]
      }
    }
  ]
}
```

---

## 💡 사용 시나리오

### 시나리오 1: 정기적인 API 동기화
```bash
# 서버 API가 업데이트되었을 때
cd working-scripts
npm run sync

# 출력된 unreal-api-change-hints.json을 AI 에이전트에게 제공
# AI가 언리얼 코드를 자동으로 업데이트
```

### 시나리오 2: 변경사항만 확인
```bash
# API 문서는 이미 생성되어 있고, 변경사항만 분석하고 싶을 때
npm run analyze
```

### 시나리오 3: 문서만 재생성
```bash
# Swagger Spec만 다시 생성하고 복사
npm run copy-docs
```

---

## 🎯 AI 코드 에이전트 활용 가이드

생성된 `unreal-api-change-hints.json` 파일을 AI 코드 에이전트에게 다음과 같이 제공하세요:

```
프롬프트 예시:
---
첨부된 unreal-api-change-hints.json 파일을 읽고,
언리얼 엔진 C++ 프로젝트의 다음 파일들을 업데이트해주세요:

- Source/MVE/Public/MVE_API_ResponseData.h
- Source/MVE/Public/MVE_Http_Client.h
- Source/MVE/Private/MVE_Http_Client.cpp

힌트 파일의 actions 배열을 참고하여:
1. 새 엔드포인트는 USTRUCT, 델리게이트, 함수를 추가
2. 수정된 엔드포인트는 USTRUCT 필드를 수정
3. 삭제된 엔드포인트는 코드 제거 여부를 확인 후 처리

모든 변경사항을 적용한 후 컴파일 가능한 상태로 만들어주세요.
```

---

## 🛠️ 기술 스택

- **Node.js**: 스크립트 실행 환경
- **JSON**: API Spec 및 힌트 파일 포맷
- **OpenAPI 3.0**: Swagger Spec 표준

---

## 📝 참고 사항

1. **언리얼 프로젝트 경로**:
   - 기본값: `c:\Users\user\Documents\Unreal Projects\MVE`
   - 변경 시 `analyze-swagger-changes.js`의 `CONFIG` 수정 필요

2. **변경 감지 정확도**:
   - Request/Response 스키마의 최상위 properties만 비교
   - 중첩된 객체는 단순하게 처리됨
   - 복잡한 스키마는 수동 확인 권장

3. **백업**:
   - 힌트 파일 기반으로 자동 코드 수정 전 백업 권장
   - Git 커밋 후 진행 권장

---

## 🐛 트러블슈팅

### 문제: "Folder not found" 오류
**원인**: 언리얼 프로젝트 ApiSpecs 폴더가 없음
**해결**:
```bash
mkdir "c:\Users\user\Documents\Unreal Projects\MVE\ApiSpecs"
```

### 문제: Spec 파일을 읽을 수 없음
**원인**: API 문서가 아직 생성되지 않음
**해결**:
```bash
npm run copy-docs  # 먼저 문서 생성
npm run analyze    # 그 다음 분석
```

### 문제: 출력 폴더가 없음
**원인**: output 폴더가 자동 생성되지 않음
**해결**: 스크립트가 자동으로 생성하므로 별도 조치 불필요

---

## 📞 문의

문제가 발생하거나 개선 사항이 있으면 이슈를 등록해주세요.
