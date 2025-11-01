#!/usr/bin/env bash

# Helm Chart 推送脚本
# 用法: ./push-chart.sh <chart-name> [version]
# 示例: ./push-chart.sh apisix
#       ./push-chart.sh apisix 6.0.2

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
    log_error "Usage: $0 <chart-name> [version]"
    log_info "Example: $0 apisix"
    log_info "         $0 apisix 6.0.2"
    exit 1
fi

CHART_NAME="$1"
VERSION="${2:-}"

# 加载配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

if [ -f "$CONFIG_FILE" ]; then
    log_info "Loading configuration from ${CONFIG_FILE}"
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
else
    log_error "Configuration file not found: ${CONFIG_FILE}"
    log_info "Please create ${CONFIG_FILE} from config.env.example"
    exit 1
fi

# 检查必需的配置
if [ -z "${CHART_REPO_URL:-}" ]; then
    log_error "CHART_REPO_URL must be set in ${CONFIG_FILE}"
    exit 1
fi

# 默认配置
CHART_REPO_TYPE="${CHART_REPO_TYPE:-oci}"
CHART_REPO_USERNAME="${CHART_REPO_USERNAME:-}"
CHART_REPO_PASSWORD="${CHART_REPO_PASSWORD:-}"

# 如果没有指定版本，尝试从临时文件读取
if [ -z "${VERSION}" ]; then
    VERSION_FILE="${SCRIPT_DIR}/../../.${CHART_NAME}.version"
    if [ -f "${VERSION_FILE}" ]; then
        VERSION=$(cat "${VERSION_FILE}")
        log_info "Using version from ${VERSION_FILE}: ${VERSION}"
    else
        # 从 Chart.yaml 读取版本
        CHART_YAML="${SCRIPT_DIR}/../../charts/${CHART_NAME}/Chart.yaml"
        if [ -f "${CHART_YAML}" ]; then
            VERSION=$(grep '^version:' "${CHART_YAML}" | awk '{print $2}')
            log_info "Using version from Chart.yaml: ${VERSION}"
        else
            log_error "Cannot determine chart version"
            log_info "Please specify version: $0 ${CHART_NAME} <version>"
            exit 1
        fi
    fi
fi

# Chart 包文件
CHART_PACKAGE="${SCRIPT_DIR}/../../${CHART_NAME}-${VERSION}.tgz"

# 检查 Chart 包是否存在
if [ ! -f "${CHART_PACKAGE}" ]; then
    log_error "Chart package not found: ${CHART_PACKAGE}"
    log_info "Please package the chart first: ./package-chart.sh ${CHART_NAME}"
    exit 1
fi

log_info "Pushing chart to repository..."
log_info "  Chart: ${CHART_NAME}"
log_info "  Version: ${VERSION}"
log_info "  Package: ${CHART_PACKAGE}"
log_info "  Repository: ${CHART_REPO_URL}"
log_info "  Type: ${CHART_REPO_TYPE}"

# 根据仓库类型推送
case "${CHART_REPO_TYPE}" in
    oci|harbor-oci)
        log_info "Pushing to Harbor OCI Registry..."
        
        # Harbor OCI 使用 helm push 命令
        if [ -z "${CHART_REPO_USERNAME}" ] || [ -z "${CHART_REPO_PASSWORD}" ]; then
            log_error "CHART_REPO_USERNAME and CHART_REPO_PASSWORD must be set for Harbor"
            exit 1
        fi
        
        # 提取 Harbor 地址和项目
        # URL 格式: oci://harbor.example.com/library
        HARBOR_HOST=$(echo "${CHART_REPO_URL}" | sed 's|oci://||' | cut -d/ -f1)
        
        log_info "  Harbor Host: ${HARBOR_HOST}"
        log_info "  Repository: ${CHART_REPO_URL}"
        
        # 登录 Harbor OCI Registry
        log_info "Logging in to Harbor OCI Registry..."
        echo "${CHART_REPO_PASSWORD}" | helm registry login "${HARBOR_HOST}" \
            -u "${CHART_REPO_USERNAME}" \
            --password-stdin
        
        # 推送 Chart
        log_info "Pushing chart to OCI registry..."
        helm push "${CHART_PACKAGE}" "${CHART_REPO_URL}"
        
        if [ $? -eq 0 ]; then
            log_info "✅ Chart pushed successfully to Harbor OCI"
        else
            log_error "Failed to push chart to OCI registry"
            exit 1
        fi
        ;;
    
    *)
        log_error "Unsupported repository type: ${CHART_REPO_TYPE}"
        log_info "This script now only supports OCI registries (set CHART_REPO_TYPE=oci)"
        exit 1
        ;;
esac

log_info ""
log_info "✅ Chart pushed successfully!"
log_info ""
log_info "Verify in repository:"

case "${CHART_REPO_TYPE}" in
    oci|harbor-oci)
        HARBOR_HOST=$(echo "${CHART_REPO_URL}" | sed 's|oci://||' | cut -d/ -f1)
        PROJECT=$(echo "${CHART_REPO_URL}" | sed 's|oci://||' | cut -d/ -f2-)
        log_info "  Web UI: https://${HARBOR_HOST}/harbor/projects/${PROJECT}/repositories/${CHART_NAME}"
        log_info "  OCI URL: ${CHART_REPO_URL}/${CHART_NAME}:${VERSION}"
        ;;
esac

log_info ""
log_info "Install chart:"
log_info "  helm registry login ${HARBOR_HOST} -u <user>"
log_info "  helm install my-${CHART_NAME} ${CHART_REPO_URL}/${CHART_NAME} --version ${VERSION}"

# 清理临时版本文件
VERSION_FILE="${SCRIPT_DIR}/../../.${CHART_NAME}.version"
if [ -f "${VERSION_FILE}" ]; then
    rm -f "${VERSION_FILE}"
fi
