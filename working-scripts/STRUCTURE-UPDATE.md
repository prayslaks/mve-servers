# 스크립트 구조 업데이트

## 📋 변경 사항 요약

스크립트 출력 경로를 일관성 있게 `working-scripts/outputs` 폴더로 통일했습니다.

---

## 🔄 변경된 폴더 구조

### Before (이전)
```
mve-servers/
├── mve-login-server/
│   ├── scripts/                    # ❌ 스크립트 위치가 불명확
│   │   ├── analyze-response-codes.js
│   │   └── generate-api-docs.js
│   └── docs/                       # ❌ 출력 위치
│       ├── response-code-statistics.json
│       └── api-spec.json
│
├── mve-resource-server/
│   ├── scripts/                    # ❌ 스크립트 위치가 불명확
│   │   ├── analyze-response-codes.js
│   │   └── generate-api-docs.js
│   └── docs/                       # ❌ 출력 위치
│       ├── response-code-statistics.json
│       └── api-spec.json
│
└── working-scripts/
    ├── generate-and-copy-docs.js
    └── analyze-swagger-changes.js
```

### After (변경 후)
```
mve-servers/
├── mve-login-server/
│   └── working-scripts/            # ✅ 명확한 위치
│       ├── analyze-response-codes.js
│       ├── generate-api-docs.js
│       └── outputs/                # ✅ 통일된 출력 위치
│           ├── response-code-statistics.json
│           └── api-spec.json
│
├── mve-resource-server/
│   ├── scripts/                    # (기존 유지)
│   │   ├── analyze-response-codes.js
│   │   └── generate-api-docs.js
│   └── working-scripts/
│       └── outputs/                # ✅ 통일된 출력 위치
│           ├── response-code-statistics.json
│           └── api-spec.json
│
└── working-scripts/
    ├── generate-and-copy-docs.js
    ├── analyze-swagger-changes.js
    └── output/                     # ✅ 힌트 파일 출력
        └── unreal-api-change-hints.json
```

---

## 📝 수정된 파일 목록

### 1. Login Server 스크립트
- **파일**: `mve-login-server/working-scripts/analyze-response-codes.js`
  - **변경**: 출력 경로를 `working-scripts/outputs/` 폴더로 수정
  - **코드**:
    ```javascript
    const outputDir = path.join(__dirname, 'outputs');
    const outputFile = path.join(outputDir, 'response-code-statistics.json');
    ```

- **파일**: `mve-login-server/working-scripts/generate-api-docs.js`
  - **변경**: 출력 경로를 `working-scripts/outputs/` 폴더로 수정
  - **코드**:
    ```javascript
    const outputDir = path.join(__dirname, 'outputs');
    const outputPath = path.join(outputDir, 'api-spec.json');
    ```

### 2. Resource Server 스크립트
- **파일**: `mve-resource-server/scripts/analyze-response-codes.js`
  - **변경**: 출력 경로를 `../working-scripts/outputs/` 폴더로 수정
  - **코드**:
    ```javascript
    const outputDir = path.join(__dirname, '..', 'working-scripts', 'outputs');
    const outputFile = path.join(outputDir, 'response-code-statistics.json');
    ```

- **파일**: `mve-resource-server/scripts/generate-api-docs.js`
  - **변경**: 출력 경로를 `../working-scripts/outputs/` 폴더로 수정
  - **코드**:
    ```javascript
    const outputDir = path.join(__dirname, '..', 'working-scripts', 'outputs');
    const outputPath = path.join(outputDir, 'api-spec.json');
    ```

### 3. 통합 스크립트
- **파일**: `working-scripts/generate-and-copy-docs.js`
  - **변경**: 스크립트 경로 및 출력 파일 경로 수정
  - **Login Server**:
    ```javascript
    analyzeScript: path.join(rootDir, 'mve-login-server', 'working-scripts', 'analyze-response-codes.js'),
    generateScript: path.join(rootDir, 'mve-login-server', 'working-scripts', 'generate-api-docs.js'),
    outputFiles: [
      { src: 'working-scripts/outputs/response-code-statistics.json', ... },
      { src: 'working-scripts/outputs/api-spec.json', ... }
    ]
    ```
  - **Resource Server**:
    ```javascript
    analyzeScript: path.join(rootDir, 'mve-resource-server', 'scripts', 'analyze-response-codes.js'),
    generateScript: path.join(rootDir, 'mve-resource-server', 'scripts', 'generate-api-docs.js'),
    outputFiles: [
      { src: 'working-scripts/outputs/response-code-statistics.json', ... },
      { src: 'working-scripts/outputs/api-spec.json', ... }
    ]
    ```

- **파일**: `working-scripts/analyze-swagger-changes.js`
  - **변경**: 최신 spec 경로 수정
  - **코드**:
    ```javascript
    loginServerSpecPath: path.join(__dirname, '..', 'mve-login-server', 'working-scripts', 'outputs', 'api-spec.json'),
    resourceServerSpecPath: path.join(__dirname, '..', 'mve-resource-server', 'working-scripts', 'outputs', 'api-spec.json'),
    ```

---

## ✅ 테스트 결과

### 개별 스크립트 테스트
```bash
# Login Server
cd mve-login-server/working-scripts
node analyze-response-codes.js  # ✅ outputs/response-code-statistics.json 생성
node generate-api-docs.js        # ✅ outputs/api-spec.json 생성

# Resource Server
cd mve-resource-server/scripts
node analyze-response-codes.js  # ✅ ../working-scripts/outputs/response-code-statistics.json 생성
node generate-api-docs.js        # ✅ ../working-scripts/outputs/api-spec.json 생성
```

### 통합 워크플로우 테스트
```bash
cd working-scripts
npm run sync                     # ✅ 모든 단계 성공

# 결과:
# ✅ Login Server: working-scripts/outputs/*.json 생성
# ✅ Resource Server: working-scripts/outputs/*.json 생성
# ✅ 언리얼 프로젝트: ApiSpecs/*.json 복사 완료
# ✅ 힌트 파일: working-scripts/output/unreal-api-change-hints.json 생성
```

---

## 🎯 장점

1. **일관성**: 모든 서버가 `working-scripts/outputs/` 폴더를 사용
2. **명확성**: 스크립트와 출력이 같은 `working-scripts` 폴더 내에 위치
3. **유지보수성**: 경로 구조가 통일되어 관리 용이
4. **확장성**: 새로운 서버 추가 시 같은 패턴 적용 가능

---

## 📁 최종 출력 파일 위치

### 각 서버별 출력
- Login Server: `mve-login-server/working-scripts/outputs/`
  - `response-code-statistics.json`
  - `api-spec.json`

- Resource Server: `mve-resource-server/working-scripts/outputs/`
  - `response-code-statistics.json`
  - `api-spec.json`

### 통합 출력
- 언리얼 프로젝트: `c:\Users\user\Documents\Unreal Projects\MVE\ApiSpecs\`
  - `login-server-api-spec.json`
  - `login-server-response-codes.json`
  - `resource-server-api-spec.json`
  - `resource-server-response-codes.json`

- 변경사항 힌트: `working-scripts/output/`
  - `unreal-api-change-hints.json`

---

## 🚀 사용 방법 (변경 없음)

```bash
# 전체 프로세스 실행
cd working-scripts
npm run sync

# 개별 작업
npm run copy-docs   # 문서 생성 및 복사만
npm run analyze     # 변경사항 분석만
```

---

**업데이트 날짜**: 2025-12-11
**상태**: ✅ 완료 및 테스트 검증됨
