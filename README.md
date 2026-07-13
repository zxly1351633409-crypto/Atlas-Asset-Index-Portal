# Atlas 资产索引门户

游戏项目内容档案原型，验证工作域、模块、版本、需求与产出的关联关系，以及 VS/NAS 源文件按需获取流程。不包含任何公司资源。

**技术栈**：Next.js 16 · React 19 · Tailwind CSS 4 · Drizzle ORM · Cloudflare Workers · TypeScript

## 当前功能

- 按场景、角色、需求、插画、UI、模型等工作域浏览。
- 工作域下先展示模块，进入模块后使用版本轴切换。
- 模块默认打开当前有效版本，并提供跨版本总览。
- 内容条目标记新增、修改、延续和待确认。
- JPG、PSD、3D 工程和需求文档等源文件按需获取。
- “新增/关联内容”区分关联已有路径、上传预览和提交源文件。
- 桌面端和窄屏响应式布局。

## 本地运行

环境要求：Node.js 22.13 或更高版本。

```powershell
npm.cmd install
npm.cmd run dev -- --port 3011
```

访问 `http://localhost:3011/`。

正式构建：

```powershell
npm.cmd run build
```

## 项目资料

- `docs/01-需求分析.md`：目标、问题、范围与原则。
- `docs/02-开发路线图.md`：阶段方案与验收标准。
- `docs/03-进度记录.md`：当前进度与关键决策。
- `mock-data/`：下一阶段目录扫描器使用的个人模拟资源入口。
