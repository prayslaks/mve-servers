#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * 두 서버의 문서를 생성하고 언리얼 프로젝트로 복사하는 통합 스크립트
 *
 * 실행 순서:
 * 1. mve-login-server/scripts/analyze-response-codes.js 실행
 * 2. mve-login-server/scripts/generate-api-docs.js 실행
 * 3. mve-resource-server/scripts/analyze-response-codes.js 실행
 * 4. mve-resource-server/scripts/generate-api-docs.js 실행
 * 5. 생성된 JSON 파일들을 언리얼 프로젝트의 ApiSpecs 폴더로 복사
 */

// 경로 설정
const rootDir = path.join(__dirname, '..');
const outputDir = path.join(__dirname, 'outputs');
const unrealProjectDir = path.join('c:', 'Users', 'user', 'Documents', 'Unreal Projects', 'MVE');
const unrealApiSpecsDir = path.join(unrealProjectDir, 'ApiSpecs');

// 서버 설정
const servers = [
  {
    name: 'login-server',
    dir: path.join(rootDir, 'mve-login-server'),
    analyzeScript: path.join(rootDir, 'mve-login-server', 'working-scripts', 'analyze-response-codes.js'),
    generateScript: path.join(rootDir, 'mve-login-server', 'working-scripts', 'generate-api-specs.js'),
    outputFiles: [
      { src: 'working-scripts/outputs/response-code-statistics.json', dest: 'login-server-response-codes.json' },
      { src: 'working-scripts/outputs/api-spec.json', dest: 'login-server-api-spec.json' }
    ]
  },
  {
    name: 'resource-server',
    dir: path.join(rootDir, 'mve-resource-server'),
    analyzeScript: path.join(rootDir, 'mve-resource-server', 'working-scripts', 'analyze-response-codes.js'),
    generateScript: path.join(rootDir, 'mve-resource-server', 'working-scripts', 'generate-api-specs.js'),
    outputFiles: [
      { src: 'working-scripts/outputs/response-code-statistics.json', dest: 'resource-server-response-codes.json' },
      { src: 'working-scripts/outputs/api-spec.json', dest: 'resource-server-api-spec.json' }
    ]
  }
];

/**
 * 명령어 실행 헬퍼 함수
 */
function runCommand(command, cwd) {
  try {
    execSync(command, {
      cwd,
      stdio: 'pipe', // 출력 숨김
      shell: true
    });
    return true;
  } catch (error) {
    console.error(`  ❌ 명령어 실행 실패: ${error.message}`);
    return false;
  }
}

/**
 * 파일 복사 함수
 */
function copyFile(srcPath, destPath) {
  try {
    const destDir = path.dirname(destPath);
    if (!fs.existsSync(destDir)) {
      fs.mkdirSync(destDir, { recursive: true });
    }
    fs.copyFileSync(srcPath, destPath);
    return true;
  } catch (error) {
    return false;
  }
}

/**
 * 메인 실행 함수
 */
async function main() {
  const TAG = '[generate-and-copy-docs]';
  console.log(`${TAG} API 문서 생성 및 복사 시작...`);
  console.log();

  // 언리얼 프로젝트 폴더 확인
  if (!fs.existsSync(unrealProjectDir)) {
    console.error(`${TAG} ❌ 언리얼 프로젝트 폴더를 찾을 수 없습니다: ${unrealProjectDir}`);
    process.exit(1);
  }

  // ApiSpecs 폴더 생성 (없으면)
  if (!fs.existsSync(unrealApiSpecsDir)) {
    fs.mkdirSync(unrealApiSpecsDir, { recursive: true });
  }

  let totalSuccess = 0;
  let totalFailed = 0;

  // 각 서버별로 처리
  for (const server of servers) {
    console.log(`${TAG} 📦 ${server.name} 처리 중...`);

    // 1. Response Code 분석 스크립트 실행
    const analyzeSuccess = runCommand(`node "${server.analyzeScript}"`, server.dir);
    if (!analyzeSuccess) {
      console.log(`${TAG}    ❌ Response Code 분석 실패`);
      totalFailed += 2;
      continue;
    }

    // 2. API 문서 생성 스크립트 실행
    const generateSuccess = runCommand(`node "${server.generateScript}"`, server.dir);
    if (!generateSuccess) {
      console.log(`${TAG}    ❌ API 문서 생성 실패`);
      totalFailed += 1;
      continue;
    }

    // 3. 생성된 파일들을 모노리포 outputs 폴더로 복사
    for (const file of server.outputFiles) {
      const srcPath = path.join(server.dir, file.src);
      const destPath = path.join(outputDir, file.dest);

      if (!fs.existsSync(srcPath)) {
        totalFailed++;
        continue;
      }

      const copySuccess = copyFile(srcPath, destPath);
      if (copySuccess) {
        totalSuccess++;
      } else {
        totalFailed++;
      }
    }

    // 4. 생성된 파일들을 언리얼 프로젝트로 복사
    for (const file of server.outputFiles) {
      const srcPath = path.join(server.dir, file.src);
      const destPath = path.join(unrealApiSpecsDir, file.dest);

      if (!fs.existsSync(srcPath)) {
        totalFailed++;
        continue;
      }

      const copySuccess = copyFile(srcPath, destPath);
      if (copySuccess) {
        totalSuccess++;
      } else {
        totalFailed++;
      }
    }
  }

  // 최종 결과 출력
  console.log();
  if (totalFailed > 0) {
    console.log(`${TAG} ⚠️  성공 ${totalSuccess}개, 실패 ${totalFailed}개`);
    process.exit(1);
  } else {
    console.log(`${TAG} ✅ 완료 (${totalSuccess}개 파일 복사)`);
  }
}

// 실행
main().catch(error => {
  console.error('❌ 치명적 오류 발생:', error);
  process.exit(1);
});