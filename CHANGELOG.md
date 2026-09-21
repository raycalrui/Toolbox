# Changelog

本文件只记录已经交付、用户可感知的产品变化。规划、候选需求和未完成工作统一记录在 `TODO.md`。

## Unreleased

- 建立最小 macOS SwiftUI 工程骨架和本地开发配置。
- 新增视频转换工具本地 MVP：
  - 批量选择或拖放视频，并读取基础媒体信息。
  - 支持 MP4 / MOV、H.264 / HEVC / ProRes 422、AAC / PCM。
  - 支持自定义分辨率、帧率、码率和预计输出大小。
  - 支持内置及自定义预设的保存、更新和删除。
  - 支持转换进度、取消任务和在 Finder 中显示结果。
  - 通过 FFmpeg 调用 Apple VideoToolbox 硬件编码。
