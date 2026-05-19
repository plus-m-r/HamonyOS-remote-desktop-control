# HarmonyOS Skills 安装说明

## ✅ 安装状态

**harmony-next skill 已成功全局安装！**

### 安装位置（与nature-skills相同）
```
C:\Users\20241\.lingma\skills\harmony-next
```

### 支持的AI助手
- ✅ Lingma (主要)
- ✅ Cursor
- ✅ GitHub Copilot
- ✅ Trae CN
- ✅ Windsurf
- ✅ 以及其他支持Skills的AI编码助手

---

## 📚 Skill功能概述

### 版本信息
- **Skill版本**: v1.3.5
- **API快照**: HarmonyOS API 12-23（离线文档）
- **最后更新**: 2026年

### 核心功能

#### 1. ArkTS/ArkUI API查询
- 完整的JS/ETS API参考文档
- 组件使用指南和代码示例
- 类型定义和错误码查询

#### 2. DevEco Studio自动化
- CodeGenie智能代码生成
- MCP工具集成
- LanceDB向量数据库
- devecostudio://协议支持

#### 3. 诊断工具
- hdc命令行工具
- uitest自动化测试
- aa/bm应用管理
- hilog日志分析
- hidumper系统诊断

#### 4. 开发工具
- ArkUI Inspector调试
- Previewer预览器
- Profiler性能分析
- Doctor健康检查
- UxTestService UX测试

---

## 🎯 使用方法

### 在AI助手中使用

#### 方式1：直接提问
```
@harmony-next 如何在ArkTS中实现列表懒加载？
```

#### 方式2：API查询
```
@harmony-next 查找Image组件的objectFit属性用法
```

#### 方式3：错误排查
```
@harmony-next 解决 "Component not found" 错误
```

#### 方式4：代码生成
```
@harmony-next 创建一个带有下拉刷新的列表页面
```

### 路由机制

Skill会自动将您的问题路由到合适的文档：

1. **API/组件问题** → `references/KITS.md` + `references/TASK_MAP.md`
2. **DevEco IDE问题** → `references/ideGuides/`
3. **模拟器/调试问题** → `references/testing/`
4. **未知领域** → `references/INDEX.md` 全库搜索

---

## 📁 文档结构

```
harmony-next/
├── SKILL.md                    # Skill主配置文件
├── references/                 # 离线参考文档
│   ├── INDEX.md               # 全库路径索引（213KB）
│   ├── KITS.md                # Kit导航
│   ├── TASK_MAP.md            # 任务导向地图
│   ├── JsEtsAPIReference/     # JS/ETS API参考
│   │   ├── modules/           # 模块文档
│   │   ├── topics/            # 主题文档
│   │   ├── types/             # 类型定义
│   │   ├── errors/            # 错误码
│   │   └── guides/            # 使用指南
│   ├── ideGuides/             # DevEco Studio指南
│   ├── appBasics/             # 应用基础
│   ├── ndkGuides/             # NDK开发指南
│   ├── performanceAndStandards/ # 性能与标准
│   └── ...
├── scripts/                   # 自动化脚本
└── tests/                     # 测试用例
```

---

## 🔧 管理Skills

### 查看已安装的Skills
```bash
# 查看所有全局skills
ls ~\.lingma\skills\

# 或在PowerShell中
Get-ChildItem ~\.lingma\skills\
```

### 安装Skill（与nature-skills相同的方法）
```bash
# 方法1：从GitHub仓库克隆后复制
git clone https://github.com/linhay/harmony-next.skills.git
cp -r harmony-next.skills/harmony-next ~\.lingma\skills\

# 方法2：直接复制本地文件
Copy-Item -Path "C:\path\to\harmony-next" -Destination "~\.lingma\skills\harmony-next" -Recurse
```

### 更新Skill
```bash
# 删除旧版本
Remove-Item ~\.lingma\skills\harmony-next -Recurse -Force

# 重新安装最新版本
git clone https://github.com/linhay/harmony-next.skills.git
cp -r harmony-next.skills/harmony-next ~\.lingma\skills\
```

### 删除Skill
```bash
Remove-Item ~\.lingma\skills\harmony-next -Recurse -Force
```

---

## 💡 最佳实践

### 1. 精确提问
❌ 不好： "怎么用HarmonyOS？"
✅ 好： "@harmony-next 如何在ArkTS中使用LazyForEach优化长列表性能？"

### 2. 提供上下文
```
@harmony-next 
我在DevEco Studio中遇到编译错误：
"Property 'xxx' does not exist on type 'yyy'"

我的代码：
[粘贴相关代码]

请帮我解决这个问题。
```

### 3. 指定API版本
```
@harmony-next 
在API 12中，如何使用@State装饰器？
与API 10有什么区别？
```

### 4. 请求代码示例
```
@harmony-next 
请提供一个完整的示例：
- 使用HTTP模块发起GET请求
- 处理响应数据
- 错误处理
- TypeScript类型定义
```

---

## ⚠️ 注意事项

### 离线文档限制
- 当前文档是**离线快照**（API 12-23）
- 对于最新API，建议同时参考华为官方在线文档
- 网址：https://developer.harmonyos.com/cn/docs

### 版本兼容性
- Skill版本：v1.3.5
- 如需最新版本，请定期从GitHub更新
- GitHub仓库：https://github.com/linhay/harmony-next.skills

### 权限说明
- Skills以**完整代理权限**运行
- 可以访问文件系统、执行命令等
- 使用前请审查Skill内容

---

## 🔄 定期更新

建议每月检查一次更新：

```bash
# 检查是否有新版本
npx skills list --global

# 如果有更新，重新安装
npx skills add linhay/harmony-next.skills --global --yes
```

---

## 📞 获取帮助

### Skill问题
- GitHub Issues: https://github.com/linhay/harmony-next.skills/issues
- 作者: linhay

### HarmonyOS开发问题
- 官方文档: https://developer.harmonyos.com
- 开发者论坛: https://developer.huawei.com/consumer/cn/forum

### 本项目相关问题
- 项目仓库: https://github.com/plus-m-r/HamonyOS-remote-desktop-control
- 技术团队: 方寸控技术团队

---

## ✨ 总结

您现在拥有了一个强大的HarmonyOS开发助手！

**主要优势**：
- ✅ 离线可用，无需联网
- ✅ 完整的API文档（12-23版本）
- ✅ 支持多个AI编码助手
- ✅ 自动化诊断和调试
- ✅ 代码生成和最佳实践

**开始使用**：
在任何支持Skills的AI助手中，使用 `@harmony-next` 前缀提问即可！

---

**安装日期**: 2026-05-19  
**Skill版本**: v1.3.5  
**安装位置**: C:\Users\20241\.lingma\skills\harmony-next  
**安装方式**: 与nature-skills相同，直接复制到.lingma/skills目录
