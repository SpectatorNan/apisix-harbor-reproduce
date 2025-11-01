#!/usr/bin/env bash

# Docker 镜像推送脚本（增强版）
# 用法: ./push-image.sh <name> <version> [path]
# 功能: 推送镜像后自动同步更新相关 Chart 的镜像配置
#
# 示例: 
#   ./push-image.sh etcd 3.5.18
#   ./push-image.sh etcd 3.6.5 3.6/debian-12
#   ./push-image.sh os-shell 12-debian-12-r50 12/debian-12

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
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
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
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
if [ -z "${HARBOR_URL:-}" ] || [ -z "${HARBOR_PROJECT:-}" ]; then
    log_error "HARBOR_URL and HARBOR_PROJECT must be set in ${CONFIG_FILE}"
    exit 1
fi

# 默认配置
PUSH_LATEST="${PUSH_LATEST:-false}"
HARBOR_USERNAME="${HARBOR_USERNAME:-}"
HARBOR_PASSWORD="${HARBOR_PASSWORD:-}"
AUTO_UPDATE_CHARTS="${AUTO_UPDATE_CHARTS:-true}"  # 新增：是否自动更新 Chart 配置

# 构建完整镜像名
FULL_IMAGE_NAME="${HARBOR_URL}/${HARBOR_PROJECT}/${IMAGE_NAME}"

# 检查镜像是否存在
if ! docker images "${FULL_IMAGE_NAME}:${IMAGE_TAG}" --format '{{.Repository}}' | grep -q "${FULL_IMAGE_NAME}"; then
    log_error "Image not found: ${FULL_IMAGE_NAME}:${IMAGE_TAG}"
    if [ -n "${IMAGE_SUBPATH}" ]; then
        log_info "Please build the image first: ./build-image.sh ${IMAGE_NAME} ${IMAGE_TAG} ${IMAGE_SUBPATH}"
    else
        log_info "Please build the image first: ./build-image.sh ${IMAGE_NAME} ${IMAGE_TAG}"
    fi
    exit 1
fi

# 登录 Harbor
if [ -n "${HARBOR_USERNAME}" ] && [ -n "${HARBOR_PASSWORD}" ]; then
    log_info "Logging in to Harbor: ${HARBOR_URL}"
    echo "${HARBOR_PASSWORD}" | docker login "${HARBOR_URL}" -u "${HARBOR_USERNAME}" --password-stdin
else
    log_warn "HARBOR_USERNAME or HARBOR_PASSWORD not set"
    log_warn "Assuming already logged in to Harbor"
fi

# 推送镜像
log_info "Pushing image to Harbor..."
log_info "  Image name:    ${IMAGE_NAME}"
log_info "  Image version: ${IMAGE_TAG}"
if [ -n "${IMAGE_SUBPATH}" ]; then
    log_info "  Image path:    ${IMAGE_SUBPATH}"
fi
log_info "  Full image:    ${FULL_IMAGE_NAME}:${IMAGE_TAG}"

docker push "${FULL_IMAGE_NAME}:${IMAGE_TAG}"

if [ "${PUSH_LATEST}" = "true" ]; then
    log_info "Pushing latest tag..."
    
    # 检查 latest 标签是否存在
    if docker images "${FULL_IMAGE_NAME}:latest" --format '{{.Repository}}' | grep -q "${FULL_IMAGE_NAME}"; then
        docker push "${FULL_IMAGE_NAME}:latest"
    else
        log_warn "Latest tag not found, tagging and pushing..."
        docker tag "${FULL_IMAGE_NAME}:${IMAGE_TAG}" "${FULL_IMAGE_NAME}:latest"
        docker push "${FULL_IMAGE_NAME}:latest"
    fi
fi

log_info "✅ Image pushed successfully!"

# ==========================================
# 新增功能：自动更新 Chart 配置
# ==========================================

update_chart_image_config() {
    local chart_dir="$1"
    local chart_name=$(basename "$chart_dir")
    local values_file="${chart_dir}/values.yaml"
    local chart_yaml="${chart_dir}/Chart.yaml"
    local updated=false
    
    if [ ! -f "$values_file" ]; then
        log_debug "Skipping ${chart_name}: values.yaml not found"
        return
    fi
    
    log_info ""
    log_info "🔍 Checking Chart: ${chart_name}"
    
    # 检查 yq 工具
    if ! command -v yq &> /dev/null; then
        log_warn "yq not found, skipping automatic Chart updates"
        log_info "Install yq: brew install yq"
        return
    fi
    
    # 智能搜索：递归查找所有使用目标镜像的配置路径
    log_debug "  Searching for image '${IMAGE_NAME}' in values.yaml..."
    
    # 使用 yq 查找所有包含 repository 字段的对象路径
    # 过滤出 repository 值匹配目标镜像名的路径
    # 支持多种格式：
    #   - os-shell
    #   - bitnami/os-shell
    #   - docker.io/bitnami/os-shell
    #   - myregistry.com/myproject/os-shell
    #   - os-shell:v1.0.0 (带标签)
    local image_paths=$(yq eval '
        .. | 
        select(type == "!!map") | 
        select(has("repository")) | 
        select(.repository | test("(^|/)'"${IMAGE_NAME}"'(:|$)")) | 
        path | 
        join(".")
    ' "$values_file" 2>/dev/null)
    
    if [ -z "$image_paths" ]; then
        log_debug "  No matching image configuration found in ${chart_name}"
        return
    fi
    
    # 处理每个匹配的路径
    while IFS= read -r path; do
        if [ -n "$path" ]; then
            # 获取当前配置的完整路径（去掉末尾可能的 .image）
            local base_path="${path}"
            
            # 获取当前的 repository 值
            local current_repo=$(yq eval ".${base_path}.repository" "$values_file" 2>/dev/null)
            
            log_info "  Found image at: ${base_path}"
            log_debug "    Current repository: ${current_repo}"
            
            # 检查是否有独立的 registry 和 tag 字段
            local has_registry=$(yq eval ".${base_path} | has(\"registry\")" "$values_file" 2>/dev/null)
            local has_tag=$(yq eval ".${base_path} | has(\"tag\")" "$values_file" 2>/dev/null)
            
            if [ "$has_registry" = "true" ] && [ "$has_tag" = "true" ]; then
                # 分离的 registry/repository/tag 配置
                log_info "    Updating registry and tag..."
                yq eval ".${base_path}.registry = \"${HARBOR_URL}\"" -i "$values_file"
                yq eval ".${base_path}.tag = \"${IMAGE_TAG}\"" -i "$values_file"
                updated=true
            elif [[ "$current_repo" == *":"* ]]; then
                # repository 包含完整镜像地址 (registry/repo:tag 格式)
                log_info "    Updating full image reference..."
                local new_image="${HARBOR_URL}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"
                yq eval ".${base_path}.repository = \"${new_image}\"" -i "$values_file"
                updated=true
            else
                # 只有 repository，可能需要拆分 registry
                log_warn "    Unsupported image configuration format, skipping"
            fi
        fi
    done <<< "$image_paths"
    
    # 更新 Chart.yaml 的 annotations.images
    if [ -f "$chart_yaml" ] && [ "$updated" = true ]; then
        log_info "  Updating Chart.yaml annotations.images"
        
        # 读取现有的 annotations.images
        local images_annotation=$(yq eval '.annotations.images' "$chart_yaml" 2>/dev/null)
        
        if [ "$images_annotation" != "null" ]; then
            # 更新对应的镜像行
            # 这里简化处理，直接用 sed 修改文件
            sed -i.bak "s|image: [^/]*/[^/]*/${IMAGE_NAME}:.*|image: ${HARBOR_URL}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}|g" "$chart_yaml"
            rm -f "${chart_yaml}.bak"
        fi
    fi
    
    if [ "$updated" = true ]; then
        log_info "  ✅ Updated ${chart_name} Chart configuration"
    else
        log_debug "  No updates applied to ${chart_name}"
    fi
}

# 自动更新 Chart 配置
if [ "${AUTO_UPDATE_CHARTS}" = "true" ]; then
    log_info ""
    log_info "================================================"
    log_info "🔄 Auto-updating Chart configurations..."
    log_info "================================================"
    
    CHARTS_DIR="${PROJECT_ROOT}/charts"
    
    if [ -d "$CHARTS_DIR" ]; then
        # 遍历所有 Chart 目录
        for chart_dir in "$CHARTS_DIR"/*; do
            if [ -d "$chart_dir" ] && [ -f "${chart_dir}/Chart.yaml" ]; then
                update_chart_image_config "$chart_dir"
            fi
        done
        
        log_info ""
        log_info "✅ Chart configuration update completed"
        log_info ""
        log_info "📝 Next steps:"
        log_info "  1. Review the changes: git diff charts/"
        log_info "  2. Test the Chart: helm template <chart-name> ./charts/<chart-name>"
        log_info "  3. Commit changes: git add charts/ && git commit -m 'chore: update ${IMAGE_NAME} to ${IMAGE_TAG}'"
    else
        log_warn "Charts directory not found: ${CHARTS_DIR}"
    fi
else
    log_info ""
    log_info "Auto-update Charts is disabled (AUTO_UPDATE_CHARTS=false)"
fi

# 显示推送的镜像
log_info ""
log_info "================================================"
log_info "📦 Pushed images:"
log_info "================================================"
log_info "  - ${FULL_IMAGE_NAME}:${IMAGE_TAG}"
if [ "${PUSH_LATEST}" = "true" ]; then
    log_info "  - ${FULL_IMAGE_NAME}:latest"
fi

log_info ""
log_info "🌐 Verify in Harbor:"
log_info "  https://${HARBOR_URL}/harbor/projects/${HARBOR_PROJECT}/repositories/${IMAGE_NAME}"

log_info ""
log_info "🎉 All done!"
