# MVE 프로젝트

원티드 포텐업 [언리얼 & AI] 최종 프로젝트의 서버 모노레포입니다.<br>
인증 및 리소스 서버는 AWS EC2 인스턴스에 배포하고 파일 서버로 AWS S3 버킷을 사용하는 것을 상정합니다.<br>
각종 인증 및 리소스 API 요청을 전송하고 리스폰스를 받는 주체는 언리얼 클라이언트 프로세스로 상정합니다.<br>

각 서브모듈에 대한 자세한 내용은 깃허브 리포지토리 페이지를 방문하여 확인하세요.

- **https://github.com/prayslaks/mve-login-server**
- **https://github.com/prayslaks/mve-resource-server**

**⚠️ 주의**: Claude Code 바이브 코딩으로 개발했으므로, 함부로 실제 서비스에 사용하다 보안 문제가 발생해도 책임지지 않습니다.

---

## 서브모듈 구성

- **[mve-login-server](mve-login-server/)** - 인증 전용 서버 (회원가입, 로그인, 로그아웃, 회원탈퇴, JWT 토큰 발급)
- **[mve-resource-server](mve-resource-server/)** - 리소스 파일 관리 서버 (음원 스트리밍, 3D 모델 경로 관리)

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
- 자세한 내용은 [mve-resource-server](mve-resource-server/) 참조

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
- **dotenv** - 환경 변수 관리

**데이터베이스 & 캐시**
- **PostgreSQL** - 관계형 데이터베이스 (사용자, 리소스 메타데이터)
- **pg** v8.16.3 - PostgreSQL 클라이언트 라이브러리
- **Redis** v4.7.0 - 인메모리 데이터 저장소 (이메일 인증, 콘서트 세션, Rate Limiting)

**보안 & 인증**
- **jsonwebtoken** v9.0.2 - JWT 기반 인증 토큰 생성/검증
- **cors** v2.8.5 - Cross-Origin Resource Sharing 처리

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
- **swagger-jsdoc** v6.2.8 - OpenAPI 3.0 스펙 생성
- **swagger-ui-express** v5.0.1 - Swagger UI 제공

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

### Unreal Engine 연동

**검증 도구**
- **Python 3.x** - C++ 구조체와 API 스펙 검증 스크립트
- **OpenAPI 3.0** - API 스펙 표준 형식

**C++ 매크로**
- `MVE_API_RESPONSE_BASE` - 공통 API 응답 필드 자동 추가

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

## 라이선스

이 프로젝트는 포트폴리오 목적으로 개발되었습니다.
