# MVE 프로젝트

원티드 포텐업 [언리얼 & AI] 최종 프로젝트의 서버 모노레포입니다.<br>
인증 및 리소스 서버는 AWS EC2 인스턴스에 배포하고 파일 서버로 AWS S3 버킷을 사용하는 것을 상정합니다.<br>
각종 인증 및 리소스 API 요청을 전송하고 리스폰스를 받는 주체는 언리얼 클라이언트 프로세스로 상정합니다.<br>

각 서브모듈에 대한 자세한 내용은 깃허브 리포지토리 페이지를 방문하여 확인하세요.

- **https://github.com/prayslaks/mve-login-server**
- **https://github.com/prayslaks/mve-resource-server**

**⚠️ 주의**: Claude Code 바이브 코딩으로 개발했으므로, 함부로 실제 서비스에 사용하다 보안 문제가 발생해도 책임지지 않습니다.

---

## 목차

- [서브모듈 구성](#서브모듈-구성)
- [주요 기능](#주요-기능)
- [아키텍처](#아키텍처)
- [최초 1회 AWS EC2 배포 환경 설정](#최초-1회-aws-ec2-배포-환경-설정)
- [최초 1회 AWS EC2 배포 이후 업데이트](#최초-1회-aws-ec2-배포-이후-업데이트)
- [Windows 로컬 개발 환경 설정](#windows-로컬-개발-환경-설정)
- [개발용 토큰 인증 우회](#개발용-토큰-인증-우회-unreal-engine-개발-빌드용)
- [AWS EC2 보안 그룹 설정](#aws-ec2-보안-그룹-설정)
- [기술 스택](#기술-스택)
- [시스템 요구사항](#시스템-요구사항)
- [API 문서 자동 생성](#api-문서-자동-생성)
- [문서](#문서)
- [라이선스](#라이선스)

---

## 서브모듈 구성

- **[mve-login-server](mve-login-server/)** - 인증 전용 서버 (회원가입, 로그인, 로그아웃, 회원탈퇴, JWT 토큰 발급)
- **[mve-resource-server](mve-resource-server/)** - 리소스 파일 관리 서버 (음원 스트리밍, 3D 모델 경로 관리)

---

## 주요 기능

### mve-login-server (Port 3000)

**인증 시스템**
- ✅ JWT 기반 인증 (토큰 발급 및 검증)
- ✅ 이메일 인증 시스템 (6자리 인증번호, SMTP)
- ✅ bcrypt 비밀번호 해싱 (salt rounds: 10)
- ✅ Redis 기반 인증번호 저장 및 Rate Limiting
- ✅ 입력값 유효성 검증

**API 엔드포인트**
- 이메일 중복 확인
- 인증번호 발송 및 검증
- 회원가입
- 로그인
- 프로필 조회

### mve-resource-server (Port 3001)

**음원 파일 (공용 - 로그인한 모든 유저 접근 가능)**
- ✅ 음원 목록 조회
- ✅ 음원 스트리밍 (S3: Presigned URL / 로컬: Range Request)
- ✅ 음원 업로드 (AAC, M4A, MP3, WAV 지원)
- ✅ 음원 검색 (제목, 아티스트)
- ✅ 포맷: **AAC (.m4a)** - 압축률 우수, 스트리밍 최적화

**3D 모델 파일 (개인 - 소유자만 접근 가능)**
- ✅ 내 모델 목록 조회
- ✅ 모델 업로드/수정/삭제
- ✅ 모델 다운로드 (Presigned URL)
- ✅ 포맷: **GLB** (glTF Binary)
- ✅ 보안: 사용자별 접근 제어 (자신의 모델만 접근)

**AI 3D 모델 생성**
- ✅ AI 생성 요청 (프롬프트 기반)
- ✅ AI 생성 요청 (이미지 + 프롬프트)
- ✅ 작업 상태 조회 (job_id 기반)
- ✅ Redis 기반 작업 큐 관리
- ✅ 비동기 처리 (요청 즉시 응답, 백그라운드 생성)

**콘서트 시스템**
- ✅ 콘서트 생성/참가/관리
- ✅ 노래 추가/제거/변경 (스튜디오 전용)
- ✅ 액세서리 추가/제거/업데이트 (스튜디오 전용)
- ✅ 리슨 서버 정보 관리
- ✅ Redis 기반 세션 관리

**액세서리 프리셋**
- ✅ 프리셋 저장/조회/수정/삭제
- ✅ 공개/비공개 설정

**공통**
- ✅ JWT 토큰 검증 (모든 API에 적용)
- ✅ PostgreSQL 데이터베이스 (리소스 메타데이터 저장)
- ✅ Redis (콘서트 세션 및 AI 작업 관리)
- ✅ OpenAPI 3.0 스펙 자동 생성
- ✅ Unreal Engine C++ 구조체 연동 검증

---

## 아키텍처

![아키텍처](mve-servers-diagram.png)

---

## 최초 1회 AWS EC2 배포 환경 설정

```bash
# 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# Node.js 20.x 설치
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# PostgreSQL 설치
sudo apt install -y postgresql postgresql-contrib

# Redis 설치
sudo apt install -y redis-server

# Git 설치
sudo apt install -y git

# 버전 확인
node --version
npm --version
psql --version
redis-server --version

# PostgreSQL 서비스 시작
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Redis 서비스 시작
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

```bash
# 서브모듈까지 클론
git clone --recursive https://github.com/prayslaks/mve-servers.git

# 통합 리포지토리로 이동
cd mve-servers

# 서브모듈까지 초기화
git submodule update --init --recursive
```

### 환경 변수 설정

두 서버는 다음 환경 설정을 **반드시 동일하게** 유지해야 합니다:

- JWT 토큰 값이 일치하지 않으면 특정 API 이용 불가
- 데이터베이스 값이 일치하지 않으면 정상 처리 불가
- Redis 값이 일치하지 않으면 각 서버가 독립적인 Redis를 사용하게 됨

SMTP 설정이나 파일 서버 설정 등은 각자 역할에 따라서 구분됩니다.

#### 로그인 서버 예시
```env
# 환경 설정
NODE_ENV=development

# 로그인 서버 포트 번호
PORT=3000

# 데이터베이스 환경설정
DB_HOST=localhost
DB_PORT=5432
DB_USER=your_db_user
DB_PASSWORD=your_db_password
DB_NAME=mve_login_db

# 최소 32자 이상의 랜덤 JWT 비밀 키 (리소스 서버의 JWT 키와 동일해야 함)
JWT_SECRET=your_secret_key_here_make_it_long_and_random

# 인증 번호 전송 이메일 SMTP 환경설정
EMAIL_HOST=smtp.naver.com
EMAIL_PORT=587
EMAIL_SECURE=false
EMAIL_USER=your_naver_email@naver.com
EMAIL_PASSWORD=your_naver_app_password

# Redis 환경설정 (이메일 인증번호 및 Rate Limiting)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
```

#### 리소스 서버 예시 (S3)

```env
# 환경 설정
NODE_ENV=production

# 서버 포트
PORT=3001

# 데이터베이스 환경 설정 (로그인 서버와 동일해야 함)
DB_HOST=localhost
DB_PORT=5432
DB_USER=your_db_user
DB_PASSWORD=your_db_password
DB_NAME=mve_login_db

# S3 버킷 환경 설정 (IAM Role에 의해 EC2 인스턴스는 자동으로 권한 획득)
STORAGE_TYPE=s3
S3_BUCKET=your_bucket
AWS_REGION=your_region

# 최소 32자 이상의 랜덤 JWT 비밀 키 (로그인 서버의 JWT 키와 동일해야 함)
JWT_SECRET=your_secret_key_here_make_it_long_and_random

# AWS S3 버킷 경로 (음원 및 모델링 파일이 저장된 파일 서버)
FILE_SERVER_PATH=./files

# Redis 환경 설정 (콘서트 세션 관리용)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
```

**⚠️ 중요**:
- `NODE_ENV`: 환경 구분 (development / production)
  - `development`: 개발용 토큰 인증 우회 로직 활성화 (리소스 서버)
  - `production`: 보안을 위해 반드시 JWT 토큰 검증 실행
- 자세한 내용은 각 서브모듈 리포지토리의 README.md와 .env.example을 참고해 설정합니다.

```bash
# 최초 1회 이후에는 쉘로 하드 셋업 가능
chmod +x aws-ubuntu-hardsetup-servers.sh
./aws-ubuntu-hardsetup-servers.sh
```

```bash
# 통합 서버 기본 설정 (밑 코드 참고)
sudo nano /etc/nginx/sites-enabled/default

# 너무 긴 EC2 도메인을 위해 server_names_hash_bucket_size 수정
sudo nano /etc/nginx/nginx.conf

# 기본 설정만 남기고 이전 로그인 서버 설정 제거
sudo rm /etc/nginx/sites-enabled/mve-login-server

# 정상 제거 확인
ls -la /etc/nginx/sites-enabled/

# 설정 활성화
sudo nginx -t && sudo systemctl reload nginx
```

```bash
# 기본 설정 이후에 nginx 재구동
sudo nginx -t && sudo systemctl reload nginx

# 밑 내용을 sudo nano /etc/nginx/sites-enabled/default로 작성
server {
    listen 80;
    
    # 용량 제한 100MB
    client_max_body_size 100M;
    
    # EC2 도메인 또는 퍼블릭 IP
    server_name your-domain.com;

    # 헬스 체크 API
    location /health/login {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /health/resource {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Resource Server API
    location /api/audio {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /api/models {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /api/concert {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /api/accessory-presets {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Login Server API (기본)
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

```bash
# psql 콘솔 활성화
sudo -u postgres psql

# psql 콘솔 명령어 =========================
CREATE DATABASE logindb;
ALTER USER postgres WITH PASSWORD '새로운비밀번호';
# psql 콘솔 명령어 =========================

# peer 인증에서 비밀번호로 전환
sudo nano /etc/postgresql/*/main/pg_hba.conf

# psql 재구동
sudo systemctl restart postgresql

# PostgreSQL에서 데이터베이스 생성
psql -U postgres -c "CREATE DATABASE logindb;"

# Login Server 테이블 생성
psql -U postgres -d logindb -f mve-login-server/init.sql

# Resource Server 테이블 생성
psql -U postgres -d logindb -f mve-resource-server/init.sql
```

```bash
# 서버 배포 쉘 스크립트 실행
./aws-ubuntu-start-servers.sh
```

---

## 최초 1회 AWS EC2 배포 이후 업데이트

```bash
# 한번 하드 셋업된 이후부터는 소프트 셋업으로도 충분히 최신 버전 유지
./aws-ubuntu-setup-servers.sh

# 만약 예기치 못한 문제가 발생했다면 하드 셋업으로 완전히 초기화 (환경 설정 파일은 유지)
./aws-ubuntu-hardsetup-servers.sh

# 서버 재구동
pm2 restart all
```

---

## Windows 로컬 개발 환경 설정

Node.js, PostgreSQL, Git이 설치되어 있어야 합니다.

```powershell
# 서브모듈까지 클론
git clone --recursive https://github.com/prayslaks/mve-servers.git

# 통합 리포지토리로 이동
cd mve-servers

# 서브모듈까지 초기화
git submodule update --init --recursive
```

#### 로그인 서버 예시 (로컬과 AWS EC2 모두 동일)
```env
# 환경 설정
NODE_ENV=development

# 로그인 서버 포트 번호
PORT=3000

# 데이터베이스 환경설정
DB_HOST=localhost
DB_PORT=5432
DB_USER=your_db_user
DB_PASSWORD=your_db_password
DB_NAME=mve_login_db

# 최소 32자 이상의 랜덤 JWT 비밀 키 (리소스 서버의 JWT 키와 동일해야 함)
JWT_SECRET=your_secret_key_here_make_it_long_and_random

# 인증 번호 전송 이메일 SMTP 환경설정
EMAIL_HOST=smtp.naver.com
EMAIL_PORT=587
EMAIL_SECURE=false
EMAIL_USER=your_naver_email@naver.com
EMAIL_PASSWORD=your_naver_app_password

# Redis 환경설정 (이메일 인증번호 및 Rate Limiting)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
```

#### 리소스 서버 예시 (로컬)

```env
# 환경 설정
NODE_ENV=development

# 서버 포트
PORT=3001

# 데이터베이스 환경 설정 (로그인 서버와 동일해야 함)
DB_HOST=localhost
DB_PORT=5432
DB_USER=your_db_user
DB_PASSWORD=your_db_password
DB_NAME=mve_login_db

# 스토리지 환경 설정 (값이 's3'가 아니라면 자동으로 로컬 스토리지로 간주)
STORAGE_TYPE=local

# 최소 32자 이상의 랜덤 JWT 비밀 키 (로그인 서버의 JWT 키와 동일해야 함)
JWT_SECRET=your_secret_key_here_make_it_long_and_random

# 로컬 스토리지 경로 (음원 및 모델링 파일이 저장된 파일 서버)
FILE_SERVER_PATH=./files

# Redis 환경 설정 (콘서트 세션 관리용)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
```

```powershell
# psql 콘솔 명령어 =========================
CREATE DATABASE logindb;
ALTER USER postgres WITH PASSWORD '새로운비밀번호';
# psql 콘솔 명령어 =========================
```

```powershell
# PostgreSQL에서 데이터베이스 생성
psql -U postgres -c "CREATE DATABASE logindb;"

# Login Server 테이블 생성
psql -U postgres -d logindb -f mve-login-server/init.sql

# Resource Server 테이블 생성
psql -U postgres -d logindb -f mve-resource-server/init.sql
```

```powershell
# 의존성 설치 (git fetch/pull + 서브모듈 업데이트 + npm install)
windows-local-setup-servers.bat

# 서버 실행
windows-local-start-servers.bat
```

---

## 개발용 토큰 인증 우회 (Unreal Engine 개발 빌드용)

리소스 서버는 개발 환경(`NODE_ENV=development`)에서 로그인 없이 API를 테스트할 수 있도록 하드코딩된 개발용 토큰을 지원합니다.

### 개발용 토큰
```
MVE_DEV_AUTH_TOKEN_2024_A
```

### 사용 방법
```http
GET /api/audio/list
Authorization: Bearer MVE_DEV_AUTH_TOKEN_2024_A
```

### Unreal Engine 예제
```cpp
// 개발 빌드에서는 하드코딩된 개발용 토큰 사용
FString DevToken = TEXT("MVE_DEV_AUTH_TOKEN_2024_A");
Request->SetHeader(TEXT("Authorization"), TEXT("Bearer ") + DevToken);

// 프로덕션 빌드에서는 실제 JWT 토큰 사용
Request->SetHeader(TEXT("Authorization"), TEXT("Bearer ") + ActualJWTToken);
```

### 보안
- `NODE_ENV=development`일 때만 작동
- 프로덕션 환경(`NODE_ENV=production`)에서는 **절대 활성화되지 않음**
- 개발용 토큰 사용 시 가상 사용자 정보(`dev-user-01`) 자동 할당
- 자세한 내용은 [mve-resource-server README](mve-resource-server/README.md#개발용-토큰-인증-우회-unreal-engine-개발-빌드용) 참조

---

## AWS EC2 보안 그룹 설정

| 유형 | 포트 | 소스 | 설명 |
|------|------|------|------|
| HTTPS | 443 | 0.0.0.0/0 | 프로덕션 서비스 |
| HTTP | 80 | 0.0.0.0/0 | 프로덕션 서비스 |
| SSH | 22 | 내 IP | 서버 관리용 |
| Custom TCP | 3000 | 내 IP | 개발용 Login Server |
| Custom TCP | 3001 | 내 IP | 개발용 Resource Server |

---

## 기술 스택

### 공통 (Both Servers)

**런타임 & 프레임워크**
- **Node.js** v20.x+ - JavaScript 런타임 환경
- **Express** v5.1.0 - 웹 애플리케이션 프레임워크
- **dotenv** v17.2.3 - 환경 변수 관리

**데이터베이스 & 캐시**
- **PostgreSQL** - 관계형 데이터베이스 (사용자, 리소스 메타데이터)
- **pg** v8.16.3 - PostgreSQL 클라이언트 라이브러리
- **Redis** v4.7.0 - 인메모리 데이터 저장소 (이메일 인증, 콘서트 세션, Rate Limiting)

**보안 & 인증**
- **jsonwebtoken** v9.0.2 - JWT 기반 인증 토큰 생성/검증
- **cors** v2.8.5 - Cross-Origin Resource Sharing 처리

**API 문서화**
- **swagger-jsdoc** - JSDoc 주석에서 OpenAPI 3.0 스펙 자동 생성
  - `schemas/api-schemas.js`: Component Schema 정의 (단일 소스)
  - `routes/*.js`: Swagger 주석으로 Response Schema 인라인 정의
  - `working-scripts/generate-api-specs.js`: OpenAPI 스펙 생성 스크립트

**인프라 (프로덕션)**
- **PM2** - Node.js 프로세스 관리자
- **Nginx** - 리버스 프록시 및 로드 밸런서
- **AWS EC2** - 서버 호스팅 (Ubuntu)
- **AWS S3** - 클라우드 파일 스토리지

### mve-login-server (인증 서버)

**보안**
- **bcrypt** v6.0.0 - 비밀번호 해싱 (salt rounds: 10)

**이메일 인증**
- **nodemailer** v7.0.10 - SMTP 이메일 전송 (인증번호 발송)

**API 문서화**
- **swagger-ui-express** v5.0.1 - Swagger UI 제공 (`/api-docs`)

**현재 정의된 Component Schema (3개)**
- `User` - 사용자 정보 (id, email, created_at)
- `SuccessResponse` - 기본 성공 응답 (success, code, message)
- `ErrorResponse` - 에러 응답 (success, code, message, details?, dbCode?)

### mve-resource-server (리소스 서버)

**파일 스토리지**
- **AWS SDK v3**
  - **@aws-sdk/client-s3** v3.705.0 - S3 클라이언트
  - **@aws-sdk/s3-request-presigner** v3.705.0 - Presigned URL 생성
- **multer** v1.4.5-lts.1 - 멀티파트 파일 업로드 처리
- **multer-s3** v3.0.1 - S3 직접 업로드 미들웨어

**외부 API 연동**
- **axios** v1.13.2 - HTTP 클라이언트 (AI 모델 생성 API 호출)
- **node-fetch** v3.3.2 - Fetch API 구현
- **form-data** v4.0.5 - Multipart/form-data 생성

**개발 도구**
- **nodemon** v3.0.1 - 개발 시 자동 재시작

**현재 정의된 Component Schema (12개)**
- `BaseResponse`, `ErrorResponse` - 공통 응답 타입
- `Vector3D`, `Rotator` - 기하학적 데이터
- `AudioFile` - 음원 파일 정보
- `ModelInfo`, `AIJobStatus`, `DeletedModelInfo` - 모델 관련
- `Accessory`, `AccessoryPreset` - 액세서리 관련
- `ConcertSong`, `ListenServer`, `ConcertInfo` - 콘서트 관련

### Unreal Engine 연동

**검증 도구**
- **Python 3.x** - C++ 구조체와 API 스펙 검증 스크립트 구동
- **OpenAPI 3.0** - API 스펙 표준 형식
- **검증 스크립트**: `unreal/unreal-rider-python-validation-tool.example`
  - API 스펙의 모든 엔드포인트가 C++ 구조체로 정의되었는지 확인
  - Component Schema가 모두 USTRUCT로 존재하는지 확인
  - Required 필드가 모두 UPROPERTY로 정의되었는지 확인
  - MVE_API_RESPONSE_BASE 매크로 필드 자동 인식

---

## 시스템 요구사항

### 개발 환경
- **Node.js**: v20.x 이상
- **PostgreSQL**: v12 이상
- **Redis**: v6 이상
- **Python**: 3.7 이상 (Unreal 검증 스크립트)
- **Git**: 2.x 이상

### 프로덕션 환경
- **OS**: Ubuntu 20.04 LTS 이상
- **Node.js**: v20.x
- **PostgreSQL**: v12+
- **Redis**: v6+
- **Nginx**: v1.18+
- **AWS 계정**: S3 버킷 및 EC2 인스턴스

---

## API 문서 자동 생성

이 프로젝트는 코드 주석에서 OpenAPI 3.0 스펙을 자동 생성합니다.

### 문서 생성 워크플로우

```bash
# Login Server
cd mve-login-server
npm run docs

# Resource Server
cd mve-resource-server
npm run docs
```

**생성 파일:**
- `mve-login-server/working-scripts/outputs/api-spec.json`
- `mve-resource-server/working-scripts/outputs/resource-server-api-spec.json`

### 설계 원칙 (CLAUDE.md 참조)

**Component Schema (재사용 가능한 타입)**
- 정의 위치: `schemas/api-schemas.js` (단일 소스)
- Unreal Engine 구조체와 매칭됨
- 양쪽 서버 합계 15개 스키마 정의

**Response Schema (엔드포인트별 응답)**
- 정의 위치: `routes/*.js` (Swagger 주석 인라인)
- Component Schema를 `$ref`로 참조
- 공통 필드 (`success`, `code`, `message`) + 추가 필드 구조

### API 추가 시 체크리스트

1. 새로운 재사용 타입이 필요한가? → `schemas/api-schemas.js`에 추가
2. `routes/*.js`에 Swagger 주석 작성 (requestBody, responses)
3. `npm run docs` 실행하여 OpenAPI 스펙 생성
4. 생성된 `api-spec.json`을 [Swagger Editor](https://editor.swagger.io/)에서 확인
5. Git 커밋에 `working-scripts/outputs/*.json` 포함

### Unreal Engine 연동 검증

프로젝트 루트에서 Python 검증 스크립트 실행:
```bash
python unreal/unreal-rider-python-validation-tool.example
```

**검증 항목:**
- API 스펙의 모든 엔드포인트가 C++ 구조체로 정의되었는지 확인
- Component Schema가 모두 USTRUCT로 존재하는지 확인
- Required 필드가 모두 UPROPERTY로 정의되었는지 확인
- MVE_API_RESPONSE_BASE 매크로 필드 자동 인식

---

## 문서

### 사용자 문서

**mve-login-server:**
- **[API_RESPONSES.md](mve-login-server/docs/API_RESPONSES.md)** - API 응답 형식 및 전체 오류 코드 목록
- **[API_TEST.md](mve-login-server/docs/API_TEST.md)** - 상세한 API 테스트 방법 및 예제
- **[ENV_SETUP.md](mve-login-server/docs/ENV_SETUP.md)** - 환경 변수 설정

**mve-resource-server:**
- **[API_RESPONSES.md](mve-resource-server/docs/API_RESPONSES.md)** - API 응답 형식 및 전체 오류 코드 목록
- **[API_TEST.md](mve-resource-server/docs/API_TEST.md)** - 상세한 API 테스트 방법 및 예제
- **[ENV_SETUP.md](mve-resource-server/docs/ENV_SETUP.md)** - 환경 변수 설정
- **[AWS_S3_SETUP.md](mve-resource-server/docs/AWS_S3_SETUP.md)** - AWS S3 설정

### 개발자 문서
- **[CLAUDE.md](CLAUDE.md)** - Claude AI 작업 가이드
  - API 추가/수정 프로세스
  - Component Schema vs Response Schema 설계 원칙
  - Unreal Engine 연동 검증 방법
  - 엄격한 API 응답 구조 규칙

---

## 라이선스

이 프로젝트는 포트폴리오 목적으로 개발되었습니다.
