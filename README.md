# Toolbox

一款面向 macOS 的原生工具箱 App，计划整合创作、文本、网络、隐私和系统辅助工具。

App 用户界面从英文版开始开发；项目协作文档继续使用中文。

## 当前状态

本地多工具 MVP 已完成：除视频转换外，现已提供 Text Diff、UUID / Random String、Password Tools 和 Network Tools，并通过统一侧边栏切换。

当前版本仅用于本地开发验证，依赖本机安装的 FFmpeg；尚未配置正式签名、App Sandbox 或 GitHub 开源。产品方向确定为不内嵌 FFmpeg，缺少依赖时引导用户通过 Homebrew 安装。

## 本地开发

- Xcode 工程：`Toolbox.xcodeproj`
- App Target：`Toolbox`
- Bundle ID：`com.raycal.Toolbox`（暂定）
- 最低系统版本：macOS 15.0
- Swift：6.0

用 Xcode 打开 `Toolbox.xcodeproj` 后即可构建运行，通过左侧分组侧边栏选择工具。

视频转换 MVP 需要本机安装 FFmpeg：

```bash
brew install ffmpeg
```

App 当前寻找 `/opt/homebrew/bin/ffmpeg` 和 `/usr/local/bin/ffmpeg`。未检测到依赖时会区分 Homebrew / FFmpeg 缺失状态，显示安装说明、可复制命令和重新检测入口。

## 产品方向

- macOS 原生体验
- 本地优先和隐私优先
- 工具模块化，可收藏常用工具
- 后续可逐步接入菜单栏、全局快捷方式、Finder 和系统服务
- 联网功能明确标识，并安全保存凭据

## 当前优先功能

- 批量添加、拖放和顺序转换视频
- 每个队列项目独立保存导出参数，选择视频后只编辑该视频的设置
- 读取分辨率、帧率、时长、编码和文件大小
- 输出 MP4 / MOV
- 使用 VideoToolbox 导出 H.264、HEVC 和 Apple ProRes 422
- 通过常用预设或自定义数值设置分辨率、帧率、视频码率与音频参数
- 保存、更新和删除自定义导出预设
- 自定义输出基础名称，并自动追加分辨率、帧率、编码和码率后缀，例如 `name_4K60_H265_40M.mp4`
- 预计输出大小、进度百分比、实际用时、预计剩余时间、实时转换帧率、取消任务及 Finder 定位
- 再次开始时只处理就绪、失败或已取消的项目，已完成项目不会重复导出
- 已完成、失败或取消的项目均可从队列移除

以上能力已经完成本地 MVP 验证。转换在本机执行，不上传视频。

## 已实现工具

- **Text Diff**：左右文本编辑、逐行或逐词对比、并排或统一结果、新增/删除/修改高亮、UTF-8 文本文件拖入和结果复制。
- **UUID & Random String**：UUID v4、自定义长度与字符组、批量生成、单项或全部复制，使用系统安全随机源。
- **Password Tools**：强密码批量生成、排除易混淆字符、本地密码强度与改进建议；密码不保存、不上传。
- **Network Tools**：本机接口与地址、公网 IPv4/IPv6、IPv4/IPv6 Ping、IP/CIDR 规范化及网段范围解析。公网地址仅在用户点击 Refresh 后向 `ipify.org` 查询，结果不持久化。

## 其他候选能力

- 剪贴板历史
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
