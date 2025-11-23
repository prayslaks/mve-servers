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

## 환경 설정

두 서버는 다음 환경 설정을 **반드시 동일하게** 유지해야 합니다:

- JWT 토큰 값이 일치하지 않으면 특정 API 이용 불가
- 데이터베이스 값이 일치하지 않으면 정상 처리 불가

SMTP 설정이나 파일 서버 설정 등은 각자 역할에 따라서 구분됩니다.

### 로그인 서버 예시
```env
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
```

### 리소스 서버 예시

```env
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
```

```env
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
```

**⚠️ 주의**: 자세한 내용은 각 서브모듈 리포지토리의 README.md와 .env.example을 참고해 설정합니다.

---

## 빠른 시작

### 1. 저장소 클론 (서브모듈 포함)

```bash
git clone --recursive <repository-url>
cd MVE
```

기존 저장소에서 서브모듈 초기화:
```bash
git submodule update --init --recursive
```

### 2. 데이터베이스 설정

```bash
# PostgreSQL에서 데이터베이스 생성
psql -U postgres -c "CREATE DATABASE logindb;"

# Login Server 테이블 생성
psql -U postgres -d logindb -f mve-login-server/init.sql

# Resource Server 테이블 생성
psql -U postgres -d logindb -f mve-resource-server/init.sql
```

### 3. 환경 변수 설정

각 서버 디렉토리에 `.env` 파일 생성 (위의 공유 의존성 참고)

### 4. 서버 실행

**Windows 로컬 개발 환경:**
```powershell
# 의존성 설치
windows-local-setup-servers.bat

# 서버 실행
windows-local-start-servers.bat
```

**AWS EC2 Ubuntu 프로덕션 환경:**
```bash
# 의존성 설치 (git pull + npm install)
chmod +x aws-ubuntu-setup-servers.sh
./aws-ubuntu-setup-servers.sh

# 서버 실행 (PM2)
chmod +x aws-ubuntu-start-servers.sh
./aws-ubuntu-start-servers.sh
```

**수동 실행:**
```bash
# 개발 환경
cd mve-login-server && node server.js
cd mve-resource-server && node server.js

# 프로덕션 환경 (PM2)
pm2 start mve-login-server/server.js --name mve-login-server
pm2 start mve-resource-server/server.js --name mve-resource-server
pm2 save
```

### 5. API 테스트

브라우저에서 API를 테스트할 수 있는 웹페이지를 제공합니다.

---

## Nginx 리버스 프록시 설정

두 서버를 하나의 도메인으로 서비스:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # Resource Server API (먼저 정의)
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

> **⚠️ 주의**: `/api/audio`와 `/api/models`를 먼저 정의해야 합니다.

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

- **Node.js** - 런타임 환경
- **Express** - 웹 프레임워크
- **PostgreSQL** - 관계형 데이터베이스
- **JWT** - 인증 토큰
- **PM2** - 프로세스 관리
- **Nginx** - 리버스 프록시
- **AWS S3** - 파일 스토리지 (프로덕션)

---

## 라이선스

이 프로젝트는 포트폴리오 목적으로 개발되었습니다.
