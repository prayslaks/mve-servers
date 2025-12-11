#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * API 문서 생성 → 언리얼 복사 → 변경사항 분석 통합 워크플로우
 *
 * 실행 순서:
 * 1. generate-and-copy-docs.js 실행 (API 문서 생성 및 언리얼 프로젝트 복사)
 * 2. analyze-swagger-changes.js 실행 (변경사항 분석 및 힌트 생성)
 */

const scriptsDir = __dirname;
const TAG = '[sync-api-to-unreal]';

console.log(`${TAG} API → 언리얼 동기화 시작...`);
console.log();

// Step 1: 문서 생성 및 복사
try {
  execSync(`node "${path.join(scriptsDir, 'generate-and-copy-docs.js')}"`, {
    stdio: 'inherit',
    shell: true
  });
} catch (error) {
  console.error(`${TAG} ❌ 문서 생성 실패`);
  process.exit(1);
}

// Step 2: 변경사항 분석
try {
  execSync(`node "${path.join(scriptsDir, 'analyze-swagger-changes.js')}"`, {
    stdio: 'inherit',
    shell: true
  });
} catch (error) {
  console.error(`${TAG} ❌ 변경사항 분석 실패`);
  process.exit(1);
}

// Step 3: 힌트 파일 언리얼로 복사
const hintsSourcePath = path.join(scriptsDir, 'outputs', 'unreal-api-change-hints.json');
const hintsDestPath = 'c:\\Users\\user\\Documents\\Unreal Projects\\MVE\\ApiSpecs\\unreal-api-change-hints.json';

try {
  if (fs.existsSync(hintsSourcePath)) {
    fs.copyFileSync(hintsSourcePath, hintsDestPath);
    console.log(`${TAG} 📋 힌트 파일 복사 완료`);
  } else {
    console.log(`${TAG} ℹ️  힌트 파일 없음 (변경사항 없음)`);
  }
} catch (error) {
  console.error(`${TAG} ❌ 힌트 파일 복사 실패`);
  process.exit(1);
}

console.log();
console.log(`${TAG} ✅ 동기화 완료`);
