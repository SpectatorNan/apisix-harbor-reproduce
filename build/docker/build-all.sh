#!/bin/bash

# 批量构建示例脚本
# 演示如何使用新的参数格式批量构建多个镜像

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "======================================"
echo "🏗️ 批量构建 Docker 镜像"
echo "======================================"
echo ""

# 定义要构建的镜像列表
# 格式: "name:version:path"
# - name: 镜像名称
# - version: 镜像版本/标签
# - path: 子路径（可选，留空表示简单结构）
IMAGES=(
    # etcd 不同版本
    "etcd:3.6.5:3.6/debian-12"
    "etcd:3.5.18:3.5/debian-12"
    
    # os-shell
    "os-shell:12-debian-12-r50:12/debian-12"
    
    # 简单结构示例（假设存在）
    # "nginx:1.25.0:"
    # "redis:7.2.0:"
)

# 配置选项
DRY_RUN="${DRY_RUN:-false}"        # 是否仅显示命令不执行
PUSH_IMAGES="${PUSH_IMAGES:-true}"  # 是否推送到 Harbor
PARALLEL="${PARALLEL:-false}"       # 是否并行构建（不推荐）

echo "配置:"
echo "  DRY_RUN: ${DRY_RUN}"
echo "  PUSH_IMAGES: ${PUSH_IMAGES}"
echo "  PARALLEL: ${PARALLEL}"
echo ""

# 统计
TOTAL=${#IMAGES[@]}
SUCCESS=0
FAILED=0

echo "准备构建 ${TOTAL} 个镜像..."
echo ""

# 构建函数
build_image() {
    local IMAGE_INFO="$1"
    local INDEX="$2"
    
    # 解析镜像信息
    IFS=':' read -r NAME VERSION PATH <<< "${IMAGE_INFO}"
    
    echo "[$((INDEX + 1))/${TOTAL}] 处理: ${NAME} ${VERSION}"
    
    if [ -n "${PATH}" ]; then
        echo "  类型: Bitnami 结构"
        echo "  路径: ${PATH}"
    else
        echo "  类型: 简单结构"
    fi
    
    # 构建镜像
    if [ "${DRY_RUN}" = "true" ]; then
        echo "  [DRY RUN] 将执行:"
        if [ -n "${PATH}" ]; then
            echo "    ./build-image.sh ${NAME} ${VERSION} ${PATH}"
        else
            echo "    ./build-image.sh ${NAME} ${VERSION}"
        fi
    else
        echo "  🔨 开始构建..."
        if [ -n "${PATH}" ]; then
            if ./build-image.sh "${NAME}" "${VERSION}" "${PATH}"; then
                echo "  ✅ 构建成功"
                ((SUCCESS++))
            else
                echo "  ❌ 构建失败"
                ((FAILED++))
                return 1
            fi
        else
            if ./build-image.sh "${NAME}" "${VERSION}"; then
                echo "  ✅ 构建成功"
                ((SUCCESS++))
            else
                echo "  ❌ 构建失败"
                ((FAILED++))
                return 1
            fi
        fi
    fi
    
    # 推送镜像
    if [ "${PUSH_IMAGES}" = "true" ] && [ "${DRY_RUN}" != "true" ]; then
        echo "  📤 推送到 Harbor..."
        if [ -n "${PATH}" ]; then
            if ./push-image.sh "${NAME}" "${VERSION}" "${PATH}"; then
                echo "  ✅ 推送成功"
            else
                echo "  ❌ 推送失败"
                return 1
            fi
        else
            if ./push-image.sh "${NAME}" "${VERSION}"; then
                echo "  ✅ 推送成功"
            else
                echo "  ❌ 推送失败"
                return 1
            fi
        fi
    elif [ "${DRY_RUN}" = "true" ] && [ "${PUSH_IMAGES}" = "true" ]; then
        echo "  [DRY RUN] 将推送:"
        if [ -n "${PATH}" ]; then
            echo "    ./push-image.sh ${NAME} ${VERSION} ${PATH}"
        else
            echo "    ./push-image.sh ${NAME} ${VERSION}"
        fi
    fi
    
    echo ""
}

# 执行构建
if [ "${PARALLEL}" = "true" ]; then
    echo "⚠️  并行模式（实验性）"
    echo ""
    
    INDEX=0
    for IMAGE_INFO in "${IMAGES[@]}"; do
        build_image "${IMAGE_INFO}" "${INDEX}" &
        ((INDEX++))
    done
    
    # 等待所有任务完成
    wait
else
    INDEX=0
    for IMAGE_INFO in "${IMAGES[@]}"; do
        build_image "${IMAGE_INFO}" "${INDEX}" || true
        ((INDEX++))
    done
fi

# 显示结果
echo "======================================"
echo "📊 构建完成"
echo "======================================"
echo "总计: ${TOTAL}"
echo "成功: ${SUCCESS}"
echo "失败: ${FAILED}"
echo ""

if [ ${FAILED} -gt 0 ]; then
    echo "⚠️  有 ${FAILED} 个镜像构建失败"
    exit 1
else
    echo "✅ 所有镜像构建成功！"
    exit 0
fi
