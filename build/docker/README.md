# 🐳 Docker 镜像构建脚本# 🐳 Docker 镜像构建脚本



本目录包含用于构建和推送 Docker 镜像到 Harbor 私有仓库的脚本。本目录包含用于构建和推送 Docker 镜像到 Harbor 私有仓库的脚本。



## 📁 目录结构## 📁 文件说明



```- `build-image.sh` - 构建 Docker 镜像

build/docker/- `push-image.sh` - 推送镜像到 Harbor

├── build-image.sh          # 构建 Docker 镜像- `config.env.example` - 配置文件模板

├── push-image.sh           # 推送镜像到 Harbor- `config.env` - 实际配置文件（不提交到 Git）

├── build-all.sh            # 批量构建脚本- `VERSION-ARGS.md` - 版本变量使用指南

├── config.env              # 配置文件（不提交到 Git）- `BITNAMI-STRUCTURE.md` - Bitnami 目录结构支持说明

├── config.env.example      # 配置文件模板

├── README.md               # 本文档## 🚀 快速开始

└── archive/                # 归档的测试脚本和文档

```### 1. 配置环境



## 🚀 快速开始```bash

# 复制配置模板

### 1. 配置环境cp config.env.example config.env



```bash# 编辑配置文件

# 复制配置模板vim config.env

cp config.env.example config.env```



# 编辑配置文件配置示例：

vim config.env```bash

```HARBOR_URL="harbor.example.com"

HARBOR_PROJECT="library"

**配置说明：**HARBOR_USERNAME="admin"

HARBOR_PASSWORD="Harbor12345"

```bashPLATFORMS="linux/amd64,linux/arm64"

# Harbor 服务器地址USE_BUILDX=true

# 如果 80 端口被占用，需要显式指定端口号（如 :443）PUSH_LATEST=false

HARBOR_URL="reg.localharbor.com:443"```



# Harbor 项目名称### 2. 构建镜像

HARBOR_PROJECT="bitnami"

```bash

# Harbor 认证信息# 基本用法

HARBOR_USERNAME="your-username"./build-image.sh <image-name> <version>

HARBOR_PASSWORD="your-password"

# 示例：构建 etcd 镜像

# 构建平台（单平台或多平台）./build-image.sh etcd 3.5.18

# 注意：多平台构建需要网络访问 Docker Hub```

PLATFORMS="linux/amd64"

# PLATFORMS="linux/amd64,linux/arm64"  # 多平台需要联网### 3. 推送镜像



# 使用 Docker Buildx```bash

USE_BUILDX=true# 基本用法

./push-image.sh <image-name> <version>

# 是否同时推送 latest 标签

PUSH_LATEST=false# 示例：推送 etcd 镜像

./push-image.sh etcd 3.5.18

# 是否禁用缓存```

NO_CACHE=false

```## 🛠️ 脚本详解



### 2. 登录 Harbor### build-image.sh



```bash构建 Docker 镜像并支持多平台构建。

# 如果 Harbor 使用非标准端口，需要指定端口号

docker login reg.localharbor.com:443 -u your-username> 💡 **提示**: 脚本现在支持 Bitnami 风格的嵌套目录结构！详见 [BITNAMI-STRUCTURE.md](./BITNAMI-STRUCTURE.md)  

```> 📝 **格式说明**: 参数格式为 `<name> <version> [path]`，详见 [PARAMETER-FORMAT.md](./PARAMETER-FORMAT.md)



### 3. 构建镜像**用法:**

```bash

**脚本格式：**./build-image.sh <name> <version> [path]

```bash```

./build-image.sh <name> <version> [path]

```**参数:**

- `<name>`: 镜像名称，必填（如 `etcd`, `os-shell`）

**参数说明：**- `<version>`: 镜像版本标签，必填（如 `3.6.5`, `12-debian-12-r50`）

- `name`: 镜像名称（如 etcd, redis）- `[path]`: 子路径，可选（如 `3.6/debian-12`）

- `version`: 镜像版本（如 3.6.5, 7.0.0）

- `path`: 可选，Dockerfile 子路径（如 3.6/debian-12）**环境变量:**

- `PLATFORMS` - 目标平台列表，默认：`linux/amd64,linux/arm64`

**示例：**- `USE_BUILDX` - 是否使用 Docker Buildx，默认：`true`

- `PUSH_LATEST` - 是否同时构建 latest 标签，默认：`false`

```bash- `BUILD_ARGS` - 额外的 Docker 构建参数

# 简单格式（使用 containers/<name>/Dockerfile）- `NO_CACHE` - 是否禁用构建缓存，默认：`false`

./build-image.sh redis 7.0.0

**示例:**

# Bitnami 格式（使用 containers/<name>/<path>/Dockerfile）

./build-image.sh etcd 3.6.5 3.6/debian-12```bash

./build-image.sh redis 7.0.0 7.0/debian-12# 简单格式 - 单平台构建

```./build-image.sh etcd 3.5.18



**对应的目录结构：**# Bitnami 格式 - 构建特定版本

```./build-image.sh etcd 3.6.5 3.6/debian-12

containers/

├── redis/# 多平台构建

│   └── Dockerfile                    # 简单格式PLATFORMS="linux/amd64,linux/arm64" ./build-image.sh etcd 3.6.5 3.6/debian-12

└── etcd/

    └── 3.6/# 构建并添加 latest 标签

        └── debian-12/PUSH_LATEST=true ./build-image.sh etcd 3.5.18

            └── Dockerfile            # Bitnami 格式

```# 使用自定义构建参数（覆盖 VERSION 文件）

BUILD_ARGS="--build-arg ETCD_VERSION=3.6.6" ./build-image.sh etcd 3.6.6 3.6/debian-12

### 4. 推送镜像

# 禁用缓存构建

```bashNO_CACHE=true ./build-image.sh etcd 3.5.18

# 格式与 build-image.sh 相同```

./push-image.sh <name> <version> [path]

### push-image.sh

# 示例

./push-image.sh etcd 3.6.5 3.6/debian-12推送 Docker 镜像到 Harbor 私有仓库。

```

**用法:**

**或者使用 Docker 原生命令：**```bash

```bash./push-image.sh <name> <version> [path]

docker push reg.localharbor.com:443/bitnami/etcd:3.6.5```

```

**参数:**

## 📦 批量构建- `<name>`: 镜像名称，必填

- `<version>`: 镜像版本标签，必填

使用 `build-all.sh` 批量构建多个镜像：- `[path]`: 子路径，可选



```bash**环境变量:**

# 编辑 build-all.sh，添加需要构建的镜像列表- `HARBOR_URL` - Harbor 服务器地址（必需）

vim build-all.sh- `HARBOR_PROJECT` - Harbor 项目名称（必需）

- `HARBOR_USERNAME` - Harbor 用户名

# 执行批量构建- `HARBOR_PASSWORD` - Harbor 密码

./build-all.sh- `PUSH_LATEST` - 是否同时推送 latest 标签，默认：`false`

```

**示例:**

## 🔧 高级配置

```bash

### 单平台 vs 多平台构建# 基本推送

./push-image.sh etcd 3.5.18

**单平台构建（推荐，无需联网）：**

```bash# Bitnami 格式推送

PLATFORMS="linux/amd64"./push-image.sh etcd 3.6.5 3.6/debian-12

USE_BUILDX=true

```# 同时推送 latest 标签

- 镜像会加载到本地 DockerPUSH_LATEST=true ./push-image.sh etcd 3.5.18

- 可以离线构建```

- 构建速度更快

## 🔐 认证方式

**多平台构建（需要联网）：**

```bash### 方式 1: 配置文件（推荐用于本地开发）

PLATFORMS="linux/amd64,linux/arm64"

USE_BUILDX=true在 `config.env` 中设置:

``````bash

- ⚠️ **需要网络访问 Docker Hub** 检查基础镜像 metadataHARBOR_USERNAME="admin"

- 镜像会直接推送到 Harbor（无法 `--load` 到本地）HARBOR_PASSWORD="Harbor12345"

- 支持多架构部署```



### 禁用 Buildx（使用传统 docker build）### 方式 2: 环境变量（推荐用于 CI/CD）



```bash```bash

USE_BUILDX=falseexport HARBOR_USERNAME="robot\$github-actions-bot"

PLATFORMS="linux/amd64"export HARBOR_PASSWORD="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."

```./push-image.sh etcd 3.5.18

```

### 使用自定义构建参数

### 方式 3: 提前登录

```bash

# 在 config.env 中添加```bash

BUILD_ARGS="--build-arg HTTP_PROXY=http://proxy:8080"docker login harbor.example.com -u admin

./push-image.sh etcd 3.5.18

# 或者在命令行中设置```

BUILD_ARGS="--build-arg VERSION=custom" ./build-image.sh etcd 3.6.5

```## 🌍 多平台构建



### 无缓存构建### 前提条件



```bash1. **安装 Docker Buildx:**

# 方法1：在 config.env 中设置

NO_CACHE=trueDocker Desktop 已包含 Buildx。对于 Linux:

```bash

# 方法2：命令行设置# Buildx 通常已预装在 Docker 19.03+

NO_CACHE=true ./build-image.sh etcd 3.6.5docker buildx version

``````



## 🐛 常见问题2. **创建 Buildx Builder:**



### 1. Harbor 连接被拒绝```bash

# 创建多平台 builder

**问题：**docker buildx create --name multiarch --driver docker-container --use

```

Get "http://reg.localharbor.com/v2/": dial tcp 127.0.0.1:80: connect: connection refused# 启动 builder

```docker buildx inspect --bootstrap



**原因：** 80 端口被其他服务（如 APISIX）占用，Docker 无法连接# 验证支持的平台

docker buildx inspect --bootstrap | grep Platforms

**解决方案：** 在 Harbor URL 中显式指定端口号```

```bash

HARBOR_URL="reg.localharbor.com:443"### 支持的平台

docker login reg.localharbor.com:443 -u username

```常见平台：

- `linux/amd64` - x86_64 (Intel/AMD 64-bit)

### 2. 多平台构建需要联网- `linux/arm64` - ARM 64-bit (Apple Silicon, AWS Graviton)

- `linux/arm/v7` - ARM 32-bit

**问题：**- `linux/ppc64le` - PowerPC 64-bit

```- `linux/s390x` - IBM Z

ERROR: failed to solve: failed to fetch metadata

```**配置示例:**

```bash

**原因：** Docker Buildx 在多平台构建时必须访问 Docker Hub 检查基础镜像 metadata# 构建 AMD64 和 ARM64

PLATFORMS="linux/amd64,linux/arm64" ./build-image.sh etcd 3.5.18

**解决方案：**

- **推荐：** 使用单平台构建 `PLATFORMS="linux/amd64"`# 构建多个 ARM 平台

- 或配置 Docker 镜像加速器PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7" ./build-image.sh etcd 3.5.18

- 或在能联网的环境构建```



### 3. unauthorized 错误## 📦 镜像目录结构



**问题：**镜像 Dockerfile 应放在 `containers/<image-name>/` 目录下：

```

unauthorized: unauthorized to access repository```

```containers/

├── etcd/

**原因：** 未登录 Harbor 或凭证过期│   ├── Dockerfile

│   ├── VERSION

**解决方案：**│   └── rootfs/

```bash│       └── opt/

# 重新登录（注意端口号）│           └── bitnami/

docker login reg.localharbor.com:443 -u username│               └── scripts/

```└── postgresql/

    ├── Dockerfile

### 4. 凭证存储错误    └── VERSION

```

**问题：**

```**VERSION 文件（可选）:**

Error saving credentials: error storing credentials - err: exec: "docker-credential-osxkeychain": executable file not found

```可以在镜像目录下创建 `VERSION` 文件用于 CI/CD 自动读取版本号：



**解决方案：** 禁用凭证助手```bash

```bashecho "3.5.18" > containers/etcd/VERSION

mkdir -p ~/.docker```

cat > ~/.docker/config.json << 'EOF'

{## 🔄 完整工作流程

  "credsStore": ""

}### 本地开发流程

EOF

``````bash

# 1. 修改 Dockerfile

## 📚 参考资料vim ../../containers/etcd/Dockerfile



- [Docker Buildx 文档](https://docs.docker.com/buildx/working-with-buildx/)# 2. 构建镜像

- [Harbor 文档](https://goharbor.io/docs/)./build-image.sh etcd 3.5.18

- 归档文档：`archive/` 目录包含更多详细说明

# 3. 测试镜像

## 📄 许可证docker run --rm harbor.example.com/library/etcd:3.5.18 etcd --version



本项目使用的许可证信息请参考项目根目录。# 4. 推送到 Harbor

./push-image.sh etcd 3.5.18

# 5. 验证推送
curl -u admin:password \
  https://harbor.example.com/api/v2.0/projects/library/repositories/etcd/artifacts
```

### CI/CD 流程

GitHub Actions 会自动执行以下步骤：

1. 检测 `containers/` 目录变更
2. 提取镜像名称和版本
3. 调用 `build-image.sh` 构建镜像
4. 调用 `push-image.sh` 推送镜像

详见 `.github/workflows/build-docker.yml`

## 🐛 故障排查

### 问题 1: Buildx Builder 不存在

**错误:**
```
ERROR: failed to find builder "multiarch"
```

**解决:**
```bash
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap
```

### 问题 2: 平台不支持

**错误:**
```
ERROR: multiple platforms feature is currently not supported
```

**解决:**
```bash
# 使用单平台构建
USE_BUILDX=false ./build-image.sh etcd 3.5.18

# 或只构建当前平台
PLATFORMS="linux/amd64" ./build-image.sh etcd 3.5.18
```

### 问题 3: 推送失败 - 认证错误

**错误:**
```
unauthorized: unauthorized to access repository
```

**解决:**
```bash
# 检查登录状态
docker login harbor.example.com -u admin

# 检查 Robot Account 格式
# 正确: robot$github-actions-bot
# 错误: github-actions-bot

# 使用 Robot Account
export HARBOR_USERNAME='robot$github-actions-bot'
export HARBOR_PASSWORD='eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...'
./push-image.sh etcd 3.5.18
```

### 问题 4: 镜像不存在

**错误:**
```
Image not found: harbor.example.com/library/etcd:3.5.18
```

**解决:**
```bash
# 确保先构建镜像
./build-image.sh etcd 3.5.18

# 检查镜像是否存在
docker images | grep etcd
```

### 问题 5: 配置文件未找到

**错误:**
```
Configuration file not found: config.env
```

**解决:**
```bash
# 从模板创建配置文件
cp config.env.example config.env

# 编辑配置
vim config.env
```

## 💡 最佳实践

### 1. 使用 Robot Account

在生产环境和 CI/CD 中使用 Harbor Robot Account 而不是普通用户：

```bash
# 在 Harbor Web UI 创建 Robot Account
# 项目 -> 机器人账户 -> 新建机器人账户

# 使用 Robot Account
HARBOR_USERNAME='robot$github-actions-bot'
HARBOR_PASSWORD='<token>'
```

### 2. 版本管理

使用语义化版本号：

```bash
# 开发版本
./build-image.sh etcd 3.5.18-dev

# 发布版本
./build-image.sh etcd 3.5.18

# 打补丁版本
./build-image.sh etcd 3.5.18-patch1
```

### 3. 构建缓存

利用 Docker 层缓存加速构建：

```bash
# 正常构建（使用缓存）
./build-image.sh etcd 3.5.18

# 清理缓存重新构建
NO_CACHE=true ./build-image.sh etcd 3.5.18

# 定期清理无用缓存
docker buildx prune -a
```

### 4. 多阶段构建

在 Dockerfile 中使用多阶段构建减小镜像体积：

```dockerfile
# 构建阶段
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN go build -o app

# 运行阶段
FROM debian:12-slim
COPY --from=builder /app/app /usr/local/bin/
CMD ["app"]
```

### 5. 安全扫描

推送镜像后在 Harbor 中启用自动扫描：

```bash
# 推送镜像
./push-image.sh etcd 3.5.18

# 在 Harbor Web UI 查看扫描结果
# 项目 -> library -> etcd -> 3.5.18 -> 扫描
```

## 📚 相关文档

- [Harbor 配置指南](../../docs/HARBOR-SETUP.md)
- [使用指南](../../docs/USAGE.md)
- [仓库结构说明](../../docs/STRUCTURE.md)
- [Docker Buildx 文档](https://docs.docker.com/buildx/working-with-buildx/)

---

**返回**: [README](../../README.md)
