# etcd 3.6 (Debian 12) Docker 镜像

基于 Bitnami etcd 3.6.x 构建脚本的自定义镜像。

## 版本信息

- **etcd 版本**: 3.6.5
- **操作系统**: Debian 12 (Bookworm)
- **架构支持**: linux/amd64, linux/arm64

## 构建镜像

### 方式 1: 使用默认版本号

```bash
cd build/docker
./build-image.sh etcd/3.6/debian-12 3.6.5
```

### 方式 2: 使用自定义版本号

通过 `--build-arg` 参数覆盖版本号：

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg ETCD_VERSION=3.6.6 \
  --build-arg YQ_VERSION=4.47.2 \
  -t harbor.example.com/library/etcd:3.6.6-debian-12 \
  containers/etcd/3.6/debian-12/
```

### 方式 3: 修改构建脚本支持版本变量

更新 `build/docker/build-image.sh`，添加版本参数传递：

```bash
# 在 build-image.sh 中添加
if [ -f "${DOCKERFILE_DIR}/VERSION" ]; then
    DEFAULT_VERSION=$(cat "${DOCKERFILE_DIR}/VERSION" | tr -d '[:space:]')
    BUILD_ARGS+=" --build-arg ETCD_VERSION=${DEFAULT_VERSION}"
fi
```

## Dockerfile 版本变量说明

### ARG 变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `ETCD_VERSION` | `3.6.5` | etcd 版本号 |
| `YQ_VERSION` | `4.47.2` | yq 工具版本号 |
| `DOWNLOADS_URL` | `downloads.bitnami.com/files/stacksmith` | Bitnami 下载地址 |
| `TARGETARCH` | `amd64` | 目标架构 |

### 使用示例

```bash
# 构建特定版本
docker build \
  --build-arg ETCD_VERSION=3.6.6 \
  -t etcd:3.6.6 \
  containers/etcd/3.6/debian-12/

# 构建时使用私有下载源
docker build \
  --build-arg DOWNLOADS_URL=my-mirror.example.com/bitnami \
  --build-arg ETCD_VERSION=3.6.5 \
  -t etcd:3.6.5 \
  containers/etcd/3.6/debian-12/

# 多平台构建
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg ETCD_VERSION=3.6.5 \
  -t harbor.example.com/library/etcd:3.6.5-debian-12 \
  --push \
  containers/etcd/3.6/debian-12/
```

## 推送到 Harbor

```bash
cd build/docker

# 使用默认版本
./push-image.sh etcd/3.6/debian-12 3.6.5

# 或指定完整镜像名
docker tag harbor.example.com/library/etcd:3.6.5-debian-12 \
           harbor.example.com/library/etcd:3.6-debian-12
docker push harbor.example.com/library/etcd:3.6-debian-12
```

## 在 APISIX Chart 中使用

修改 `charts/apisix/values.yaml`:

```yaml
etcd:
  enabled: true
  image:
    registry: harbor.example.com
    repository: library/etcd
    tag: 3.6.5-debian-12
    # 或使用 major.minor 标签
    # tag: 3.6-debian-12
```

## 版本管理策略

### 标签策略

为镜像创建多个标签以支持不同的使用场景：

```bash
# 完整版本标签
3.6.5-debian-12

# Major.Minor 标签（跟随最新 patch）
3.6-debian-12

# Major 标签（生产环境不推荐）
3-debian-12

# Latest 标签（不推荐用于生产）
latest
```

### 构建脚本示例

```bash
#!/bin/bash
ETCD_VERSION="3.6.5"
MAJOR_MINOR="3.6"
MAJOR="3"
OS="debian-12"
REGISTRY="harbor.example.com/library"

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg ETCD_VERSION=${ETCD_VERSION} \
  -t ${REGISTRY}/etcd:${ETCD_VERSION}-${OS} \
  -t ${REGISTRY}/etcd:${MAJOR_MINOR}-${OS} \
  -t ${REGISTRY}/etcd:${MAJOR}-${OS} \
  --push \
  containers/etcd/3.6/debian-12/
```

## 环境变量

运行时环境变量（与 Bitnami etcd 一致）：

| 变量 | 默认值 | 说明 |
|-----|--------|------|
| `ETCD_DATA_DIR` | `/bitnami/etcd/data` | 数据目录 |
| `ETCD_LISTEN_CLIENT_URLS` | `http://0.0.0.0:2379` | 客户端监听地址 |
| `ETCD_LISTEN_PEER_URLS` | `http://0.0.0.0:2380` | Peer 监听地址 |
| `ALLOW_NONE_AUTHENTICATION` | `no` | 允许无认证 |
| `ETCD_ROOT_PASSWORD` | - | Root 密码 |

## 验证镜像

```bash
# 检查版本
docker run --rm harbor.example.com/library/etcd:3.6.5-debian-12 etcd --version

# 检查架构
docker inspect harbor.example.com/library/etcd:3.6.5-debian-12 | jq '.[0].Architecture'

# 运行测试
docker run -d \
  --name etcd-test \
  -p 2379:2379 \
  -e ALLOW_NONE_AUTHENTICATION=yes \
  harbor.example.com/library/etcd:3.6.5-debian-12

# 测试连接
docker exec etcd-test etcdctl endpoint health

# 清理
docker stop etcd-test && docker rm etcd-test
```

## 故障排查

### 版本不匹配

如果遇到 "component not found" 错误：

```bash
# 检查 Bitnami 仓库中可用的版本
curl -s https://downloads.bitnami.com/files/stacksmith/ | grep etcd

# 或使用兼容的版本号
docker build --build-arg ETCD_VERSION=3.6.4 ...
```

### 下载失败

使用镜像源或缓存：

```bash
# 使用阿里云镜像
docker build \
  --build-arg DOWNLOADS_URL=mirrors.aliyun.com/bitnami \
  ...

# 使用本地缓存（需要预先下载）
docker build \
  --mount=type=bind,source=/path/to/cache,target=/tmp/bitnami/pkg/cache \
  ...
```

## 参考资料

- [etcd 官方文档](https://etcd.io/docs/v3.6/)
- [Bitnami etcd 容器](https://github.com/bitnami/containers/tree/main/bitnami/etcd)
- [Bitnami etcd Chart](https://github.com/bitnami/charts/tree/main/bitnami/etcd)

---

**返回**: [etcd README](../../README.md)
