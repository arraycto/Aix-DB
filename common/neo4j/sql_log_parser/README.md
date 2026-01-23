# SQL 日志解析器

> 从 MySQL 执行日志中自动提取表关系，构建 Neo4j 知识图谱

---

## 目录

- [功能概述](#功能概述)
- [目录结构](#目录结构)
- [工作流程](#工作流程)
- [支持的数据源](#支持的数据源)
- [快速开始](#快速开始)
- [使用示例](#使用示例)
- [输出文件](#输出文件)
- [注意事项](#注意事项)

---

## 功能概述

SQL 日志解析器用于从 MySQL 执行日志中自动提取表关系，并写入 Neo4j 图数据库。

**适用场景：**
- 无法直接访问业务代码
- 需要自动化构建数据库表关系图谱
- 数据血缘分析

---

## 目录结构

```
common/neo4j/sql_log_parser/
├── __init__.py                     # 模块初始化
├── sql_log_reader.py               # SQL 日志读取器
├── binlog_reader.py                # Binlog 实时读取器 ⭐推荐
├── sql_relationship_extractor.py   # SQL 关系提取器
├── sql_log_to_neo4j.py            # 主流程脚本
└── README.md                       # 使用说明
```

### 核心模块

| 模块 | 功能 | 主要类 |
|------|------|--------|
| `sql_log_reader.py` | 从日志文件读取 SQL | `SQLLogReader` |
| `binlog_reader.py` | 实时读取 MySQL Binlog | `BinlogReader` |
| `sql_relationship_extractor.py` | 从 SQL 语句提取表关系 | `SQLRelationshipExtractor` |
| `sql_log_to_neo4j.py` | 完整流程编排 | `SQLLogToNeo4jPipeline` |

---

## 工作流程

```
┌──────────────────────────────────────────────────────────────────┐
│                         数据源输入                                │
├──────────────────────────────────────────────────────────────────┤
│  sql_log_reader.py  ──→  从日志文件读取 SQL                       │
│  binlog_reader.py   ──→  实时读取 Binlog（推荐）                  │
└─────────────────────────────┬────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                      SQL 解析与关系提取                           │
├──────────────────────────────────────────────────────────────────┤
│  sql_relationship_extractor.py  ──→  解析 SQL，提取表关系         │
└─────────────────────────────┬────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                         数据输出                                  │
├──────────────────────────────────────────────────────────────────┤
│  sql_log_to_neo4j.py  ──→  写入 Neo4j / 导出 JSON                │
└──────────────────────────────────────────────────────────────────┘
```

---

## 支持的数据源

| 优先级 | 数据源 | 说明 |
|:------:|--------|------|
| ⭐ | **MySQL Binlog** | 实时读取，推荐使用 |
| 2 | General Log 文件 | 需开启 `general_log` |
| 3 | Slow Query Log 文件 | 需开启 `slow_query_log` |
| 4 | 自定义 SQL 日志文件 | 支持任意格式 |
| 5 | `performance_schema` | 从系统表读取 |

---

## 快速开始

### 1. 安装依赖

```bash
# 基础依赖
pip install pymysql py2neo

# Binlog 实时读取（推荐）
pip install pymysql-replication
```

### 2. 配置 MySQL

#### 方式一：启用 Binlog（推荐）

```sql
-- 检查 binlog 是否启用
SHOW VARIABLES LIKE 'log_bin';
```

如未启用，在 `my.cnf` 中添加：

```ini
[mysqld]
log-bin=mysql-bin
binlog-format=ROW
server-id=1
```

#### 方式二：启用 General Log

```sql
SET GLOBAL general_log = 'ON';
SET GLOBAL general_log_file = '/var/log/mysql/general.log';
```

#### 方式三：启用 Slow Query Log

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL slow_query_log_file = '/var/log/mysql/slow.log';
SET GLOBAL long_query_time = 0;  -- 记录所有查询
```

### 3. 运行

```bash
python sql_log_to_neo4j.py
```

按照提示选择数据源并输入相应路径即可。

---

## 使用示例

### 从 Binlog 实时读取（推荐）

```python
from sql_log_to_neo4j import SQLLogToNeo4jPipeline

pipeline = SQLLogToNeo4jPipeline()

pipeline.run_from_binlog_realtime(
    log_file=None,              # 从当前位置开始
    log_pos=None,               # 从当前位置开始
    stop_after_seconds=3600,    # 读取 1 小时后停止（None 则持续读取）
    clear_existing=False,       # 是否清除已有数据
    export_json=True,           # 是否导出 JSON
    incremental_update=True     # 实时增量更新到 Neo4j
)
```

### 从 General Log 提取

```python
from sql_log_to_neo4j import SQLLogToNeo4jPipeline

pipeline = SQLLogToNeo4jPipeline()

pipeline.run_from_general_log(
    log_file_path="/var/log/mysql/general.log",
    clear_existing=False,
    export_json=True
)
```

### 从 performance_schema 提取

```python
from sql_log_to_neo4j import SQLLogToNeo4jPipeline

pipeline = SQLLogToNeo4jPipeline()

pipeline.run_from_performance_schema(
    limit=1000,
    clear_existing=False
)
```

---

## 输出文件

| 文件 | 说明 |
|------|------|
| `sql_log_relationships.json` | 提取的表关系 JSON 文件 |

---

## 注意事项

| 项目 | 说明 |
|------|------|
| Neo4j 服务 | 确保 Neo4j 服务已启动并可访问 |
| 文件权限 | 确保有读取 MySQL 日志文件的权限 |
| 性能考虑 | 大量 SQL 语句处理可能需要较长时间 |
| 测试建议 | 建议先在小规模数据上测试验证 |
