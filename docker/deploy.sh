#!/bin/bash

# deploy_and_init.sh - 自动化部署和初始化脚本

set -e  # 遇到错误时退出

echo "🚀 开始部署和初始化流程..."

# 1. 创建volume目录和mcp_settings.json文件
echo "📁 创建volume目录和配置文件..."
mkdir -p ./volume/mcp-data
touch ./volume/mcp-data/mcp_settings.json

# 2. 启动所有服务
echo "🐳 启动Docker服务..."
docker-compose up -d

# 3. 安装Python依赖
echo "🐍 安装Python依赖..."
pip install pymysql py2neo

# 4. 循环检查mysql和neo4j-apoc容器是否启动成功
echo "🔍 检查服务启动状态..."

# 检查容器是否运行
wait_for_container() {
    local container_name=$1
    local max_attempts=30
    local attempt=1

    echo "⏳ 等待 $container_name 启动..."

    while [ $attempt -le $max_attempts ]; do
        if [ "$(docker inspect -f {{.State.Running}} $container_name 2>/dev/null)" = "true" ]; then
            echo "✅ $container_name 已成功启动"
            return 0
        fi
        echo "⏳ $container_name 尚未启动，第 $attempt/$max_attempts 次尝试..."
        attempt=$((attempt + 1))
        sleep 10
    done

    echo "❌ $container_name 启动超时"
    return 1
}

# 检查MySQL服务是否真正可用
check_mysql_ready() {
    local max_attempts=30
    local attempt=1

    echo "⏳ 等待 MySQL 服务准备就绪..."

    while [ $attempt -le $max_attempts ]; do
        if docker exec chat-db mysqladmin ping --silent >/dev/null 2>&1; then
            echo "✅ MySQL 服务已准备就绪"
            return 0
        fi
        echo "⏳ MySQL 尚未准备就绪，第 $attempt/$max_attempts 次尝试..."
        attempt=$((attempt + 1))
        sleep 5
    done

    echo "❌ MySQL 服务准备超时"
    return 1
}

# 检查指定端口是否可用
check_port_available() {
    local service_name=$1
    local port=$2
    local max_attempts=30
    local attempt=1

    echo "⏳ 检查 $service_name 端口 $port 是否可用..."

    while [ $attempt -le $max_attempts ]; do
        if nc -z localhost $port; then
            echo "✅ $service_name 端口 $port 已开放"
            return 0
        fi
        echo "⏳ $service_name 端口 $port 尚未开放，第 $attempt/$max_attempts 次尝试..."
        attempt=$((attempt + 1))
        sleep 5
    done

    echo "❌ $service_name 端口 $port 检查超时"
    return 1
}

# 等待MySQL和Neo4j服务启动，并检查MySQL是否真正可用以及端口是否开放
wait_for_container "chat-db" && \
wait_for_container "neo4j-apoc" && \
check_mysql_ready && \
check_port_available "MySQL" 13006 && \
check_port_available "Neo4j" 7687

# 5. 执行数据初始化脚本
if [ $? -eq 0 ]; then
    echo "📊 等待服务稳定 (30秒)..."
    sleep 30  # 等待30秒以确保服务完全就绪

    echo "📊 执行数据初始化..."
    if [ -f "./init_data.sh" ]; then
        # 添加重试机制
        max_attempts=3
        attempt=1

        while [ $attempt -le $max_attempts ]; do
            if bash ./init_data.sh; then
                echo "🎉 部署和初始化完成！"
                break
            else
                if [ $attempt -eq $max_attempts ]; then
                    echo "❌ 初始化失败，已重试 $max_attempts 次"
                    exit 1
                else
                    echo "⚠️  初始化失败，第 $attempt 次重试..."
                    attempt=$((attempt + 1))
                    sleep 10
                fi
            fi
        done
    else
        echo "⚠️  初始化脚本 init_data.sh 不存在"
    fi
else
    echo "❌ 服务启动失败，无法执行数据初始化"
    exit 1
fi