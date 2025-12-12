# MVE Servers - Claude 작업 가이드

이 문서는 Claude가 MVE 프로젝트 작업 시 참조하는 가이드입니다.

## 프로젝트 구조

```
mve-servers/
├── mve-login-server/        # 로그인/인증 서버
├── mve-resource-server/     # 리소스 관리 서버
└── CLAUDE.md               # 이 파일
```

---

## mve-resource-server: API 문서화 규칙

### 중요: 단일 소스 원칙 (Single Source of Truth)

**모든 API 스키마는 `schemas/api-schemas.js` 파일에서만 정의합니다.**

**절대 금지**: `routes/*.js` 파일에 스키마 정의
**올바른 방법**: `schemas/api-schemas.js`에 정의 → routes에서 참조

### API 추가/수정 작업 프로세스

#### 1. 스키마 정의 확인

새로운 데이터 타입이 필요한가?

- **YES** → `mve-resource-server/schemas/api-schemas.js`에 스키마 추가
- **NO** → 기존 스키마 사용

#### 2. routes/*.js에 Swagger 주석 작성

- 엔드포인트 정보(경로, HTTP 메서드, 설명 등)만 작성
- 스키마는 `$ref: '#/components/schemas/SchemaName'`로 참조
- **절대 스키마를 인라인으로 정의하지 않음**

#### 3. API 문서 생성

```bash
cd mve-resource-server
npm run docs
```

생성된 파일: `mve-resource-server/working-scripts/outputs/api-spec.json`

---

### 예시

#### 잘못된 방법 (Two Source 문제 발생)

```javascript
// routes/audio.js - 이렇게 하면 안됨!
/**
 * @swagger
 * components:
 *   schemas:
 *     AudioFile:  # ← routes 파일에서 스키마 정의하면 안됨!
 *       type: object
 *       properties:
 *         id:
 *           type: integer
 *         title:
 *           type: string
 */
```

**문제점**: generate-api-specs.js와 중복 정의 → 동기화 불가능

---

#### 올바른 방법 (단일 소스)

**Step 1: schemas/api-schemas.js에 스키마 정의**

```javascript
// mve-resource-server/schemas/api-schemas.js
module.exports = {
  AudioFile: {
    type: 'object',
    description: '음원 파일 정보',
    properties: {
      id: {
        type: 'integer',
        description: '음원 ID',
        example: 1
      },
      title: {
        type: 'string',
        description: '음원 제목',
        example: 'Sample Track'
      },
      artist: {
        type: 'string',
        nullable: true,
        description: '아티스트',
        example: 'Artist Name'
      }
    }
  },
  // ... 다른 스키마들
};
```

**Step 2: routes/audio.js에서 참조만**

```javascript
// routes/audio.js
/**
 * @swagger
 * /api/audio/list:
 *   get:
 *     summary: 음원 목록 조회
 *     tags:
 *       - Audio
 *     responses:
 *       200:
 *         description: 음원 목록 조회 성공
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 audio_files:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/AudioFile'  # ← 참조만!
 */
router.get('/list', verifyToken, async (req, res) => {
  // 구현...
});
```

---

### 현재 정의된 스키마 목록 (10개)

#### 기하학적 데이터 타입
- `Vector3D` - 3D 좌표 (x, y, z)
- `Rotator` - 3D 회전 (pitch, yaw, roll)

#### Audio 관련
- `AudioFile` - 음원 파일 정보

#### Model 관련
- `ModelInfo` - 3D 모델 파일 정보
- `AIJobStatus` - AI 생성 작업 상태

#### Accessory 관련
- `Accessory` - 아바타 액세서리 (Vector3D, Rotator 참조)
- `AccessoryPreset` - 액세서리 프리셋

#### Concert 관련
- `ConcertSong` - 콘서트 노래 정보
- `ListenServer` - 리슨 서버 정보
- `ConcertInfo` - 콘서트 전체 정보

---

### 스키마 참조 관계

```
AccessoryPreset
  └─→ Accessory (배열)
       ├─→ Vector3D (relativeLocation)
       └─→ Rotator (relativeRotation)

ConcertInfo
  ├─→ ConcertSong (배열)
  ├─→ Accessory (배열)
  └─→ ListenServer
```

---

### 새로운 API 추가 시 체크리스트

- [ ] 새로운 스키마가 필요한가?
  - YES → `schemas/api-schemas.js`에 추가
  - NO → 기존 스키마 재사용

- [ ] `routes/*.js`에 Swagger 주석 작성
  - 엔드포인트 경로, HTTP 메서드
  - summary, description, tags
  - requestBody (필요 시)
  - responses (성공/에러 케이스)
  - 스키마는 `$ref`로만 참조

- [ ] API 문서 생성 및 확인
  ```bash
  npm run docs
  ```

- [ ] Swagger UI에서 확인
  ```bash
  npm start
  # http://localhost:3001/api-docs 접속
  ```

---

### 주의사항

1. **스키마 수정 시**: `schemas/api-schemas.js` 파일만 수정
2. **문서 재생성**: 스키마 변경 후 반드시 `npm run docs` 실행
3. **네이밍 규칙**: PascalCase 사용 (예: `AudioFile`, `ConcertInfo`)
4. **필수 필드**: `required` 배열에 명시
5. **nullable**: null 가능한 필드는 `nullable: true` 추가
6. **예시 값**: `example` 필드로 샘플 데이터 제공

---

## API 문서 동기화 자동화

현재 설정:
- 스키마: `schemas/api-schemas.js` (단일 소스)
- 생성 스크립트: `working-scripts/generate-api-specs.js`
- 출력: `working-scripts/outputs/api-spec.json`

변경 사항이 있을 때:
1. 코드 수정 (routes 또는 schemas)
2. `npm run docs` 실행
3. Git commit에 api-spec.json 포함

---

## mve-login-server 가이드

(필요 시 추가)

---

**마지막 업데이트**: 2024년 (스키마 단일 소스 통합 완료)
