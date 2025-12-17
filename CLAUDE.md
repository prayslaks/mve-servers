# MVE Servers - Claude 작업 가이드

이 문서는 Claude가 MVE 프로젝트 작업 시 참조하는 가이드입니다.

## 프로젝트 구조

```
mve-servers/
├── mve-login-server/        # 로그인/인증 서버
├── mve-resource-server/     # 리소스 관리 서버
├── unreal/                  # Unreal Engine 연동 파일
│   ├── unreal-response-data-header.example
│   └── unreal-rider-python-validation-tool.example
└── CLAUDE.md               # 이 가이드
```

---

## 🎯 핵심 설계 원칙 (양쪽 서버 공통)

### 1. 단일 소스 원칙 (Single Source of Truth)

**모든 재사용 가능한 데이터 타입은 `schemas/api-schemas.js`에서만 정의합니다.**

#### Component Schema vs Response Schema 구분

| 타입 | 정의 위치 | 용도 | 예시 |
|------|----------|------|------|
| **Component Schema** | `schemas/api-schemas.js` | 재사용 가능한 데이터 타입 | `User`, `AudioFile`, `BaseResponse` |
| **Response Schema** | `routes/*.js` (인라인) | 엔드포인트별 응답 구조 | `/api/auth/login`의 200 응답 |

#### ❌ 절대 금지

```javascript
// schemas/api-schemas.js - 이렇게 하면 안됨!
module.exports = {
  LoginResponse: {  // ← Response 래퍼를 Component Schema로 만들지 말 것!
    type: 'object',
    properties: {
      success: { type: 'boolean' },
      code: { type: 'string' },
      message: { type: 'string' },
      user: { $ref: '#/components/schemas/User' }
    }
  }
};
```

**문제점**: Unreal 검증 스크립트에서 중복 구조체 생성 → API 경로 추적 불가

#### ✅ 올바른 방법

**Component Schema (schemas/api-schemas.js)**: 재사용 가능한 타입만

```javascript
module.exports = {
  User: {  // ← 여러 API에서 재사용되는 데이터 타입
    type: 'object',
    required: ['id', 'email', 'created_at'],
    properties: {
      id: { type: 'integer', example: 1 },
      email: { type: 'string', format: 'email', example: 'test@example.com' },
      created_at: { type: 'string', format: 'date-time' }
    }
  },

  SuccessResponse: {  // ← 공통 응답 베이스
    type: 'object',
    required: ['success', 'code', 'message'],
    properties: {
      success: { type: 'boolean', example: true },
      code: { type: 'string', example: 'SUCCESS' },
      message: { type: 'string', example: 'Operation successful' }
    }
  }
};
```

**Response Schema (routes/auth.js)**: 인라인으로 정의

```javascript
/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: 사용자 로그인
 *     tags:
 *       - Auth
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email, password]
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: 로그인 성공
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [success, code, message, user, token]
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 code:
 *                   type: string
 *                   example: "LOGIN_SUCCESS"
 *                 message:
 *                   type: string
 *                   example: "Login successful"
 *                 user:
 *                   $ref: '#/components/schemas/User'  # ← Component Schema 참조
 *                 token:
 *                   type: string
 *                   example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
 *       400:
 *         description: 잘못된 요청
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [success, code, message]
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: false
 *                 code:
 *                   type: string
 *                   example: "INVALID_EMAIL"
 *                 message:
 *                   type: string
 *                   example: "Invalid email format"
 */
router.post('/login', async (req, res) => {
  // 구현...
});
```

---

### 2. 🚨 엄격한 API 응답 구조 규칙

**모든 API 응답은 반드시 다음 구조를 따라야 합니다:**

```
공통 필드 (required) + 추가 필드 (선택)
```

#### 필수 공통 필드 (3개)

| 필드 | 타입 | 설명 | 예시 |
|------|------|------|------|
| `success` | `boolean` | 요청 성공 여부 | `true`, `false` |
| `code` | `string` (Login) / `integer` (Resource) | 응답 코드 | `"LOGIN_SUCCESS"`, `200` |
| `message` | `string` | 응답 메시지 | `"Login successful"` |

#### Unreal Engine 매크로와의 연동

Unreal C++ 헤더에서는 `MVE_API_RESPONSE_BASE` 매크로로 정의:

```cpp
// C++ 헤더 파일
#define MVE_API_RESPONSE_BASE \
    UPROPERTY(BlueprintReadOnly, Category="MVE|API Response") \
    bool Success = false; \
    UPROPERTY(BlueprintReadOnly, Category="MVE|API Response") \
    FString Code; \
    UPROPERTY(BlueprintReadOnly, Category="MVE|API Response") \
    FString Message;

USTRUCT(BlueprintType)
struct FLoginResponseData
{
    GENERATED_BODY()
    MVE_API_RESPONSE_BASE  // ← 공통 3개 필드 자동 추가

    UPROPERTY(BlueprintReadOnly, Category="MVE|API Response")
    FUser User;  // ← 추가 필드

    UPROPERTY(BlueprintReadOnly, Category="MVE|API Response")
    FString Token;  // ← 추가 필드
};
```

검증 스크립트(`unreal-rider-python-validation-tool.example`)는:
1. 매크로를 발견하면 자동으로 `Success`, `Code`, `Message` 필드 인식
2. API 스펙의 `required` 배열에 있는 필드만 검증
3. 매크로 필드 + UPROPERTY 필드를 모두 체크

---

### 3. Required 필드 명시 규칙

#### ✅ 반드시 지켜야 할 사항

```javascript
// schemas/api-schemas.js
module.exports = {
  User: {
    type: 'object',
    required: ['id', 'email', 'created_at'],  // ← 필수!
    properties: {
      id: { type: 'integer' },
      email: { type: 'string' },
      created_at: { type: 'string' },
      nickname: { type: 'string', nullable: true }  // ← 선택적 필드
    }
  }
};
```

```javascript
// routes/auth.js - Swagger 주석
/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     responses:
 *       200:
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [success, code, message, user, token]  # ← 필수!
 *               properties:
 *                 success: { type: boolean }
 *                 code: { type: string }
 *                 message: { type: string }
 *                 user: { $ref: '#/components/schemas/User' }
 *                 token: { type: string }
 */
```

#### 검증 로직

- `required` 배열 있음 → 해당 필드만 검증
- `required` 배열 없음 → 모든 properties 검증 (후방 호환성)

---

## 📋 API 추가/수정 작업 프로세스

### 단계별 체크리스트

#### 1️⃣ Component Schema 확인

새로운 **재사용 가능한** 데이터 타입이 필요한가?

- **YES** → `schemas/api-schemas.js`에 추가
  - `required` 배열 반드시 명시
  - `nullable` 필드는 명시적으로 표시
  - `example` 값 제공 권장

- **NO** → 기존 스키마 재사용 또는 인라인 정의

#### 2️⃣ routes/*.js에 Swagger 주석 작성

```javascript
/**
 * @swagger
 * /api/your-endpoint:
 *   post:
 *     summary: 엔드포인트 설명
 *     tags: [YourTag]
 *     requestBody:  # ← 요청 바디가 있으면 반드시 정의
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [field1, field2]
 *             properties:
 *               field1: { type: string }
 *               field2: { type: integer }
 *     responses:
 *       200:  # ← 성공 케이스
 *         description: 성공
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [success, code, message, data]  # ← 공통 3개 + 추가 필드
 *               properties:
 *                 success: { type: boolean, example: true }
 *                 code: { type: string, example: "SUCCESS" }
 *                 message: { type: string, example: "Operation successful" }
 *                 data:
 *                   $ref: '#/components/schemas/YourSchema'  # ← Component Schema 참조
 *       400:  # ← 에러 케이스들
 *         description: 에러
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [success, code, message]
 *               properties:
 *                 success: { type: boolean, example: false }
 *                 code: { type: string, example: "ERROR_CODE" }
 *                 message: { type: string, example: "Error description" }
 *                 details: { type: object, nullable: true }  # ← 선택적 상세 정보
 */
```

**필수 사항:**
- 모든 HTTP 상태 코드에 대해 응답 스키마 정의
- 공통 필드 (`success`, `code`, `message`) 반드시 포함
- `required` 배열 명시
- requestBody가 있으면 스키마 정의

#### 3️⃣ API 문서 생성

```bash
# Login Server
cd mve-login-server
npm run docs

# Resource Server
cd mve-resource-server
npm run docs
```

생성 파일:
- `working-scripts/outputs/login-server-api-spec.json`
- `working-scripts/outputs/resource-server-api-spec.json`

#### 4️⃣ Swagger UI 확인

```bash
npm start
# Login Server: http://localhost:3000/api-docs
# Resource Server: http://localhost:3001/api-docs
```

#### 5️⃣ Unreal Engine 검증

```bash
# 루트 디렉토리에서 실행
python unreal/unreal-rider-python-validation-tool.example
```

**검증 항목:**
- API 스펙의 모든 엔드포인트가 C++ 구조체로 정의되어 있는가?
- Component Schema가 모두 구조체로 존재하는가?
- required 필드가 모두 UPROPERTY로 정의되어 있는가?
- 매크로 필드 인식이 정상적으로 동작하는가?

---

## 📚 현재 정의된 Component Schema

### mve-login-server (3개)

| 스키마 | 설명 | 필수 필드 |
|--------|------|-----------|
| `User` | 사용자 정보 | `id`, `email`, `created_at` |
| `SuccessResponse` | 기본 성공 응답 | `success`, `code`, `message` |
| `ErrorResponse` | 에러 응답 | `success`, `code`, `message` |

### mve-resource-server (12개)

#### 공통 응답
- `BaseResponse` - 기본 API 응답 포맷
- `ErrorResponse` - 에러 응답 포맷

#### 기하학적 데이터
- `Vector3D` - 3D 좌표 (x, y, z)
- `Rotator` - 3D 회전 (pitch, yaw, roll)

#### Audio
- `AudioFile` - 음원 파일 정보

#### Model
- `ModelInfo` - 3D 모델 파일 정보
- `AIJobStatus` - AI 생성 작업 상태
- `DeletedModelInfo` - 삭제된 모델 정보

#### Accessory
- `Accessory` - 아바타 액세서리
- `AccessoryPreset` - 액세서리 프리셋

#### Concert
- `ConcertSong` - 콘서트 노래 정보
- `ListenServer` - 리슨 서버 정보
- `ConcertInfo` - 콘서트 전체 정보

---

## 🔧 자동화 도구

### 1. API 문서 생성

```bash
# Login Server
npm run docs  # working-scripts/generate-api-specs.js 실행

# Resource Server
npm run docs  # working-scripts/generate-api-specs.js 실행
```

**동작 방식:**
1. `schemas/api-schemas.js` 로드 (Component Schemas)
2. `routes/*.js`의 Swagger 주석 파싱 (Response Schemas)
3. OpenAPI 3.0 스펙 생성
4. JSON 파일로 출력

### 2. Unreal Engine 검증 스크립트

**파일**: `unreal/unreal-rider-python-validation-tool.example`

**기능:**
- C++ 헤더 파일에서 USTRUCT 파싱
- 매크로 자동 확장 (`MVE_API_RESPONSE_BASE` → 3개 필드)
- API 스펙과 구조체 필드 비교
- 누락/불일치 필드 리포트

**매크로 정의:**
```python
MACRO_DEFINITIONS = {
    "MVE_API_RESPONSE_BASE": [
        ("Success", "bool"),
        ("Code", "FString"),
        ("Message", "FString"),
    ]
}
```

새 매크로 추가 시 이 딕셔너리에 정의하면 자동 인식됩니다.

---

## ⚠️ 주의사항 및 금지 사항

### ❌ 절대 하지 말 것

1. **Response 래퍼를 Component Schema로 만들지 말 것**
   ```javascript
   // schemas/api-schemas.js - 금지!
   LoginResponse: { ... }
   SignupResponse: { ... }
   ```

2. **routes/*.js에서 Component Schema 정의하지 말 것**
   ```javascript
   // routes/auth.js - 금지!
   /**
    * @swagger
    * components:
    *   schemas:
    *     User: { ... }  // ← schemas/api-schemas.js에 정의해야 함
    */
   ```

3. **공통 필드 누락 금지**
   - 모든 응답에 `success`, `code`, `message` 필수

4. **required 배열 생략 금지**
   - Component Schema와 Response Schema 모두 명시

### ✅ 반드시 지킬 것

1. **단일 소스 원칙**
   - 재사용 타입은 `schemas/api-schemas.js`에만

2. **API 응답 구조 통일**
   - 공통 3개 필드 + 추가 필드 구조

3. **문서 재생성**
   - 스키마 수정 후 `npm run docs` 실행

4. **검증 스크립트 실행**
   - Unreal Engine 연동 전 Python 스크립트로 검증

5. **Git 커밋에 포함**
   - `api-spec.json` 파일을 커밋에 포함

---

## 🎯 설계 배경 및 이유

### 왜 Response 래퍼를 Component Schema로 만들지 않는가?

**문제 상황:**
```javascript
// 잘못된 설계 - Component Schema에 Response 래퍼 정의
module.exports = {
  LoginResponse: {
    type: 'object',
    properties: { success: {...}, code: {...}, user: {...} }
  }
};

// routes/auth.js에서 참조
responses: {
  200: {
    content: {
      'application/json': {
        schema: { $ref: '#/components/schemas/LoginResponse' }
      }
    }
  }
}
```

**발생하는 문제:**
1. Unreal 검증 스크립트가 `LoginResponse`를 Component Schema로 인식
2. `@MveApiComponentSchema LoginResponse` 어노테이션으로 매칭 시도
3. 실제로는 `@MveApiResponse POST /api/auth/login`으로 정의해야 함
4. **중복 구조체 에러** 또는 **API 경로 추적 불가** 발생

**올바른 설계:**
```javascript
// schemas/api-schemas.js - Component Schema는 재사용 타입만
module.exports = {
  User: { ... }  // ← 여러 API에서 사용되는 타입
};

// routes/auth.js - Response는 인라인으로
responses: {
  200: {
    content: {
      'application/json': {
        schema: {
          type: 'object',
          properties: {
            success: {...},
            code: {...},
            user: { $ref: '#/components/schemas/User' }  // ← Component Schema 참조
          }
        }
      }
    }
  }
}
```

**결과:**
- Unreal 구조체가 API 경로와 명확히 매칭됨
- 중복 정의 제거
- 양쪽 서버 설계 통일

---

## 📝 작업 기록

**최근 주요 변경 (2025-12-18):**

1. **설계 통일 완료**
   - Login Server와 Resource Server 모두 동일한 패턴 적용
   - Component Schema vs Response Schema 명확히 구분

2. **Unreal 검증 스크립트 개선**
   - 매크로 자동 확장 기능 추가
   - Required 필드만 검증하도록 개선
   - Component Schema 자동 스킵 로직 추가

3. **중복 스키마 제거**
   - Login Server에서 7개 Response 래퍼 스키마 삭제
   - routes/auth.js를 인라인 스키마로 변경

4. **Required 필드 일괄 추가**
   - 모든 Component Schema에 `required` 배열 명시
   - 양쪽 서버 api-schemas.js 업데이트 완료

---

**마지막 업데이트**: 2025-12-18 (설계 통일 및 Unreal 연동 개선 완료)
