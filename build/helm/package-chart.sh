#!/usr/bin/env bash

# Helm Chart 打包脚本
# 用法: ./package-chart.sh <chart-name>
# 示例: ./package-chart.sh apisix

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
if [ $# -lt 1 ]; then
    log_error "Usage: $0 <chart-name>"
    log_info "Example: $0 apisix"
    exit 1
fi

CHART_NAME="$1"

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
UPDATE_DEPENDENCIES="${UPDATE_DEPENDENCIES:-true}"
AUTO_INCREMENT_VERSION="${AUTO_INCREMENT_VERSION:-false}"
OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/../..}"
SIGN_CHART="${SIGN_CHART:-false}"
LINT_CHART="${LINT_CHART:-true}"

# Chart 目录
CHART_DIR="${SCRIPT_DIR}/../../charts/${CHART_NAME}"

# 检查 Chart 目录是否存在
if [ ! -d "${CHART_DIR}" ]; then
    log_error "Chart directory not found: ${CHART_DIR}"
    exit 1
fi

# 检查 Chart.yaml 是否存在
if [ ! -f "${CHART_DIR}/Chart.yaml" ]; then
    log_error "Chart.yaml not found in: ${CHART_DIR}"
    exit 1
fi

# 检查 Helm 是否安装
if ! command -v helm &> /dev/null; then
    log_error "Helm is not installed. Please install Helm first."
    log_info "Visit: https://helm.sh/docs/intro/install/"
    exit 1
fi

log_info "Packaging Helm Chart..."
log_info "  Chart: ${CHART_NAME}"
log_info "  Directory: ${CHART_DIR}"

# 进入 Chart 目录
cd "${CHART_DIR}"

# 读取当前版本
CURRENT_VERSION=$(grep '^version:' Chart.yaml | awk '{print $2}')
log_info "  Current version: ${CURRENT_VERSION}"

# 自动递增版本（如果启用）
if [ "${AUTO_INCREMENT_VERSION}" = "true" ]; then
    log_info "Auto-incrementing patch version..."
    
    # 分解版本号
    MAJOR=$(echo "${CURRENT_VERSION}" | cut -d. -f1)
    MINOR=$(echo "${CURRENT_VERSION}" | cut -d. -f2)
    PATCH=$(echo "${CURRENT_VERSION}" | cut -d. -f3)
    
    # 递增 patch 版本
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
    
    log_info "  New version: ${NEW_VERSION}"
    
    # 更新 Chart.yaml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^version: .*/version: ${NEW_VERSION}/" Chart.yaml
    else
        # Linux
        sed -i "s/^version: .*/version: ${NEW_VERSION}/" Chart.yaml
    fi
    
    VERSION="${NEW_VERSION}"
else
    VERSION="${CURRENT_VERSION}"
fi

# 更新依赖
if [ "${UPDATE_DEPENDENCIES}" = "true" ]; then
    log_info "Updating chart dependencies..."
    helm dependency update
    
    if [ $? -eq 0 ]; then
        log_info "✅ Dependencies updated successfully"
    else
        log_error "Failed to update dependencies"
        exit 1
    fi
fi

# Lint Chart
if [ "${LINT_CHART}" = "true" ]; then
    log_info "Linting chart..."
    helm lint .
    
    if [ $? -eq 0 ]; then
        log_info "✅ Chart lint passed"
    else
        log_warn "⚠️  Chart lint found issues (continuing anyway)"
    fi
fi

# 打包 Chart
log_info "Packaging chart..."
cd "${SCRIPT_DIR}/../.."

PACKAGE_CMD="helm package"
PACKAGE_CMD+=" charts/${CHART_NAME}"
PACKAGE_CMD+=" --destination ."

if [ "${SIGN_CHART}" = "true" ]; then
    if [ -n "${SIGN_KEY:-}" ] && [ -n "${SIGN_KEYRING:-}" ]; then
        log_info "Signing chart with key: ${SIGN_KEY}"
        PACKAGE_CMD+=" --sign"
        PACKAGE_CMD+=" --key ${SIGN_KEY}"
        PACKAGE_CMD+=" --keyring ${SIGN_KEYRING}"
    else
        log_warn "SIGN_KEY or SIGN_KEYRING not set, skipping signing"
    fi
fi

log_info "Executing: ${PACKAGE_CMD}"
eval "${PACKAGE_CMD}"

if [ $? -eq 0 ]; then
    CHART_PACKAGE="${CHART_NAME}-${VERSION}.tgz"
    log_info "✅ Chart packaged successfully: ${CHART_PACKAGE}"
    
    # 显示包信息
    log_info ""
    log_info "Package details:"
    ls -lh "${CHART_PACKAGE}"
    
    log_info ""
    log_info "Package content:"
    tar -tzf "${CHART_PACKAGE}" | head -20
    
    if [ "$(tar -tzf "${CHART_PACKAGE}" | wc -l)" -gt 20 ]; then
        log_info "... (truncated)"
    fi
    
    log_info ""
    log_info "Next steps:"
    log_info "  1. Test locally: helm install test-${CHART_NAME} ./${CHART_PACKAGE} --dry-run --debug"
    log_info "  2. Push to Harbor: ./push-chart.sh ${CHART_NAME}"
    
    # 保存版本号到文件（用于 push-chart.sh）
    echo "${VERSION}" > ".${CHART_NAME}.version"
else
    log_error "Failed to package chart"
    exit 1
fi
