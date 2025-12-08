# API 스펙 문제점 및 개선 사항 보고서

생성일: 2025-12-08
대상: mve-resource-server, mve-login-server

---

## 요약

Swagger API 스펙과 실제 구현 코드 간의 불일치 및 누락 사항을 전체적으로 점검한 결과, 다음과 같은 주요 문제들이 발견되었습니다:

1. **응답 스키마가 대부분 불완전하거나 누락됨** (가장 심각)
2. **경로 불일치** (accessory-presets 경로)
3. **오류 응답 정의 부족**
4. **개발 전용 API 미문서화**
5. **필드명 불일치**

---

## 1. mve-resource-server API 스펙 문제점

### 🔴 심각도: 높음

#### 1.1. Accessory Presets API 경로 불일치

**문제:**
- API 스펙: `/api/presets/*`
- 실제 라우트: `/api/accessory-presets/*`

**영향:**
- 클라이언트가 잘못된 경로로 요청하게 됨
- 404 에러 발생

**해결 방법:**
- API 스펙의 모든 `/api/presets/*` 경로를 `/api/accessory-presets/*`로 수정 필요
- 파일: `mve-resource-server/docs/api-spec.json`
  - Line 191: `/api/presets/save` → `/api/accessory-presets/save`
  - Line 249: `/api/presets/list` → `/api/accessory-presets/list`
  - Line 306: `/api/presets/{id}` → `/api/accessory-presets/{id}`

**수정 완료:** ✅ 경로 수정 완료

---

#### 1.2. 응답 스키마 대부분 누락

**문제:**
대부분의 엔드포인트에서 `responses`에 상세한 JSON 스키마가 없고 단순 description만 존재합니다.

**예시 - 현재 상태:**
```json
{
  "responses": {
    "200": {
      "description": "콘서트 생성 성공"
    },
    "400": {
      "description": "잘못된 요청"
    }
  }
}
```

**예시 - 올바른 상태:**
```json
{
  "responses": {
    "200": {
      "description": "콘서트 생성 성공",
      "content": {
        "application/json": {
          "schema": {
            "type": "object",
            "properties": {
              "success": {
                "type": "boolean",
                "example": true
              },
              "roomId": {
                "type": "string",
                "example": "concert_1234567890_abcdef123"
              },
              "expiresIn": {
                "type": "integer",
                "description": "세션 만료 시간(초)",
                "example": 3600
              }
            }
          }
        }
      }
    },
    "400": {
      "description": "잘못된 요청",
      "content": {
        "application/json": {
          "schema": {
            "$ref": "#/components/schemas/ErrorResponse"
          },
          "examples": {
            "missingFields": {
              "value": {
                "success": false,
                "error": "MISSING_FIELDS",
                "message": "concertName is required"
              }
            }
          }
        }
      }
    }
  }
}
```

**영향을 받는 엔드포인트 목록:**
1. `POST /api/accessory-presets/save` - Line 236-246
2. `PUT /api/accessory-presets/{id}` - Line 410-429
3. `DELETE /api/accessory-presets/{id}` - Line 453-484
4. `POST /api/concert/create` - Line 932-942
5. `POST /api/concert/{roomId}/join` - Line 1033-1046
6. `POST /api/concert/{roomId}/leave` - Line 1091-1105
7. `POST /api/concert/{roomId}/songs/add` - Line 1211-1224
8. `DELETE /api/concert/{roomId}/songs/{songNum}` - Line 1259-1273
9. `POST /api/concert/{roomId}/songs/change` - Line 1317-1330
10. `POST /api/concert/{roomId}/accessories/add` - Line 1462-1476
11. `DELETE /api/concert/{roomId}/accessories/{index}` - Line 1510-1524
12. `PUT /api/concert/{roomId}/accessories` - Line 1584-1598
13. `POST /api/concert/{roomId}/listen-server` - Line 1657-1671
14. `POST /api/concert/{roomId}/toggle-open` - Line 1715-1729
15. `PUT /api/models/{id}` - Line 2120-2137
16. `POST /api/models/{id}/thumbnail` - Line 2326-2340

---

#### 1.3. 개발 전용 API 미문서화

**문제:**
실제 구현되어 있는 개발 전용 API들이 Swagger 스펙에 없습니다.

**누락된 API:**

1. **POST /api/models/dev/upload-from-ai**
   - 설명: 개발 환경에서 사용자 인증 없이 AI 모델 업로드 테스트
   - 환경: 개발 환경(NODE_ENV !== 'production')만 사용 가능
   - 실제 응답:
     ```json
     {
       "success": true,
       "message": "Model uploaded successfully (DEV MODE)",
       "model": { ... }
     }
     ```

2. **POST /api/concert/dev/expire-all**
   - 설명: 모든 콘서트 세션 일괄 만료 (개발 환경 전용)
   - 환경: 개발 환경만 사용 가능
   - 실제 응답:
     ```json
     {
       "success": true,
       "message": "All concert sessions have been expired",
       "expiredCount": 5,
       "expiredRooms": ["concert_xxx", "concert_yyy"]
     }
     ```
   - **참고:** 이 API는 현재 api-spec.json Line 1731-1780에 이미 문서화되어 있습니다 ✅

**수정 필요:**
- `/api/models/dev/upload-from-ai` 엔드포인트 추가 필요
- Tag: "Models (Development)" 또는 "AI Generation"

---

#### 1.4. 오류 응답 공통 스키마 누락

**문제:**
오류 응답에 대한 공통 스키마가 `components/schemas`에 정의되지 않았습니다.

**해결 방법:**
`components/schemas`에 다음과 같은 공통 스키마 추가 필요:

```json
{
  "components": {
    "schemas": {
      "ErrorResponse": {
        "type": "object",
        "required": ["success", "error", "message"],
        "properties": {
          "success": {
            "type": "boolean",
            "example": false
          },
          "error": {
            "type": "string",
            "description": "오류 코드",
            "example": "DATABASE_ERROR"
          },
          "message": {
            "type": "string",
            "description": "사람이 읽을 수 있는 오류 메시지",
            "example": "Database error"
          },
          "details": {
            "type": "object",
            "description": "추가 오류 상세 정보 (선택)",
            "additionalProperties": true
          },
          "code": {
            "type": "string",
            "description": "데이터베이스 오류 코드 등 (선택)",
            "example": "23505"
          }
        }
      },
      "SuccessResponse": {
        "type": "object",
        "required": ["success"],
        "properties": {
          "success": {
            "type": "boolean",
            "example": true
          },
          "message": {
            "type": "string",
            "description": "성공 메시지"
          }
        }
      }
    }
  }
}
```

---

#### 1.5. 실제 응답 필드와 API 스펙 불일치

**문제:**
일부 엔드포인트에서 실제 응답 필드명과 API 스펙의 필드명이 다릅니다.

**예시 1: Accessory Presets**
- API 스펙: `preset_name`, `user_id`, `file_path`, `is_public`, `created_at`, `updated_at`
- 실제 응답: `presetName`, `userId`, `isPublic`, `createdAt`, `updatedAt` (camelCase)

**예시 2: Concert Sessions**
- 실제 응답에는 `createdAt`이 Unix timestamp(밀리초)로 반환되지만 스펙에 명시되지 않음

**해결 방법:**
- 실제 라우트 코드를 다시 확인하여 정확한 필드명 사용
- 통일된 네이밍 컨벤션 사용 (snake_case vs camelCase)

---

#### 1.6. 인증 오류 응답 누락

**문제:**
JWT 인증이 필요한 모든 엔드포인트에서 다음 오류 응답들이 공통적으로 발생하지만 문서화되지 않았습니다:

**미들웨어에서 발생하는 공통 인증 오류:**

1. **403 Forbidden - Authorization 헤더 오류**
   ```json
   {
     "success": false,
     "error": "NO_AUTH_HEADER",
     "message": "No authorization header provided"
   }
   ```
   ```json
   {
     "success": false,
     "error": "INVALID_AUTH_FORMAT",
     "message": "Authorization header must start with \"Bearer \""
   }
   ```
   ```json
   {
     "success": false,
     "error": "NO_TOKEN",
     "message": "No token provided"
   }
   ```

2. **401 Unauthorized - 토큰 검증 실패**
   ```json
   {
     "success": false,
     "error": "TOKEN_EXPIRED",
     "message": "Token has expired",
     "expiredAt": "2024-01-01T02:00:00.000Z"
   }
   ```
   ```json
   {
     "success": false,
     "error": "INVALID_TOKEN",
     "message": "Invalid token"
   }
   ```
   ```json
   {
     "success": false,
     "error": "TOKEN_VERIFICATION_FAILED",
     "message": "Token verification failed"
   }
   ```

**해결 방법:**
- 모든 인증 필요 엔드포인트의 `responses`에 401, 403 응답 추가
- 또는 `components/responses`에 공통 인증 오류 정의 후 참조

```json
{
  "components": {
    "responses": {
      "UnauthorizedError": {
        "description": "인증 실패",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ErrorResponse"
            },
            "examples": {
              "tokenExpired": {
                "value": {
                  "success": false,
                  "error": "TOKEN_EXPIRED",
                  "message": "Token has expired",
                  "expiredAt": "2024-01-01T02:00:00.000Z"
                }
              }
            }
          }
        }
      },
      "ForbiddenError": {
        "description": "권한 없음",
        "content": {
          "application/json": {
            "schema": {
              "$ref": "#/components/schemas/ErrorResponse"
            },
            "examples": {
              "noAuthHeader": {
                "value": {
                  "success": false,
                  "error": "NO_AUTH_HEADER",
                  "message": "No authorization header provided"
                }
              }
            }
          }
        }
      }
    }
  }
}
```

---

## 2. mve-login-server API 스펙 문제점

### 🔴 심각도: 중간

#### 2.1. 오류 응답 스키마 불완전

**문제:**
오류 응답에 상세 정보가 포함되지만 스키마에 정의되지 않았습니다.

**예시 - 실제 응답:**
```json
{
  "success": false,
  "error": "MISSING_FIELDS",
  "message": "All fields required",
  "details": {
    "password": "OK",
    "email": "OK",
    "code": "Verification code is required"
  }
}
```

**문제:**
- `details` 필드가 스키마에 없음
- `retryAfter` 필드(429 응답)가 문서화되지 않음
- `attemptsRemaining` 필드(401 응답)가 문서화되지 않음

**영향을 받는 엔드포인트:**
1. `POST /api/auth/send-verification` - `retryAfter` 필드 누락
2. `POST /api/auth/verify-code` - `attemptsRemaining` 필드 누락
3. `POST /api/auth/signup` - `details` 필드 누락
4. `POST /api/auth/login` - `details` 필드 누락

---

#### 2.2. 성공 응답 스키마 상세도 부족

**문제:**
일부 성공 응답의 스키마가 단순하게 정의되어 있습니다.

**예시:**
- `POST /api/auth/check-email`의 응답 스키마는 정의되어 있지만, 실제 응답에는 `exists` 필드와 `error` 필드가 포함됨
- 실제 응답:
  ```json
  {
    "success": true,
    "exists": false,
    "error": null,
    "message": "Email is available"
  }
  ```

**해결 방법:**
- 모든 실제 응답 필드를 스키마에 포함

---

## 3. 우선순위별 수정 작업

### 🔴 우선순위 1 (즉시 수정 필요)

1. ✅ **Accessory Presets 경로 수정** (완료)
   - `/api/presets/*` → `/api/accessory-presets/*`

2. **공통 오류 스키마 추가**
   - `ErrorResponse` 스키마 정의
   - `SuccessResponse` 스키마 정의
   - 파일: 양쪽 서버의 `api-spec.json`

3. **인증 오류 응답 추가**
   - 모든 JWT 필요 엔드포인트에 401/403 응답 추가

### 🟡 우선순위 2 (중요)

1. **주요 엔드포인트 응답 스키마 작성**
   - Concert API (생성, 목록 등)
   - Models API (업로드, 생성 등)
   - Audio API (업로드, 스트리밍 등)

2. **개발 전용 API 문서화**
   - `/api/models/dev/upload-from-ai` 추가

### 🟢 우선순위 3 (개선 사항)

1. **모든 엔드포인트 응답 스키마 완성**
   - 누락된 모든 응답 스키마 작성
   - 예시(examples) 추가

2. **필드명 통일**
   - camelCase vs snake_case 결정
   - 전체 코드베이스에 일관되게 적용

---

## 4. 권장 사항

### 4.1. API 스펙 자동 생성 도구 사용

현재는 수동으로 `api-spec.json`을 관리하고 있어 코드와 문서 간 불일치가 발생합니다.

**권장 도구:**
- `swagger-jsdoc`: JSDoc 주석으로 Swagger 자동 생성
- `tsoa`: TypeScript 데코레이터로 자동 생성 (TypeScript 전환 시)

**예시 (swagger-jsdoc):**
```javascript
/**
 * @swagger
 * /api/concert/create:
 *   post:
 *     summary: 콘서트 생성
 *     tags: [Concert]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - concertName
 *             properties:
 *               concertName:
 *                 type: string
 *     responses:
 *       200:
 *         description: 콘서트 생성 성공
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 roomId:
 *                   type: string
 */
router.post('/create', authMiddleware, async (req, res) => {
  // ...
});
```

### 4.2. 응답 타입 정의 파일 작성

JavaScript로 작성되어 있지만, JSDoc을 사용하여 타입을 정의할 수 있습니다.

**예시:**
```javascript
/**
 * @typedef {Object} ConcertCreateResponse
 * @property {boolean} success - 성공 여부
 * @property {string} roomId - 콘서트 방 ID
 * @property {number} expiresIn - 만료 시간(초)
 */

/**
 * @typedef {Object} ErrorResponse
 * @property {boolean} success - 항상 false
 * @property {string} error - 오류 코드
 * @property {string} message - 오류 메시지
 * @property {Object} [details] - 추가 상세 정보
 */
```

### 4.3. 통합 테스트 추가

API 스펙과 실제 응답이 일치하는지 자동으로 검증하는 테스트 추가:

```bash
npm install --save-dev jest supertest swagger-parser
```

```javascript
// tests/api-spec.test.js
const swaggerParser = require('swagger-parser');
const request = require('supertest');
const app = require('../server');

describe('API Spec Validation', () => {
  let apiSpec;

  beforeAll(async () => {
    apiSpec = await swaggerParser.validate('./docs/api-spec.json');
  });

  test('POST /api/concert/create matches spec', async () => {
    const response = await request(app)
      .post('/api/concert/create')
      .set('Authorization', 'Bearer ' + testToken)
      .send({ concertName: 'Test Concert' });

    const specResponse = apiSpec.paths['/api/concert/create'].post.responses['200'];
    // Validate response structure matches spec
  });
});
```

---

## 5. 결론

현재 API 스펙 문서는 기본 구조는 잘 갖추어져 있지만, **실제 응답 스키마가 대부분 누락**되어 있어 개발자가 API를 사용하기 어렵습니다.

**즉시 해야 할 작업:**
1. ✅ Accessory Presets 경로 수정 (완료)
2. 공통 오류/성공 응답 스키마 정의
3. 주요 엔드포인트의 응답 스키마 작성

**장기적 개선 사항:**
1. API 스펙 자동 생성 도구 도입
2. 타입 정의 파일 작성
3. 통합 테스트로 스펙 일치 검증

이 보고서를 기반으로 우선순위에 따라 수정 작업을 진행하시기 바랍니다.
