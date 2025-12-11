# 예시 출력 파일

## 시나리오: Login Server에 새로운 API가 추가되었을 때

서버에 `/api/auth/reset-password` API가 추가되고, `/api/auth/login` API의 응답에 `lastLoginAt` 필드가 추가된 경우의 예시 출력입니다.

### unreal-api-change-hints.json

```json
{
  "metadata": {
    "generatedAt": "2024-01-15T10:30:00.000Z",
    "version": "1.0.0",
    "description": "Swagger Spec 변경사항 기반 언리얼 C++ 코드 변경 힌트"
  },
  "warning": {
    "ko": "⚠️ 이 힌트는 자동 생성된 것으로, 지나치게 신뢰하지 마세요. 실제 코드베이스를 우선으로 고려하고, 문제가 있을 경우 반드시 사용자에게 보고하세요.",
    "en": "⚠️ This hint is auto-generated. Do not over-rely on it. Prioritize the actual codebase and report any issues to the user.",
    "important": [
      "실제 언리얼 프로젝트의 기존 코드 구조와 패턴을 먼저 확인하세요",
      "힌트는 참고용이며, 코드베이스와 충돌 시 코드베이스를 우선하세요",
      "중첩된 객체나 복잡한 타입은 수동 검토가 필요합니다",
      "변경 적용 전 사용자에게 변경 사항을 요약하여 보고하세요",
      "컴파일 에러나 로직 문제 발생 시 즉시 사용자에게 알리세요"
    ]
  },
  "servers": [
    {
      "serverName": "Login Server",
      "summary": {
        "totalEndpoints": 9,
        "addedEndpoints": 1,
        "removedEndpoints": 0,
        "modifiedEndpoints": 1,
        "unchangedEndpoints": 7
      },
      "changes": {
        "newEndpoints": [
          {
            "endpoint": "POST /api/auth/reset-password",
            "path": "/api/auth/reset-password",
            "method": "POST",
            "summary": "비밀번호 재설정",
            "description": "이메일 인증 후 비밀번호를 재설정합니다",
            "unrealCode": {
              "functionName": "ResetPassword",
              "responseStructName": "FResetPasswordResponseData",
              "delegateName": "FOnResetPasswordComplete",
              "dynamicDelegateName": "FOnResetPasswordCompleteBP",
              "actions": [
                {
                  "file": "MVE_API_ResponseData.h",
                  "action": "ADD_STRUCT",
                  "details": "USTRUCT FResetPasswordResponseData을 추가하고 응답 필드를 UPROPERTY로 정의"
                },
                {
                  "file": "MVE_API_ResponseData.h",
                  "action": "ADD_DELEGATE",
                  "details": "FOnResetPasswordComplete 델리게이트 선언 추가"
                },
                {
                  "file": "MVE_Http_Client.h",
                  "action": "ADD_FUNCTION_DECLARATION",
                  "details": "static void ResetPassword(...) 함수 선언 추가"
                },
                {
                  "file": "MVE_Http_Client.cpp",
                  "action": "ADD_FUNCTION_IMPLEMENTATION",
                  "details": "ResetPassword 함수 구현 (URL 생성, JSON 빌드, HANDLE_RESPONSE_STRUCT 매크로 사용)"
                }
              ]
            }
          }
        ],
        "removedEndpoints": [],
        "modifiedEndpoints": [
          {
            "endpoint": "POST /api/auth/login",
            "path": "/api/auth/login",
            "method": "POST",
            "summary": "로그인",
            "unrealCode": {
              "functionName": "Login",
              "responseStructName": "FLoginResponseData",
              "actions": [
                {
                  "file": "MVE_API_ResponseData.h",
                  "action": "ADD_RESPONSE_FIELDS",
                  "details": "FLoginResponseData에 다음 필드 추가:",
                  "fields": [
                    {
                      "name": "lastLoginAt",
                      "type": "string",
                      "cppType": "FString",
                      "description": "마지막 로그인 시각 (ISO 8601 format)"
                    }
                  ]
                }
              ]
            },
            "requestChanges": {
              "added": [],
              "removed": [],
              "modified": []
            },
            "responseChanges": {
              "added": [
                {
                  "name": "lastLoginAt",
                  "type": "string",
                  "description": "마지막 로그인 시각 (ISO 8601 format)"
                }
              ],
              "removed": [],
              "modified": []
            }
          }
        ]
      }
    },
    {
      "serverName": "Resource Server",
      "summary": {
        "totalEndpoints": 38,
        "addedEndpoints": 0,
        "removedEndpoints": 0,
        "modifiedEndpoints": 0,
        "unchangedEndpoints": 38
      },
      "changes": {
        "newEndpoints": [],
        "removedEndpoints": [],
        "modifiedEndpoints": []
      }
    }
  ]
}
```

## AI 코드 에이전트가 수행할 작업

### 1. MVE_API_ResponseData.h 수정

#### 새 구조체 추가
```cpp
// 새로 추가
USTRUCT(BlueprintType)
struct FResetPasswordResponseData
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category="MVE|API Response")
    bool success = false;

    UPROPERTY(BlueprintReadOnly, Category="MVE|API Response")
    FString message;
};
DECLARE_DELEGATE_ThreeParams(FOnResetPasswordComplete, bool, const FResetPasswordResponseData&, const FString&);
DECLARE_DYNAMIC_DELEGATE_ThreeParams(FOnResetPasswordCompleteBP, bool, bSuccess, const FResetPasswordResponseData&, ResponseData, const FString&, ErrorCode);
```

#### 기존 구조체 수정
```cpp
// 기존 FLoginResponseData에 필드 추가
USTRUCT(BlueprintType)
struct FLoginResponseData
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category="MVE|API Response")
    bool success = false;

    UPROPERTY(BlueprintReadOnly, Category="MVE|API Response")
    FString token;

    UPROPERTY(BlueprintReadOnly, Category="MVE|API Response")
    FString message;

    // 새로 추가된 필드
    UPROPERTY(BlueprintReadOnly, Category="MVE|API Response")
    FString lastLoginAt;
};
```

### 2. MVE_Http_Client.h 수정

```cpp
// 새 함수 선언 추가
static void ResetPassword(
    const FString& Email,
    const FString& Code,
    const FString& NewPassword,
    const FOnResetPasswordComplete& OnResult
);
```

### 3. MVE_Http_Client.cpp 수정

```cpp
// 새 함수 구현 추가
void UMVE_API_Helper::ResetPassword(
    const FString& Email,
    const FString& Code,
    const FString& NewPassword,
    const FOnResetPasswordComplete& OnResult
)
{
    const FString URL = FString::Printf(TEXT("%s/api/auth/reset-password"), *LoginServerURL);

    TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
    JsonObject->SetStringField(TEXT("email"), Email);
    JsonObject->SetStringField(TEXT("code"), Code);
    JsonObject->SetStringField(TEXT("newPassword"), NewPassword);

    FString JsonBody;
    TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonBody);
    FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);

    FMVE_HTTP_Client::SendPostRequest(
        URL,
        JsonBody,
        "",
        HANDLE_RESPONSE_STRUCT(FResetPasswordResponseData, OnResult)
    );
}
```

## 콘솔 출력 예시

```
================================================================================
🔍 Swagger Spec 변경사항 분석 및 언리얼 코드 힌트 생성
================================================================================

📖 Spec 파일 로딩 중...

📋 Login Server 분석 중...
  ✅ 분석 완료
     - 전체 엔드포인트: 9
     - 추가: 1
     - 삭제: 0
     - 수정: 1
     - 변경 없음: 7

📋 Resource Server 분석 중...
  ✅ 분석 완료
     - 전체 엔드포인트: 38
     - 추가: 0
     - 삭제: 0
     - 수정: 0
     - 변경 없음: 38

🎯 언리얼 코드 변경 힌트 생성 중...

💾 결과 저장 중: C:\Users\user\Documents\mve-servers\working-scripts\output\unreal-api-change-hints.json
  ✅ 저장 완료

================================================================================
📊 변경사항 요약
================================================================================

📦 Login Server
  - 새 엔드포인트: 1개
  - 삭제된 엔드포인트: 0개
  - 수정된 엔드포인트: 1개

  🆕 새 엔드포인트 목록:
     - POST /api/auth/reset-password: 비밀번호 재설정
       함수명: ResetPassword

  ✏️  수정된 엔드포인트 목록:
     - POST /api/auth/login
       작업 수: 1개

📦 Resource Server
  - 새 엔드포인트: 0개
  - 삭제된 엔드포인트: 0개
  - 수정된 엔드포인트: 0개

================================================================================
🎉 분석 완료!

📁 힌트 파일 위치: C:\Users\user\Documents\mve-servers\working-scripts\output\unreal-api-change-hints.json
📄 파일 크기: 3.42 KB

💡 이 힌트 파일을 AI 코드 에이전트에게 제공하여
   언리얼 C++ 코드 업데이트를 자동화할 수 있습니다.
```

## AI 에이전트 프롬프트 예시

```
첨부된 unreal-api-change-hints.json 파일을 읽고 분석해주세요.

다음 언리얼 엔진 C++ 파일들을 업데이트해주세요:
- Source/MVE/Public/MVE_API_ResponseData.h
- Source/MVE/Public/MVE_Http_Client.h
- Source/MVE/Private/MVE_Http_Client.cpp

힌트 파일의 내용에 따라:

1. **새 엔드포인트 (newEndpoints)**:
   - MVE_API_ResponseData.h에 USTRUCT와 DECLARE_DELEGATE 추가
   - MVE_Http_Client.h에 함수 선언 추가
   - MVE_Http_Client.cpp에 함수 구현 추가

2. **수정된 엔드포인트 (modifiedEndpoints)**:
   - responseChanges.added: USTRUCT에 새 필드 추가
   - requestChanges.added: 함수 파라미터 추가

3. **코드 스타일 유지**:
   - 기존 코드의 스타일과 일관성 유지
   - UPROPERTY 매크로 사용
   - BlueprintReadOnly 카테고리 설정
   - HANDLE_RESPONSE_STRUCT 매크로 활용

모든 변경사항을 적용한 후 컴파일 가능한 상태로 만들어주세요.
```
