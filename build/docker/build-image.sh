#!/usr/bin/env bash

# Docker 镜像构建脚本
# 用法: ./build-image.sh <name> <version> [path]
# 示例: 
#   ./build-image.sh etcd 3.5.18
#   ./build-image.sh etcd 3.6.5 3.6/debian-12

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查参数
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <name> <version> [path]"
    log_info "Examples:"
    log_info "  Simple:   $0 etcd 3.5.18"
    log_info "  Bitnami:  $0 etcd 3.6.5 3.6/debian-12"
    log_info "  Full:     $0 os-shell 12-debian-12-r50 12/debian-12"
    exit 1
fi

IMAGE_NAME="$1"
IMAGE_TAG="$2"
IMAGE_SUBPATH="${3:-}"  # 可选的子路径参数

# 加载配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

if [ -f "$CONFIG_FILE" ]; then
    log_info "Loading configuration from ${CONFIG_FILE}"
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
else
    log_warn "Configuration file not found: ${CONFIG_FILE}"
    log_warn "Using default configuration"
fi

# 默认配置
HARBOR_URL="${HARBOR_URL:-harbor.example.com}"
HARBOR_PROJECT="${HARBOR_PROJECT:-library}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
USE_BUILDX="${USE_BUILDX:-true}"
PUSH_LATEST="${PUSH_LATEST:-false}"
BUILD_ARGS="${BUILD_ARGS:-}"
NO_CACHE="${NO_CACHE:-false}"

# 构建 Dockerfile 路径
# 如果提供了子路径参数，使用 containers/<name>/<path>/Dockerfile
# 否则使用 containers/<name>/Dockerfile
if [ -n "${IMAGE_SUBPATH}" ]; then
    DOCKERFILE_DIR="${SCRIPT_DIR}/../../containers/${IMAGE_NAME}/${IMAGE_SUBPATH}"
else
    DOCKERFILE_DIR="${SCRIPT_DIR}/../../containers/${IMAGE_NAME}"
fi

# 构建完整镜像名
FULL_IMAGE_NAME="${HARBOR_URL}/${HARBOR_PROJECT}/${IMAGE_NAME}"

# 检查 Dockerfile 是否存在
if [ ! -f "${DOCKERFILE_DIR}/Dockerfile" ]; then
    log_error "Dockerfile not found: ${DOCKERFILE_DIR}/Dockerfile"
    log_info "Searched in: ${DOCKERFILE_DIR}"
    exit 1
fi

# 自动读取版本号并添加到构建参数
if [ -f "${DOCKERFILE_DIR}/VERSION" ]; then
    DEFAULT_VERSION=$(cat "${DOCKERFILE_DIR}/VERSION" | tr -d '[:space:]')
    if [ -n "${DEFAULT_VERSION}" ]; then
        log_info "Found VERSION file with version: ${DEFAULT_VERSION}"
        # 根据镜像名称添加对应的版本构建参数
        case "${IMAGE_NAME}" in
            etcd)
                BUILD_ARGS+=" --build-arg ETCD_VERSION=${DEFAULT_VERSION}"
                ;;
            os-shell)
                BUILD_ARGS+=" --build-arg OS_SHELL_VERSION=${DEFAULT_VERSION}"
                ;;
            *)
                BUILD_ARGS+=" --build-arg VERSION=${DEFAULT_VERSION}"
                ;;
        esac
    fi
fi

log_info "Building Docker image..."
log_info "  Image name:    ${IMAGE_NAME}"
log_info "  Image version: ${IMAGE_TAG}"
if [ -n "${IMAGE_SUBPATH}" ]; then
    log_info "  Image path:    ${IMAGE_SUBPATH}"
fi
log_info "  Full image:    ${FULL_IMAGE_NAME}:${IMAGE_TAG}"
log_info "  Platforms:     ${PLATFORMS}"
log_info "  Dockerfile:    ${DOCKERFILE_DIR}/Dockerfile"
if [ -n "${BUILD_ARGS}" ]; then
    log_info "  Build args:    ${BUILD_ARGS}"
fi

# 构建镜像
cd "${DOCKERFILE_DIR}"

if [ "${USE_BUILDX}" = "true" ]; then
    log_info "Using Docker Buildx for multi-platform build"
    
    # 检查 buildx builder 是否存在
    if ! docker buildx inspect multiarch >/dev/null 2>&1; then
        log_warn "Buildx builder 'multiarch' not found, creating..."
        docker buildx create --name multiarch --driver docker-container --use
        docker buildx inspect --bootstrap
    else
        docker buildx use multiarch
    fi
    
    # 构建参数
    BUILD_CMD="docker buildx build"
    BUILD_CMD+=" --platform ${PLATFORMS}"
    BUILD_CMD+=" -t ${FULL_IMAGE_NAME}:${IMAGE_TAG}"
    
    if [ "${PUSH_LATEST}" = "true" ]; then
        BUILD_CMD+=" -t ${FULL_IMAGE_NAME}:latest"
    fi
    
    if [ "${NO_CACHE}" = "true" ]; then
        BUILD_CMD+=" --no-cache"
    fi
    
    if [ -n "${BUILD_ARGS}" ]; then
        BUILD_CMD+=" ${BUILD_ARGS}"
    fi
    
    # 检查是否是多平台构建
    PLATFORM_COUNT=$(echo "${PLATFORMS}" | tr ',' '\n' | wc -l | tr -d ' ')
    if [ "${PLATFORM_COUNT}" -gt 1 ]; then
        log_warn "Multi-platform build detected (${PLATFORM_COUNT} platforms)"
        log_warn "Image will be pushed to registry directly (--push)"
        log_warn "Cannot use --load for multi-platform builds"
        BUILD_CMD+=" --push"
    else
        log_info "Single platform build, loading to local Docker"
        BUILD_CMD+=" --load"
    fi
    
    BUILD_CMD+=" ."
    
    log_info "Executing: ${BUILD_CMD}"
    eval "${BUILD_CMD}"
    
else
    log_info "Using standard Docker build"
    
    # 构建参数
    BUILD_CMD="docker build"
    BUILD_CMD+=" -t ${FULL_IMAGE_NAME}:${IMAGE_TAG}"
    
    if [ "${PUSH_LATEST}" = "true" ]; then
        BUILD_CMD+=" -t ${FULL_IMAGE_NAME}:latest"
    fi
    
    if [ "${NO_CACHE}" = "true" ]; then
        BUILD_CMD+=" --no-cache"
    fi
    
    if [ -n "${BUILD_ARGS}" ]; then
        BUILD_CMD+=" ${BUILD_ARGS}"
    fi
    
    BUILD_CMD+=" ."
    
    log_info "Executing: ${BUILD_CMD}"
    eval "${BUILD_CMD}"
fi

log_info "✅ Image built successfully: ${FULL_IMAGE_NAME}:${IMAGE_TAG}"

# 显示镜像信息
log_info "Image details:"
docker images "${FULL_IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"

log_info ""
log_info "Next steps:"
log_info "  1. Test the image: docker run --rm ${FULL_IMAGE_NAME}:${IMAGE_TAG} --version"
if [ -n "${IMAGE_SUBPATH}" ]; then
    log_info "  2. Push to Harbor: ./push-image.sh ${IMAGE_NAME} ${IMAGE_TAG} ${IMAGE_SUBPATH}"
else
    log_info "  2. Push to Harbor: ./push-image.sh ${IMAGE_NAME} ${IMAGE_TAG}"
fi
