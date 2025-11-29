module.exports = {
  apps: [
    // ============================================
    // MVE Login Server
    // ============================================
    {
      name: 'mve-login-server',
      script: './mve-login-server/server.js',

      // [t3.micro 최적화 설정]
      // Stateless REST API (JWT 기반) - 프로세스 간 공유 상태 없음
      instances: 2,              // t3.micro의 2 vCPU 활용
      exec_mode: 'cluster',      // 클러스터 모드로 로드 밸런싱

      // [메모리 보호]
      // t3.micro는 총 1GB RAM, OS가 ~200MB 사용
      // 남은 800MB를 두 서버가 나눠 사용 (각각 최대 350MB)
      max_memory_restart: '350M',

      // [로그 관리]
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      error_file: './logs/login-error.log',
      out_file: './logs/login-output.log',
      merge_logs: true,

      // [환경 변수]
      env: {
        NODE_ENV: 'development',
        PORT: 3000
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000
      }
    },

    // ============================================
    // MVE Resource Server
    // ============================================
    {
      name: 'mve-resource-server',
      script: './mve-resource-server/server.js',

      // [t3.micro 최적화 설정]
      // Redis 사용 중 → REST API는 클러스터 모드 안전 (Redis = 공유 저장소)
      // ⚠️ Socket.io 도입 시 주의:
      //    - Redis Adapter 없이는 클러스터 모드 불가 (WebSocket 연결이 특정 인스턴스에 고정됨)
      //    - Redis Adapter 있으면 클러스터 모드 안전 (인스턴스 간 이벤트 브로드캐스트 가능)
      // 현재: Socket.io 미사용이므로 클러스터 모드 가능하나, 메모리 절약 위해 1개 운영
      instances: 2,
      exec_mode: 'cluster',      // Redis 공유 저장소 덕분에 안전

      // [메모리 보호]
      // 2개 인스턴스로 Login 서버와 동일하게 운영
      max_memory_restart: '350M',

      // [로그 관리]
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      error_file: './logs/resource-error.log',
      out_file: './logs/resource-output.log',
      merge_logs: true,

      // [환경 변수]
      env: {
        NODE_ENV: 'development',
        PORT: 3001
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3001
      }
    }
  ]
};

// ============================================
// 사용법 및 설정 가이드
// ============================================
//
// PM2 시작:
//   pm2 start ecosystem.config.js
//   pm2 start ecosystem.config.js --env production  (프로덕션 모드)
//
// PM2 관리:
//   pm2 list              - 실행 중인 프로세스 목록
//   pm2 logs              - 실시간 로그 확인
//   pm2 monit             - CPU/메모리 모니터링
//   pm2 restart all       - 모든 서버 재시작
//   pm2 stop all          - 모든 서버 중지
//   pm2 delete all        - 모든 프로세스 제거
//
// 개별 서버 관리:
//   pm2 restart mve-login-server
//   pm2 restart mve-resource-server
//   pm2 logs mve-login-server
//   pm2 logs mve-resource-server
//
// 자동 시작 설정 (재부팅 시 자동 실행):
//   pm2 startup           - 시스템 시작 스크립트 생성
//   pm2 save              - 현재 프로세스 목록 저장
//
// ============================================
// t3.micro 메모리 할당 전략
// ============================================
//
// 전체 메모리: 1024MB
// - OS (Linux): ~200MB
// - mve-login-server (2 instances): 350MB × 2 = 700MB (사실상 안전 상한선)
// - mve-resource-server (1 instance): 450MB (실제로는 더 적게 사용)
// - 여유 공간: ~100MB (버퍼)
//
// ⚠️ 클러스터 모드가 안전한 이유:
// 1. Login 서버: Stateless REST API (JWT) → 공유 상태 없음 → 클러스터 안전 ✅
// 2. Resource 서버: Redis를 공유 저장소로 사용 → 클러스터 안전 ✅
//    - 모든 인스턴스가 같은 Redis 바라봄
//    - HTTP REST API만 사용 (WebSocket 아님)
// 3. 각 프로세스가 메모리 제한 초과 시 PM2가 자동 재시작
//
// ⚠️ Socket.io 도입 시 주의사항:
// - WebSocket은 stateful 연결 (클라이언트 ↔ 특정 인스턴스)
// - Redis Adapter 없이 클러스터 모드 사용하면 연결 끊김 발생
// - Redis Adapter 도입 후 클러스터 모드 사용 가능
//
// ============================================
// Socket.io 도입 시 변경사항
// ============================================
//
// 현재: 클러스터 모드 2개 인스턴스로 운영 중
// Socket.io 도입 시 2가지 선택지:
//
// [옵션 1] Redis Adapter 없이 사용 (개발 단계)
// {
//   instances: 1,              // ← 2에서 1로 변경
//   exec_mode: 'fork',         // ← cluster에서 fork로 변경
//   max_memory_restart: '450M',
// }
//
// [옵션 2] Redis Adapter 사용 (프로덕션 권장)
// {
//   instances: 2,              // ← 그대로 유지
//   exec_mode: 'cluster',      // ← 그대로 유지
//   max_memory_restart: '350M',
// }
// + 코드에서 Socket.io Redis Adapter 설정 추가 필요
//
// ============================================
// 메모리 모니터링 팁
// ============================================
//
// 실시간 메모리 사용량 확인:
//   pm2 monit
//
// 메모리 사용량이 지속적으로 높으면:
//   pm2 restart all --update-env
//
// 특정 앱의 메모리 제한 임시 조정:
//   pm2 restart mve-resource-server --max-memory-restart 400M
//
