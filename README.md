# Toolbox

一款面向 macOS 的原生工具箱 App，计划整合创作、文本、网络、隐私和系统辅助工具。

App 用户界面从英文版开始开发；项目协作文档继续使用中文。

## 当前状态

首个本地 MVP 已完成：视频转换工具可以读取视频信息、批量排队，并按自定义参数通过 FFmpeg 和 VideoToolbox 导出。

当前版本仅用于本地开发验证，依赖本机 Homebrew FFmpeg；尚未配置正式签名、App Sandbox、FFmpeg 内嵌分发或 GitHub 开源。

## 本地开发

- Xcode 工程：`Toolbox.xcodeproj`
- App Target：`Toolbox`
- Bundle ID：`com.raycal.Toolbox`（暂定）
- 最低系统版本：macOS 15.0
- Swift：6.0

用 Xcode 打开 `Toolbox.xcodeproj` 后即可构建运行，左侧选择 “Video Converter” 进入当前工具。

视频转换 MVP 需要本机安装 FFmpeg：

```bash
brew install ffmpeg
```

App 会优先寻找 App 内嵌的 `ffmpeg`，本地开发阶段也会寻找 `/opt/homebrew/bin/ffmpeg` 和 `/usr/local/bin/ffmpeg`。

## 产品方向

- macOS 原生体验
- 本地优先和隐私优先
- 工具模块化，可收藏常用工具
- 后续可逐步接入菜单栏、全局快捷方式、Finder 和系统服务
- 联网功能明确标识，并安全保存凭据

## 当前优先功能

- 批量添加、拖放和顺序转换视频
- 读取分辨率、帧率、时长、编码和文件大小
- 输出 MP4 / MOV
- 使用 VideoToolbox 导出 H.264、HEVC 和 Apple ProRes 422
- 自定义分辨率、帧率、视频码率与音频参数
- 保存、更新和删除自定义导出预设
- 预计输出大小、实时进度、取消任务及 Finder 定位

以上能力已经完成本地 MVP 验证。转换在本机执行，不上传视频。

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
