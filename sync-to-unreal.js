const fs = require('fs');
const path = require('path');

// 최상위 환경 변수
require('dotenv').config({ path: path.join(__dirname, '.env') });

// 언리얼 프로젝트 경로 (환경변수 또는 설정 파일)
const unrealPath = process.env.UNREAL_PROJECT_PATH || '../../Unreal Projects/MVE';

// api-spec.json 복사
fs.copyFileSync(
  path.join(__dirname, 'mve-login-server/docs/api-spec.json'),
  path.join(unrealPath, '/ApiSpecs/login-api-spec.json')
);

console.log('인증 서버 API 문서를 언리얼 프로젝트로 동기화했습니다!');

// api-spec.json 복사
fs.copyFileSync(
  path.join(__dirname, 'mve-resource-server/docs/api-spec.json'),
  path.join(unrealPath, '/ApiSpecs/resource-api-spec.json')
);

console.log('리소스 서버 API 문서를 언리얼 프로젝트로 동기화했습니다!');

// response-code-statistics.json 복사
fs.copyFileSync(
  path.join(__dirname, 'working-scripts/response-code-statistics.json'),
  ptth.join(unrealPath, '/ApiSpecs/response-code-statistics.json')
)