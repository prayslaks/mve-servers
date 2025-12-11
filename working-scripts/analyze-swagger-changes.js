#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Swagger Spec 변경사항 분석 및 언리얼 코드 힌트 생성 스크립트
 *
 * 목적:
 * - 기존 Swagger Spec과 새 Swagger Spec을 비교
 * - 변경된 API 엔드포인트 및 스키마 감지
 * - 언리얼 엔진 C++ 코드에 필요한 변경사항 힌트 생성
 * - AI 코드 에이전트가 참고할 수 있는 구조화된 JSON 출력
 */

// ============================================================================
// 설정
// ============================================================================

const CONFIG = {
  // 언리얼 프로젝트 ApiSpecs 폴더 (기존 spec 저장 위치)
  unrealApiSpecsDir: path.join('c:', 'Users', 'user', 'Documents', 'Unreal Projects', 'MVE', 'ApiSpecs'),

  // 서버 프로젝트의 최신 spec 위치
  loginServerSpecPath: path.join(__dirname, '..', 'mve-login-server', 'working-scripts', 'outputs', 'api-spec.json'),
  resourceServerSpecPath: path.join(__dirname, '..', 'mve-resource-server', 'working-scripts', 'outputs', 'api-spec.json'),

  // 출력 파일 경로
  outputDir: path.join(__dirname, 'outputs'),
  hintsFileName: 'unreal-api-change-hints.json'
};

// ============================================================================
// 유틸리티 함수
// ============================================================================

/**
 * JSON 파일 읽기
 */
function readJsonFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(content);
  } catch (error) {
    console.error(`  ❌ 파일 읽기 실패: ${filePath}`);
    console.error(`     ${error.message}`);
    return null;
  }
}

/**
 * JSON 파일 쓰기
 */
function writeJsonFile(filePath, data) {
  try {
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf-8');
    return true;
  } catch (error) {
    console.error(`  ❌ 파일 쓰기 실패: ${filePath}`);
    console.error(`     ${error.message}`);
    return false;
  }
}

/**
 * HTTP 메서드와 경로로 엔드포인트 키 생성
 */
function getEndpointKey(path, method) {
  return `${method.toUpperCase()} ${path}`;
}

/**
 * OpenAPI 스키마에서 프로퍼티 추출
 */
function extractProperties(schema) {
  if (!schema) return {};

  // $ref 참조 처리 (간단한 케이스만)
  if (schema.$ref) {
    return { _ref: schema.$ref };
  }

  // 직접 properties가 있는 경우
  if (schema.properties) {
    return schema.properties;
  }

  // content > application/json > schema 구조
  if (schema.content && schema.content['application/json']) {
    return extractProperties(schema.content['application/json'].schema);
  }

  return {};
}

/**
 * Response 스키마 추출 (200 응답 기준)
 */
function extractResponseSchema(responses) {
  if (!responses) return {};

  // 200, 201, 202 등 성공 응답 찾기
  const successResponse = responses['200'] || responses['201'] || responses['202'];
  if (!successResponse) return {};

  if (successResponse.content && successResponse.content['application/json']) {
    return successResponse.content['application/json'].schema;
  }

  return {};
}

/**
 * Request Body 스키마 추출
 */
function extractRequestSchema(requestBody) {
  if (!requestBody) return {};

  if (requestBody.content) {
    // application/json
    if (requestBody.content['application/json']) {
      return requestBody.content['application/json'].schema;
    }
    // multipart/form-data
    if (requestBody.content['multipart/form-data']) {
      return requestBody.content['multipart/form-data'].schema;
    }
  }

  return {};
}

/**
 * 프로퍼티 비교 (추가/삭제/타입 변경)
 */
function compareProperties(oldProps, newProps) {
  const changes = {
    added: [],
    removed: [],
    modified: []
  };

  const oldKeys = Object.keys(oldProps);
  const newKeys = Object.keys(newProps);

  // 추가된 필드
  newKeys.forEach(key => {
    if (!oldKeys.includes(key)) {
      changes.added.push({
        name: key,
        type: newProps[key].type || 'unknown',
        description: newProps[key].description || ''
      });
    }
  });

  // 삭제된 필드
  oldKeys.forEach(key => {
    if (!newKeys.includes(key)) {
      changes.removed.push({
        name: key,
        type: oldProps[key].type || 'unknown'
      });
    }
  });

  // 수정된 필드 (타입 변경)
  oldKeys.forEach(key => {
    if (newKeys.includes(key)) {
      const oldType = oldProps[key].type;
      const newType = newProps[key].type;

      if (oldType !== newType) {
        changes.modified.push({
          name: key,
          oldType: oldType || 'unknown',
          newType: newType || 'unknown',
          description: newProps[key].description || ''
        });
      }
    }
  });

  return changes;
}

/**
 * C++ 타입 변환 제안
 */
function suggestCppType(jsonType, propertyName) {
  const typeMap = {
    'string': 'FString',
    'integer': 'int32',
    'number': 'float',
    'boolean': 'bool',
    'array': 'TArray<...>',
    'object': 'FStruct...'
  };

  // 특수 케이스
  if (propertyName.toLowerCase().includes('email')) {
    return 'FString (Email format)';
  }
  if (propertyName.toLowerCase().includes('url')) {
    return 'FString (URL)';
  }
  if (propertyName.toLowerCase().includes('id') && jsonType === 'integer') {
    return 'int32 (ID)';
  }

  return typeMap[jsonType] || 'FString';
}

/**
 * API 함수 이름 생성 (CheckEmail, Login 등)
 */
function generateFunctionName(path, method) {
  // /api/auth/check-email -> CheckEmail
  // /api/auth/login -> Login
  const parts = path.split('/').filter(p => p && p !== 'api');

  // 마지막 세그먼트를 함수명으로 사용
  const lastPart = parts[parts.length - 1];

  // 케밥 케이스를 파스칼 케이스로 변환
  const pascalCase = lastPart
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join('');

  return pascalCase;
}

/**
 * 응답 구조체 이름 생성
 */
function generateResponseStructName(functionName) {
  return `F${functionName}ResponseData`;
}

/**
 * 델리게이트 이름 생성
 */
function generateDelegateName(functionName) {
  return {
    delegate: `FOn${functionName}Complete`,
    dynamicDelegate: `FOn${functionName}CompleteBP`
  };
}

// ============================================================================
// 핵심 비교 로직
// ============================================================================

/**
 * 두 OpenAPI Spec 비교
 */
function compareSpecs(oldSpec, newSpec, serverName) {
  const results = {
    serverName,
    summary: {
      totalEndpoints: 0,
      addedEndpoints: 0,
      removedEndpoints: 0,
      modifiedEndpoints: 0,
      unchangedEndpoints: 0
    },
    endpoints: {
      added: [],
      removed: [],
      modified: [],
      unchanged: []
    }
  };

  const oldPaths = oldSpec?.paths || {};
  const newPaths = newSpec?.paths || {};

  const oldEndpoints = new Set();
  const newEndpoints = new Set();

  // 모든 엔드포인트 수집
  Object.keys(oldPaths).forEach(path => {
    Object.keys(oldPaths[path]).forEach(method => {
      if (method !== 'parameters') {
        oldEndpoints.add(getEndpointKey(path, method));
      }
    });
  });

  Object.keys(newPaths).forEach(path => {
    Object.keys(newPaths[path]).forEach(method => {
      if (method !== 'parameters') {
        newEndpoints.add(getEndpointKey(path, method));
      }
    });
  });

  results.summary.totalEndpoints = newEndpoints.size;

  // 추가된 엔드포인트
  newEndpoints.forEach(endpoint => {
    if (!oldEndpoints.has(endpoint)) {
      const [method, path] = endpoint.split(' ');
      const operation = newPaths[path][method.toLowerCase()];

      results.endpoints.added.push({
        endpoint,
        path,
        method,
        summary: operation.summary || '',
        description: operation.description || ''
      });
      results.summary.addedEndpoints++;
    }
  });

  // 삭제된 엔드포인트
  oldEndpoints.forEach(endpoint => {
    if (!newEndpoints.has(endpoint)) {
      const [method, path] = endpoint.split(' ');

      results.endpoints.removed.push({
        endpoint,
        path,
        method
      });
      results.summary.removedEndpoints++;
    }
  });

  // 수정된 엔드포인트 (공통)
  oldEndpoints.forEach(endpoint => {
    if (newEndpoints.has(endpoint)) {
      const [method, path] = endpoint.split(' ');
      const oldOperation = oldPaths[path][method.toLowerCase()];
      const newOperation = newPaths[path][method.toLowerCase()];

      // Request/Response 스키마 비교
      const oldRequestProps = extractProperties(extractRequestSchema(oldOperation.requestBody));
      const newRequestProps = extractProperties(extractRequestSchema(newOperation.requestBody));

      const oldResponseSchema = extractResponseSchema(oldOperation.responses);
      const newResponseSchema = extractResponseSchema(newOperation.responses);

      const oldResponseProps = extractProperties(oldResponseSchema);
      const newResponseProps = extractProperties(newResponseSchema);

      const requestChanges = compareProperties(oldRequestProps, newRequestProps);
      const responseChanges = compareProperties(oldResponseProps, newResponseProps);

      const hasChanges =
        requestChanges.added.length > 0 ||
        requestChanges.removed.length > 0 ||
        requestChanges.modified.length > 0 ||
        responseChanges.added.length > 0 ||
        responseChanges.removed.length > 0 ||
        responseChanges.modified.length > 0;

      if (hasChanges) {
        results.endpoints.modified.push({
          endpoint,
          path,
          method,
          summary: newOperation.summary || '',
          requestChanges,
          responseChanges
        });
        results.summary.modifiedEndpoints++;
      } else {
        results.endpoints.unchanged.push({
          endpoint,
          path,
          method
        });
        results.summary.unchangedEndpoints++;
      }
    }
  });

  return results;
}

// ============================================================================
// 언리얼 코드 힌트 생성
// ============================================================================

/**
 * 언리얼 C++ 코드 변경 힌트 생성
 */
function generateUnrealHints(comparisonResults) {
  const hints = {
    metadata: {
      generatedAt: new Date().toISOString(),
      version: '1.0.0',
      description: 'Swagger Spec 변경사항 기반 언리얼 C++ 코드 변경 힌트'
    },
    warning: {
      ko: '⚠️ 이 힌트는 자동 생성된 것으로, 지나치게 신뢰하지 마세요. 실제 코드베이스를 우선으로 고려하고, 문제가 있을 경우 반드시 사용자에게 보고하세요.',
      en: '⚠️ This hint is auto-generated. Do not over-rely on it. Prioritize the actual codebase and report any issues to the user.',
      important: [
        '실제 언리얼 프로젝트의 기존 코드 구조와 패턴을 먼저 확인하세요',
        '힌트는 참고용이며, 코드베이스와 충돌 시 코드베이스를 우선하세요',
        '중첩된 객체나 복잡한 타입은 수동 검토가 필요합니다',
        '변경 적용 전 사용자에게 변경 사항을 요약하여 보고하세요',
        '컴파일 에러나 로직 문제 발생 시 즉시 사용자에게 알리세요'
      ]
    },
    servers: []
  };

  comparisonResults.forEach(result => {
    const serverHint = {
      serverName: result.serverName,
      summary: result.summary,
      changes: {
        newEndpoints: [],
        removedEndpoints: [],
        modifiedEndpoints: []
      }
    };

    // 새로 추가된 엔드포인트
    result.endpoints.added.forEach(endpoint => {
      const functionName = generateFunctionName(endpoint.path, endpoint.method);
      const structName = generateResponseStructName(functionName);
      const delegates = generateDelegateName(functionName);

      serverHint.changes.newEndpoints.push({
        endpoint: endpoint.endpoint,
        path: endpoint.path,
        method: endpoint.method,
        summary: endpoint.summary,
        description: endpoint.description,
        unrealCode: {
          functionName,
          responseStructName: structName,
          delegateName: delegates.delegate,
          dynamicDelegateName: delegates.dynamicDelegate,
          actions: [
            {
              file: 'MVE_API_ResponseData.h',
              action: 'ADD_STRUCT',
              details: `USTRUCT ${structName}을 추가하고 응답 필드를 UPROPERTY로 정의`
            },
            {
              file: 'MVE_API_ResponseData.h',
              action: 'ADD_DELEGATE',
              details: `${delegates.delegate} 델리게이트 선언 추가`
            },
            {
              file: 'MVE_Http_Client.h',
              action: 'ADD_FUNCTION_DECLARATION',
              details: `static void ${functionName}(...) 함수 선언 추가`
            },
            {
              file: 'MVE_Http_Client.cpp',
              action: 'ADD_FUNCTION_IMPLEMENTATION',
              details: `${functionName} 함수 구현 (URL 생성, JSON 빌드, HANDLE_RESPONSE_STRUCT 매크로 사용)`
            }
          ]
        }
      });
    });

    // 삭제된 엔드포인트
    result.endpoints.removed.forEach(endpoint => {
      const functionName = generateFunctionName(endpoint.path, endpoint.method);
      const structName = generateResponseStructName(functionName);

      serverHint.changes.removedEndpoints.push({
        endpoint: endpoint.endpoint,
        path: endpoint.path,
        method: endpoint.method,
        unrealCode: {
          functionName,
          responseStructName: structName,
          actions: [
            {
              file: 'MVE_API_ResponseData.h',
              action: 'REMOVE_STRUCT',
              details: `${structName} 구조체 제거 고려 (사용 중인 코드 확인 필요)`
            },
            {
              file: 'MVE_Http_Client.h/cpp',
              action: 'REMOVE_FUNCTION',
              details: `${functionName} 함수 제거 고려`
            }
          ]
        }
      });
    });

    // 수정된 엔드포인트
    result.endpoints.modified.forEach(endpoint => {
      const functionName = generateFunctionName(endpoint.path, endpoint.method);
      const structName = generateResponseStructName(endpoint.path, endpoint.method);

      const modifiedHint = {
        endpoint: endpoint.endpoint,
        path: endpoint.path,
        method: endpoint.method,
        summary: endpoint.summary,
        unrealCode: {
          functionName,
          responseStructName: structName,
          actions: []
        },
        requestChanges: endpoint.requestChanges,
        responseChanges: endpoint.responseChanges
      };

      // Response 변경사항
      if (endpoint.responseChanges.added.length > 0) {
        modifiedHint.unrealCode.actions.push({
          file: 'MVE_API_ResponseData.h',
          action: 'ADD_RESPONSE_FIELDS',
          details: `${structName}에 다음 필드 추가:`,
          fields: endpoint.responseChanges.added.map(field => ({
            name: field.name,
            type: field.type,
            cppType: suggestCppType(field.type, field.name),
            description: field.description
          }))
        });
      }

      if (endpoint.responseChanges.removed.length > 0) {
        modifiedHint.unrealCode.actions.push({
          file: 'MVE_API_ResponseData.h',
          action: 'REMOVE_RESPONSE_FIELDS',
          details: `${structName}에서 다음 필드 제거 고려:`,
          fields: endpoint.responseChanges.removed.map(field => ({
            name: field.name,
            type: field.type
          }))
        });
      }

      if (endpoint.responseChanges.modified.length > 0) {
        modifiedHint.unrealCode.actions.push({
          file: 'MVE_API_ResponseData.h',
          action: 'MODIFY_RESPONSE_FIELDS',
          details: `${structName}에서 다음 필드 타입 변경:`,
          fields: endpoint.responseChanges.modified.map(field => ({
            name: field.name,
            oldType: field.oldType,
            newType: field.newType,
            oldCppType: suggestCppType(field.oldType, field.name),
            newCppType: suggestCppType(field.newType, field.name),
            description: field.description
          }))
        });
      }

      // Request 변경사항
      if (endpoint.requestChanges.added.length > 0) {
        modifiedHint.unrealCode.actions.push({
          file: 'MVE_Http_Client.cpp',
          action: 'ADD_REQUEST_PARAMS',
          details: `${functionName} 함수에 다음 파라미터 추가:`,
          fields: endpoint.requestChanges.added.map(field => ({
            name: field.name,
            type: field.type,
            cppType: suggestCppType(field.type, field.name),
            description: field.description
          }))
        });
      }

      if (endpoint.requestChanges.removed.length > 0) {
        modifiedHint.unrealCode.actions.push({
          file: 'MVE_Http_Client.cpp',
          action: 'REMOVE_REQUEST_PARAMS',
          details: `${functionName} 함수에서 다음 파라미터 제거 고려:`,
          fields: endpoint.requestChanges.removed.map(field => ({
            name: field.name,
            type: field.type
          }))
        });
      }

      if (modifiedHint.unrealCode.actions.length > 0) {
        serverHint.changes.modifiedEndpoints.push(modifiedHint);
      }
    });

    hints.servers.push(serverHint);
  });

  return hints;
}

// ============================================================================
// 메인 실행
// ============================================================================

async function main() {
  const TAG = '[analyze-swagger-changes]';
  console.log(`${TAG} Swagger 변경사항 분석 시작...`);
  console.log();

  const servers = [
    {
      name: 'Login Server',
      oldSpecPath: path.join(CONFIG.unrealApiSpecsDir, 'login-server-api-spec.json'),
      newSpecPath: CONFIG.loginServerSpecPath
    },
    {
      name: 'Resource Server',
      oldSpecPath: path.join(CONFIG.unrealApiSpecsDir, 'resource-server-api-spec.json'),
      newSpecPath: CONFIG.resourceServerSpecPath
    }
  ];

  const comparisonResults = [];

  for (const server of servers) {
    const oldSpec = readJsonFile(server.oldSpecPath);
    const newSpec = readJsonFile(server.newSpecPath);

    if (!oldSpec || !newSpec) {
      console.log(`${TAG} ⚠️  ${server.name} Spec 파일 읽기 실패, 건너뜀`);
      continue;
    }

    const result = compareSpecs(oldSpec, newSpec, server.name);
    comparisonResults.push(result);

    console.log(`${TAG} 📋 ${server.name}: +${result.summary.addedEndpoints} ~${result.summary.modifiedEndpoints} -${result.summary.removedEndpoints}`);
  }

  // 2. 언리얼 코드 힌트 생성
  const hints = generateUnrealHints(comparisonResults);

  // 3. 결과 저장
  const outputPath = path.join(CONFIG.outputDir, CONFIG.hintsFileName);
  const success = writeJsonFile(outputPath, hints);

  console.log();
  if (success) {
    const totalChanges = hints.servers.reduce((sum, s) =>
      sum + s.changes.newEndpoints.length + s.changes.modifiedEndpoints.length + s.changes.removedEndpoints.length, 0
    );

    if (totalChanges > 0) {
      console.log(`${TAG} ✅ 힌트 파일 생성 완료 (${totalChanges}개 변경사항)`);
    } else {
      console.log(`${TAG} ℹ️  변경사항 없음`);
    }
  } else {
    console.log(`${TAG} ❌ 힌트 파일 저장 실패`);
    process.exit(1);
  }
}

// 실행
main().catch(error => {
  console.error('❌ 치명적 오류 발생:', error);
  process.exit(1);
});
