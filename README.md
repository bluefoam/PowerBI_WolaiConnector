# Wolai Connector for Power BI
<img width="74" height="34" alt="image" src="https://github.com/user-attachments/assets/fa594040-3169-4a31-9ace-e4a6722879ae" />


这个自定义连接器允许 Power BI 直接连接到 Wolai 数据库并导入数据。

**版本**: 1.1.1
**更新日期**: 2026-01-17

## ✨ 主要功能

*   **全量数据导入**: 支持获取 Wolai 数据库的所有记录。
*   **自动分页**: 针对大型表格（超过 200 行）实现了自动游标分页 (`start_cursor`)，解决 502 网关超时问题。
*   **丰富的字段支持**: 支持文本、数字、日期、人员、关联、公式等多种 Wolai 属性类型。

## 🛠️ 安装步骤

1.  **构建连接器** (如果您是开发者):
    *   运行根目录下的 `build.ps1` 脚本。
    *   生成的 `.mez` 文件位于 `bin\Debug\WolaiConnector.mez`。

2.  **安装连接器**:
    *   将 `WolaiConnector.mez` 文件复制到您的 Power BI 自定义连接器目录：
        *   `[文档]\Power BI Desktop\Custom Connectors`
    *   如果目录不存在，请手动创建。

3.  **配置 Power BI**:
    *   打开 Power BI Desktop。
    *   转到 **文件** > **选项和设置** > **选项**。
    *   在 **安全性** > **数据扩展** 下，选择 **"（不推荐）允许任何扩展加载而不进行验证或警告"**。
    *   **重启** Power BI Desktop。

## 🚀 使用方法

1.  **准备凭据**:
    *   在 Wolai 开发者中心创建应用，获取 `App ID` 和 `App Secret`。
    *   获取目标数据库的 `Database ID`（从数据库页面 URL 中获取）。

2.  **连接数据**:
    *   在 Power BI 中点击 **"获取数据"**。
    *   搜索 **"Wolai"** 并选择。
    *   输入 **Database ID**。

3.  **身份验证**:
    *   在弹出的凭据窗口中，选择 **"密钥" (Key)** 方式。
    *   在密钥框中输入格式为 `AppID|AppSecret` 的字符串。
        *   例如: `your_app_id|your_app_secret`
        *   注意中间使用竖线 `|` 分隔。

## 📂 项目结构

*   `WolaiConnector.pq`: 核心连接器代码 (M 语言)。
*   `build.ps1`: 自动化构建脚本 (PowerShell)。
*   `icons/`: 连接器图标资源。
*   `resources.resx`: 本地化字符串资源。

## ⚠️ 常见问题

**Q: 导入大表时报错或卡住？**
A: 版本 1.1.1 已经优化了分页逻辑。如果仍然遇到问题，请检查网络连接，或尝试在非高峰时段进行刷新。

## 🔒 隐私说明

此连接器直接通过 HTTPS 请求 Wolai API，数据仅在您的本地 Power BI Desktop 和 Wolai 服务器之间传输，不会经过任何第三方服务器。
