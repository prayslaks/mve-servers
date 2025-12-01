# Unreal Engine HTTP Client Guide - MVE Servers

## 개요
이 문서는 언리얼 엔진 C++ 프로젝트에서 **MVE 서버(Login Server + Resource Server)**의 API를 호출하는 방법을 안내합니다.

## 목차
1. [환경 설정](#환경-설정)
2. [기본 HTTP 클라이언트 구현](#기본-http-클라이언트-구현)
3. [Login Server API 호출](#login-server-api-호출)
4. [Resource Server API 호출](#resource-server-api-호출)
5. [에러 처리](#에러-처리)
6. [실전 예제](#실전-예제)

---

## 환경 설정

### 1. Build.cs 설정
프로젝트의 `[YourProject].Build.cs` 파일에 HTTP 모듈을 추가합니다.

```csharp
PublicDependencyModuleNames.AddRange(new string[] {
    "Core",
    "CoreUObject",
    "Engine",
    "InputCore",
    "Http",           // HTTP 요청
    "Json",           // JSON 파싱
    "JsonUtilities"   // JSON 유틸리티
});
```

### 2. 헤더 파일 포함
```cpp
#include "Http.h"
#include "HttpModule.h"
#include "Interfaces/IHttpRequest.h"
#include "Interfaces/IHttpResponse.h"
#include "Json.h"
#include "JsonUtilities.h"
```

### 3. 서버 URL 설정
```cpp
// 개발 환경 (로컬)
#define SERVER_URL TEXT("http://localhost")
#define LOGIN_PORT TEXT("3000")
#define RESOURCE_PORT TEXT("3001")

// 프로덕션 환경 (AWS EC2 예시)
// #define SERVER_URL TEXT("http://your-ec2-domain.compute.amazonaws.com")
// Nginx를 사용하면 포트 구분 불필요 (80번 포트로 통일)

// 전체 URL 구성
FString LoginServerURL = FString::Printf(TEXT("%s:%s"), SERVER_URL, LOGIN_PORT);
FString ResourceServerURL = FString::Printf(TEXT("%s:%s"), SERVER_URL, RESOURCE_PORT);
```

---

## 기본 HTTP 클라이언트 구현

### HTTP 요청 헬퍼 클래스 (MVEHttpClient.h)
```cpp
#pragma once

#include "CoreMinimal.h"
#include "Http.h"

DECLARE_DELEGATE_TwoParams(FOnHttpResponse, bool /*bSuccess*/, const FString& /*ResponseBody*/);

class YOURPROJECT_API FMVEHttpClient
{
public:
    // GET 요청
    static void SendGetRequest(const FString& URL, const FString& AuthToken, FOnHttpResponse OnComplete);

    // POST 요청 (JSON)
    static void SendPostRequest(const FString& URL, const FString& JsonBody, const FString& AuthToken, FOnHttpResponse OnComplete);

    // PUT 요청 (JSON)
    static void SendPutRequest(const FString& URL, const FString& JsonBody, const FString& AuthToken, FOnHttpResponse OnComplete);

    // DELETE 요청
    static void SendDeleteRequest(const FString& URL, const FString& AuthToken, FOnHttpResponse OnComplete);

    // POST 요청 (Multipart Form Data - 파일 업로드)
    static void SendMultipartRequest(const FString& URL, const TArray<uint8>& FileData, const FString& FileName,
                                      const TMap<FString, FString>& FormFields, const FString& AuthToken, FOnHttpResponse OnComplete);

private:
    static void OnResponseReceived(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful, FOnHttpResponse Callback);
};
```

### 구현부 (MVEHttpClient.cpp)
```cpp
#include "MVEHttpClient.h"
#include "HttpModule.h"
#include "Interfaces/IHttpRequest.h"
#include "Interfaces/IHttpResponse.h"

void FMVEHttpClient::SendGetRequest(const FString& URL, const FString& AuthToken, FOnHttpResponse OnComplete)
{
    TSharedRef<IHttpRequest> Request = FHttpModule::Get().CreateRequest();
    Request->SetVerb("GET");
    Request->SetURL(URL);
    Request->SetHeader("Content-Type", "application/json");

    if (!AuthToken.IsEmpty())
    {
        Request->SetHeader("Authorization", FString::Printf(TEXT("Bearer %s"), *AuthToken));
    }
    
    Request->OnProcessRequestComplete().BindStatic(&FMVEHttpClient::OnResponseReceived, OnComplete);
    Request->ProcessRequest();
}

void FMVEHttpClient::SendPostRequest(const FString& URL, const FString& JsonBody, const FString& AuthToken, FOnHttpResponse OnComplete)
{
    TSharedRef<IHttpRequest> Request = FHttpModule::Get().CreateRequest();
    Request->SetVerb("POST");
    Request->SetURL(URL);
    Request->SetHeader("Content-Type", "application/json");
    Request->SetContentAsString(JsonBody);

    if (!AuthToken.IsEmpty())
    {
        Request->SetHeader("Authorization", FString::Printf(TEXT("Bearer %s"), *AuthToken));
    }
    
    Request->OnProcessRequestComplete().BindStatic(&FMVEHttpClient::OnResponseReceived, OnComplete);
    Request->ProcessRequest();
}

void FMVEHttpClient::SendPutRequest(const FString& URL, const FString& JsonBody, const FString& AuthToken, FOnHttpResponse OnComplete)
{
    TSharedRef<IHttpRequest> Request = FHttpModule::Get().CreateRequest();
    Request->SetVerb("PUT");
    Request->SetURL(URL);
    Request->SetHeader("Content-Type", "application/json");
    Request->SetContentAsString(JsonBody);

    if (!AuthToken.IsEmpty())
    {
        Request->SetHeader("Authorization", FString::Printf(TEXT("Bearer %s"), *AuthToken));
    }
    
    Request->OnProcessRequestComplete().BindStatic(&FMVEHttpClient::OnResponseReceived, OnComplete);
    Request->ProcessRequest();
}

void FMVEHttpClient::SendDeleteRequest(const FString& URL, const FString& AuthToken, FOnHttpResponse OnComplete)
{
    TSharedRef<IHttpRequest> Request = FHttpModule::Get().CreateRequest();
    Request->SetVerb("DELETE");
    Request->SetURL(URL);
    Request->SetHeader("Content-Type", "application/json");

    if (!AuthToken.IsEmpty())
    {
        Request->SetHeader("Authorization", FString::Printf(TEXT("Bearer %s"), *AuthToken));
    }
    
    Request->OnProcessRequestComplete().BindStatic(&FMVEHttpClient::OnResponseReceived, OnComplete);
    Request->ProcessRequest();
}

void FMVEHttpClient::SendMultipartRequest(const FString& URL, const TArray<uint8>& FileData, const FString& FileName,
    const TMap<FString, FString>& FormFields, const FString& AuthToken, FOnHttpResponse OnComplete)
{
    FString Boundary = FString::Printf(TEXT("----UnrealBoundary%d"), FMath::RandRange(100000, 999999));

    TArray<uint8> CombinedContent;
    FString BeginBoundary = FString::Printf(TEXT("--%s\r\n"), *Boundary);
    FString EndBoundary = FString::Printf(TEXT("\r\n--%s--\r\n"), *Boundary);
    
    // Form 필드 추가
    for (const TPair<FString, FString>& Field : FormFields)
    {
        FString FieldHeader = FString::Printf(
            TEXT("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n"),
            *Boundary, *Field.Key, *Field.Value
        );
        CombinedContent.Append((uint8*)TCHAR_TO_UTF8(*FieldHeader), FieldHeader.Len());
    }
    
    // 파일 필드 추가
    FString FileHeader = FString::Printf(
        TEXT("--%s\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"%s\"\r\nContent-Type: application/octet-stream\r\n\r\n"),
        *Boundary, *FileName
    );
    CombinedContent.Append((uint8*)TCHAR_TO_UTF8(*FileHeader), FileHeader.Len());
    CombinedContent.Append(FileData);
    CombinedContent.Append((uint8*)TCHAR_TO_UTF8(*EndBoundary), EndBoundary.Len());
    
    TSharedRef<IHttpRequest> Request = FHttpModule::Get().CreateRequest();
    Request->SetVerb("POST");
    Request->SetURL(URL);
    Request->SetHeader("Content-Type", FString::Printf(TEXT("multipart/form-data; boundary=%s"), *Boundary));
    Request->SetContent(CombinedContent);
    
    if (!AuthToken.IsEmpty())
    {
        Request->SetHeader("Authorization", FString::Printf(TEXT("Bearer %s"), *AuthToken));
    }
    
    Request->OnProcessRequestComplete().BindStatic(&FMVEHttpClient::OnResponseReceived, OnComplete);
    Request->ProcessRequest();
}

void FMVEHttpClient::OnResponseReceived(FHttpRequestPtr Request, FHttpResponsePtr Response, bool bWasSuccessful, FOnHttpResponse Callback)
{
    if (bWasSuccessful && Response.IsValid())
    {
        int32 StatusCode = Response->GetResponseCode();
        FString ResponseBody = Response->GetContentAsString();

        // 200번대 응답을 성공으로 간주
        bool bSuccess = (StatusCode >= 200 && StatusCode < 300);
        Callback.ExecuteIfBound(bSuccess, ResponseBody);
    }
    else
    {
        Callback.ExecuteIfBound(false, TEXT("{\"success\": false, \"error\": \"NETWORK_ERROR\", \"message\": \"Network request failed\"}"));
    }
}
```

---

## Login Server API 호출

### 1. 회원가입 (Signup)
```cpp
void SignUp(const FString& Username, const FString& Email, const FString& Password)
{
    FString URL = FString::Printf(TEXT("%s/api/auth/signup"), *LoginServerURL);

    // JSON 생성
    TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
    JsonObject->SetStringField("username", Username);
    JsonObject->SetStringField("email", Email);
    JsonObject->SetStringField("password", Password);

    FString JsonBody;
    TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonBody);
    FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);

    // HTTP 요청
    FMVEHttpClient::SendPostRequest(URL, JsonBody, "",
        FOnHttpResponse::CreateLambda([](bool bSuccess, const FString& ResponseBody)
        {
            if (bSuccess)
            {
                TSharedPtr<FJsonObject> JsonResponse;
                TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(ResponseBody);

                if (FJsonSerializer::Deserialize(Reader, JsonResponse) && JsonResponse.IsValid())
                {
                    bool bResponseSuccess = JsonResponse->GetBoolField("success");
                    if (bResponseSuccess)
                    {
                        // 회원가입 성공
                        const TSharedPtr<FJsonObject>* UserObject;
                        if (JsonResponse->TryGetObjectField("user", UserObject))
                        {
                            int32 UserId = (*UserObject)->GetIntegerField("id");
                            FString Username = (*UserObject)->GetStringField("username");
                            UE_LOG(LogTemp, Log, TEXT("Signup Success: ID=%d, Username=%s"), UserId, *Username);
                        }
                    }
                    else
                    {
                        // 회원가입 실패
                        FString ErrorCode = JsonResponse->GetStringField("error");
                        FString ErrorMessage = JsonResponse->GetStringField("message");
                        UE_LOG(LogTemp, Error, TEXT("Signup Failed: %s - %s"), *ErrorCode, *ErrorMessage);
                    }
                }
            }
        })
    );
}
```

### 2. 이메일 인증번호 발송
```cpp
void SendVerificationCode(const FString& Email)
{
    FString URL = FString::Printf(TEXT("%s/api/auth/send-verification"), *LoginServerURL);
    // ... JSON 생성 및 요청 코드 (생략된 부분은 위와 유사한 패턴) ...
}
```

### 3. 로그인 (Login)
```cpp
// 전역 변수로 JWT 토큰 저장
FString GlobalAuthToken;

void Login(const FString& Username, const FString& Password)
{
    FString URL = FString::Printf(TEXT("%s/api/auth/login"), *LoginServerURL);

    TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
    JsonObject->SetStringField("username", Username);
    JsonObject->SetStringField("password", Password);
    
    FString JsonBody;
    TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonBody);
    FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);
    
    FMVEHttpClient::SendPostRequest(URL, JsonBody, "",
        FOnHttpResponse::CreateLambda([](bool bSuccess, const FString& ResponseBody)
        {
            if (bSuccess)
            {
                TSharedPtr<FJsonObject> JsonResponse;
                TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(ResponseBody);
                
                if (FJsonSerializer::Deserialize(Reader, JsonResponse) && JsonResponse.IsValid())
                {
                    if (JsonResponse->GetBoolField("success"))
                    {
                        // JWT 토큰 저장
                        GlobalAuthToken = JsonResponse->GetStringField("token");
                        
                        const TSharedPtr<FJsonObject>* UserObject;
                        if (JsonResponse->TryGetObjectField("user", UserObject))
                        {
                            int32 UserId = (*UserObject)->GetIntegerField("id");
                            FString Username = (*UserObject)->GetStringField("username");
                            
                            UE_LOG(LogTemp, Log, TEXT("Login Success: %s (ID: %d)"), *Username, UserId);
                            UE_LOG(LogTemp, Log, TEXT("Auth Token: %s"), *GlobalAuthToken);
                        }
                    }
                }
            }
        })
    );
}
```

---

## Resource Server API 호출

### 1. 음원 목록 조회
```cpp
void GetAudioList()
{
    FString URL = FString::Printf(TEXT("%s/api/audio/list"), *ResourceServerURL);

    FMVEHttpClient::SendGetRequest(URL, GlobalAuthToken,
        FOnHttpResponse::CreateLambda([](bool bSuccess, const FString& ResponseBody)
        {
            TSharedPtr<FJsonObject> JsonResponse;
            TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(ResponseBody);

            if (FJsonSerializer::Deserialize(Reader, JsonResponse) && JsonResponse.IsValid())
            {
                if (JsonResponse->GetBoolField("success"))
                {
                    const TArray<TSharedPtr<FJsonValue>>* AudioFiles;
                    if (JsonResponse->TryGetArrayField("audio_files", AudioFiles))
                    {
                        for (const TSharedPtr<FJsonValue>& AudioValue : *AudioFiles)
                        {
                            const TSharedPtr<FJsonObject>* AudioObject;
                            if (AudioValue->TryGetObject(AudioObject))
                            {
                                int32 Id = (*AudioObject)->GetIntegerField("id");
                                FString Title = (*AudioObject)->GetStringField("title");
                                int32 Duration = (*AudioObject)->GetIntegerField("duration");
                                UE_LOG(LogTemp, Log, TEXT("Audio: [%d] %s (%ds)"), Id, *Title, Duration);
                            }
                        }
                    }
                }
            }
        })
    );
}
```

### 2. 콘서트 생성
```cpp
void CreateConcert(const FString& ConcertName, const TArray<int32>& AudioIds, int32 MaxAudience)
{
    FString URL = FString::Printf(TEXT("%s/api/concert/create"), *ResourceServerURL);

    TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject);
    JsonObject->SetStringField("concertName", ConcertName);
    JsonObject->SetNumberField("maxAudience", MaxAudience);

    // Songs 배열 생성
    TArray<TSharedPtr<FJsonValue>> SongsArray;
    for (int32 i = 0; i < AudioIds.Num(); ++i)
    {
        TSharedPtr<FJsonObject> SongObject = MakeShareable(new FJsonObject);
        SongObject->SetNumberField("songNum", i + 1);
        SongObject->SetNumberField("audioId", AudioIds[i]);
        SongsArray.Add(MakeShareable(new FJsonValueObject(SongObject)));
    }
    JsonObject->SetArrayField("songs", SongsArray);

    FString JsonBody;
    TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonBody);
    FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);

    FMVEHttpClient::SendPostRequest(URL, JsonBody, GlobalAuthToken,
        FOnHttpResponse::CreateLambda([](bool bSuccess, const FString& ResponseBody)
        {
             // ... 응답 처리 ...
        })
    );
}
```

---

## 에러 처리

### 에러 코드별 중앙 처리
```cpp
void HandleAPIError(const FString& ResponseBody)
{
    TSharedPtr<FJsonObject> JsonResponse;
    TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(ResponseBody);

    if (FJsonSerializer::Deserialize(Reader, JsonResponse) && JsonResponse.IsValid())
    {
        bool bSuccess = JsonResponse->GetBoolField("success");

        if (!bSuccess)
        {
            FString ErrorCode = JsonResponse->GetStringField("error");
            FString ErrorMessage = JsonResponse->GetStringField("message");
            
            if (ErrorCode == "TOKEN_EXPIRED")
            {
                UE_LOG(LogTemp, Warning, TEXT("Token expired. Please login again."));
            }
            else if (ErrorCode == "INVALID_TOKEN")
            {
                UE_LOG(LogTemp, Error, TEXT("Invalid token. Logging out."));
                GlobalAuthToken.Empty();
            }
            else
            {
                UE_LOG(LogTemp, Error, TEXT("API Error [%s]: %s"), *ErrorCode, *ErrorMessage);
            }
        }
    }
}
```

---

## 실전 예제

### 완전한 로그인 플로우 (UMVELoginManager)
이 클래스는 회원가입부터 로그인까지의 상태를 관리합니다.

- **StartSignup**: 이메일을 보내 인증번호를 요청합니다.
- **VerifyEmailCode**: 사용자가 입력한 인증번호를 검증합니다.
- **CompleteSignup**: 검증된 상태에서 아이디와 비번을 설정하여 가입을 완료합니다.

(상세 코드는 본문 참조)

### 음원 재생 플로우
```cpp
void PlayAudio(int32 AudioId, UMediaPlayer* MediaPlayer)
{
    // 1단계: 스트리밍 URL 획득
    FString URL = FString::Printf(TEXT("%s/api/audio/stream/%d"), *ResourceServerURL, AudioId);

    FMVEHttpClient::SendGetRequest(URL, GlobalAuthToken,
        FOnHttpResponse::CreateLambda([MediaPlayer](bool bSuccess, const FString& ResponseBody)
        {
            if (bSuccess)
            {
                // ... JSON 파싱하여 StreamUrl 획득 ...
                FString StreamUrl = JsonResponse->GetStringField("stream_url");
                
                // 2단계: Media Player로 재생
                if (MediaPlayer)
                {
                    MediaPlayer->OpenUrl(StreamUrl);
                    UE_LOG(LogTemp, Log, TEXT("Playing audio from: %s"), *StreamUrl);
                }
            }
        })
    );
}
```

---

## 추가 팁

**GlobalAuthToken 관리**: `GlobalAuthToken`은 게임 인스턴스(GameInstance)나 서브시스템(Subsystem)에 저장하여 게임 전체에서 접근 가능하도록 관리하는 것이 좋습니다.