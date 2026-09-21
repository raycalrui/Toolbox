# Toolbox

一款面向 macOS 的原生工具箱 App，计划整合创作、文本、网络、隐私和系统辅助工具。

## 当前状态

项目处于首个 MVP 的范围确认阶段。已经建立本地 Git 仓库和最小 macOS SwiftUI Xcode 工程，但尚未实现任何工具功能。

首个 MVP 已确定为视频格式转换工具。下一步需要确定第一版的格式范围、编码后端、任务模式、预设内容和验收标准。

## 本地开发

- Xcode 工程：`Toolbox.xcodeproj`
- App Target：`Toolbox`
- Bundle ID：`com.raycal.Toolbox`（暂定）
- 最低系统版本：macOS 15.0
- Swift：6.0

用 Xcode 打开 `Toolbox.xcodeproj` 后即可构建运行。当前界面只是等待选择首个工具的占位页。

## 产品方向

- macOS 原生体验
- 本地优先和隐私优先
- 工具模块化，可收藏常用工具
- 后续可逐步接入菜单栏、全局快捷方式、Finder 和系统服务
- 联网功能明确标识，并安全保存凭据

## 当前优先功能

- 视频格式转换
- 自定义分辨率、帧率、码率和编码器
- 保存和管理导出预设

以上能力正在确认 MVP 范围，尚未开始实现。

## 其他候选能力

- 文本差异对比
- UUID 与随机字符串生成
- 公网及局域网 IP 查看
- Ping 测试
- IPv4 / IPv6 信息解析
- 剪贴板历史
- 密码生成与密码强度检查
- 防止 Mac 睡眠
- 收藏常用工具
- Finder 右键扩展
- Cloudflare IPv4 / IPv6 DDNS

以上均为候选需求，不代表已经实现。实际状态以 [`TODO.md`](TODO.md) 为准。

## 项目文档

- [`AGENTS.md`](AGENTS.md)：协作、开发和文档维护规则
- [`TODO.md`](TODO.md)：需求池、优先级和实施状态
- [`DECISIONS.md`](DECISIONS.md)：长期产品与技术决策
- [`CHANGELOG.md`](CHANGELOG.md)：已交付功能和版本变化

## 文档维护

项目文档由后续执行任务的 Agent 随项目同步维护：需求变化更新 `TODO.md`，长期决策更新 `DECISIONS.md`，完成的用户可感知变化更新 `README.md` 和 `CHANGELOG.md`。任何规划中的能力都不得写成已完成功能。
