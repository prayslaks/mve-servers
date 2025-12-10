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
const unrealProjectDir = path.join('c:', 'Users', 'user', 'Documents', 'Unreal Projects', 'MVE');
const unrealApiSpecsDir = path.join(unrealProjectDir, 'ApiSpecs');

// 서버 설정
const servers = [
  {
    name: 'login-server',
    dir: path.join(rootDir, 'mve-login-server'),
    analyzeScript: path.join(rootDir, 'mve-login-server', 'scripts', 'analyze-response-codes.js'),
    generateScript: path.join(rootDir, 'mve-login-server', 'scripts', 'generate-api-docs.js'),
    outputFiles: [
      { src: 'docs/response-code-statistics.json', dest: 'login-server-response-codes.json' },
      { src: 'docs/api-spec.json', dest: 'login-server-api-spec.json' }
    ]
  },
  {
    name: 'resource-server',
    dir: path.join(rootDir, 'mve-resource-server'),
    analyzeScript: path.join(rootDir, 'mve-resource-server', 'scripts', 'analyze-response-codes.js'),
    generateScript: path.join(rootDir, 'mve-resource-server', 'scripts', 'generate-api-docs.js'),
    outputFiles: [
      { src: 'docs/response-code-statistics.json', dest: 'resource-server-response-codes.json' },
      { src: 'docs/api-spec.json', dest: 'resource-server-api-spec.json' }
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
    // 디렉토리가 없으면 생성
    const destDir = path.dirname(destPath);
    if (!fs.existsSync(destDir)) {
      fs.mkdirSync(destDir, { recursive: true });
    }

    fs.copyFileSync(srcPath, destPath);
    console.log(`  ✅ 복사 완료: ${path.basename(destPath)}`);
    return true;
  } catch (error) {
    console.error(`  ❌ 복사 실패: ${error.message}`);
    return false;
  }
}

/**
 * 메인 실행 함수
 */
async function main() {
  console.log('='.repeat(80));
  console.log('🚀 API 문서 생성 및 언리얼 프로젝트 복사 스크립트');
  console.log('='.repeat(80));
  console.log();

  // 언리얼 프로젝트 폴더 확인
  if (!fs.existsSync(unrealProjectDir)) {
    console.error(`❌ 언리얼 프로젝트 폴더를 찾을 수 없습니다: ${unrealProjectDir}`);
    process.exit(1);
  }

  // ApiSpecs 폴더 생성 (없으면)
  if (!fs.existsSync(unrealApiSpecsDir)) {
    console.log(`📁 ApiSpecs 폴더 생성: ${unrealApiSpecsDir}`);
    fs.mkdirSync(unrealApiSpecsDir, { recursive: true });
  }

  let totalSuccess = 0;
  let totalFailed = 0;

  // 각 서버별로 처리
  for (const server of servers) {
    console.log('='.repeat(80));
    console.log(`📦 ${server.name.toUpperCase()} 처리 중...`);
    console.log('='.repeat(80));
    console.log();

    // 1. Response Code 분석 스크립트 실행
    process.stdout.write(`📊 [1/2] Response Code 분석 중... `);
    const analyzeSuccess = runCommand(`node "${server.analyzeScript}"`, server.dir);

    if (!analyzeSuccess) {
      console.log('❌ 실패');
      totalFailed += 2;
      continue;
    }
    console.log('✅');

    // 2. API 문서 생성 스크립트 실행
    process.stdout.write(`📝 [2/2] API 문서 생성 중... `);
    const generateSuccess = runCommand(`node "${server.generateScript}"`, server.dir);

    if (!generateSuccess) {
      console.log('❌ 실패');
      totalFailed += 1;
      continue;
    }
    console.log('✅');

    // 3. 생성된 파일들을 언리얼 프로젝트로 복사
    console.log(`📋 생성된 파일 복사 중...`);
    for (const file of server.outputFiles) {
      const srcPath = path.join(server.dir, file.src);
      const destPath = path.join(unrealApiSpecsDir, file.dest);

      if (!fs.existsSync(srcPath)) {
        console.log(`  ❌ 소스 파일을 찾을 수 없습니다: ${path.basename(srcPath)}`);
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
    console.log();
  }

  // 최종 결과 출력
  console.log('='.repeat(80));
  console.log('📈 최종 결과');
  console.log('='.repeat(80));
  console.log(`✅ 성공: ${totalSuccess}개 파일`);
  console.log(`❌ 실패: ${totalFailed}개`);
  console.log();
  console.log(`📁 언리얼 프로젝트 ApiSpecs 폴더: ${unrealApiSpecsDir}`);
  console.log();

  // 복사된 파일 목록 출력
  if (fs.existsSync(unrealApiSpecsDir)) {
    console.log('📄 복사된 파일 목록:');
    const files = fs.readdirSync(unrealApiSpecsDir);
    files.forEach(file => {
      const filePath = path.join(unrealApiSpecsDir, file);
      const stats = fs.statSync(filePath);
      const size = (stats.size / 1024).toFixed(2);
      console.log(`  - ${file} (${size} KB)`);
    });
    console.log();
  }

  if (totalFailed > 0) {
    console.log('⚠️  일부 작업이 실패했습니다. 위 로그를 확인해주세요.');
    process.exit(1);
  } else {
    console.log('🎉 모든 작업이 성공적으로 완료되었습니다!');
  }
}

// 실행
main().catch(error => {
  console.error('❌ 치명적 오류 발생:', error);
  process.exit(1);
});
