# 系统化开发文档

本目录用于记录 HarmonyOS 远程桌面控制客户端的系统性开发文档，覆盖架构、组件设计、构建环境、测试与质量、发布与部署等核心内容。

## 文档结构

- `README.md` - 目录介绍与使用说明
- `architecture.md` - 系统架构、模块分层与依赖关系
- `component-design.md` - 组件设计、服务职责和接口概述
- `build-and-environment.md` - 开发环境、构建步骤、依赖管理
- `testing-and-quality.md` - 测试策略、质量标准、测试目录说明

## 如何使用

1. 先阅读 `README.md` 了解文档结构。
2. 按照系统架构和组件设计对照代码实现，补充或修正文档内容。
3. 构建与测试前，阅读 `build-and-environment.md` 和 `testing-and-quality.md`。
4. 任何技术变更都应同步更新本目录中的相应文档。

## 维护规范

- 变更架构时：更新 `architecture.md`
- 调整服务或模块职责时：更新 `component-design.md`
- 变更编译、构建或依赖时：更新 `build-and-environment.md`
- 新增测试或修改测试规则时：更新 `testing-and-quality.md`

> 目标：使开发文档成为项目知识库，而不是孤立的说明文档。每次代码变更应同时被文档记录。
