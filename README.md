# Atlas 美术资源索引门户

Atlas 是一个本地优先的美术资源索引原型：保留 Team Foundation/TFVC、NAS 和历史文件夹，在其上增加工作域、模块、版本轴、轻量预览、来源路径与操作回溯。它不迁移源文件，也不把 PSD 或 3D 工程搬进网页。

## Windows 一键使用

无需预先安装 Node.js。解压后按这个顺序操作：

1. 双击 `连接资源目录.bat`。
2. 输入本机目录，例如 `D:\Atlas-Resource-Share`；也可输入共享路径，例如 `\\资源电脑\AtlasShare`。
3. 双击 `启动 Atlas.bat`。
4. 首次运行会检查 Node.js、安装锁定依赖并构建，完成后自动打开浏览器。
5. 日常再次打开可双击 `打开 Atlas.bat`；结束时双击 `停止 Atlas.bat`。

启动窗口会保留成功状态和页面地址，不会一闪而过。默认地址为 `http://127.0.0.1:3011/`。

### 首次运行会做什么

- 优先复用电脑上符合要求的 Node.js 22.13+。
- 若不存在，则从 Node.js 官方 `latest-v22.x` 发布目录下载 Windows 便携 ZIP，并核对 `SHASUMS256.txt`。
- 依据 `package-lock.json` 执行 `npm ci`；锁文件未变化时不会重复安装。
- 源码未变化时不会重复构建。
- 启动目录监视器和本机网页服务，随后打开默认浏览器。

联网首次安装通常需要几分钟。公司网络无法访问 Node.js/npm 时，应使用离线包或由技术部门配置内部软件源；启动器不会绕过代理、账号或安全策略。

## 资源目录结构

连接脚本会在所选根目录下建立标准演示结构：

```text
<资源根目录>\
└─ ProjectAurora\
   ├─ Scenes\
   │  └─ <模块>\<版本>\<内容或文件>
   ├─ Characters\
   ├─ Illustrations\
   ├─ UI\
   ├─ Requirements\Writing\
   ├─ Requirements\System\
   ├─ Requirements\Illustration\
   ├─ Models\
   └─ Materials\
```

最简测试可把图片直接放在：

```text
ProjectAurora\Scenes\J 剧情 模块\1.0\preview.png
```

页面会产生“场景 → J 剧情 模块 → 1.0 → preview”关系。内容文件夹也可包含 `Preview`、`Source`、`Export`、`Documents` 子目录。

JPG、PNG、WebP 会在文件写入完成后生成最长边不超过 1280 像素的轻量 JPEG 缩略图；高清原图继续保留在原目录并作为来源文件按需获取。大图复制期间不会读取半成品，生成失败会记录明确状态，目录监视器也不会因此退出。

标准目录只用于本机演示。公司现有 JPG、PSD 与 3D 工程可以位于不同 TFVC/NAS 路径；正式接入应把这些路径关联为同一条内容记录，而不是要求搬到同一个文件夹。

## 换电脑与共享盘演示

资源提供电脑：

1. 建立一个测试文件夹并通过 Windows 共享。
2. 给演示账号读取或读写权限。
3. 记下 UNC 路径，例如 `\\DESIGN-PC\AtlasShare`。

演示电脑：

1. 在资源管理器中先打开 UNC 路径，确认 Windows 凭证与网络可用。
2. 解压 Atlas，运行 `连接资源目录.bat` 并输入该 UNC。
3. 运行 `启动 Atlas.bat`。
4. 在资源提供电脑新增图片，演示电脑页面刷新后即可看到变化。

工具不会绕过 NAS 权限、防火墙、VPN 或文件占用锁。标准目录可直接演示；公司多年历史目录需要正式连接器和“原路径 → 工作域/模块/版本”的虚拟映射，不能自动猜测。

详细步骤见 [Windows 便携演示与跨电脑连接](docs/13-Windows便携演示与跨电脑连接.md)。

## 当前功能

- 场景、角色、需求、插画、UI、模型和材质贴图工作域。
- 工作域 → 模块 → 版本轴 → 内容 → 来源文件的浏览流程。
- 图片与模型预览图双击查看，高清图和源工程按需获取。
- JPG/PNG、PSD、3D 工程文件夹与需求文档的组合登记；也可分别关联三个已有 TFVC/NAS 路径。
- 上传、修改、删除和回溯操作变更轴；回溯追加修订，不覆盖旧记录。
- 模拟职位、团队、角色与工作域权限。
- 外部目录自动扫描、轻量预览缓存和新增/删除同步。
- 首次加载显示真实连接状态，不用“0 个模块”冒充空目录。

## 开发运行

技术栈：Next.js 16、React 19、vinext、TypeScript、Drizzle ORM、Cloudflare Workers。

```powershell
npm.cmd ci
npm.cmd run dev -- --port 3011
```

验证：

```powershell
npm.cmd test
npm.cmd run lint
```

生成 Windows 联网便携包：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\release\Build-PortablePackage.ps1
```

产物位于 `release\Atlas-Portal-Windows-v0.2.1.zip`，适合放到 GitHub Releases；ZIP 不包含本机配置、缓存、`node_modules` 或真实资源。

## GitHub 上传建议

1. 优先建立私有仓库，确认演示图片、机器名和内部计划案是否适合公开。
2. 不提交 `config/local.user.json`、`.runtime`、`public/connector-data`、`lab-data` 或真实资源目录；这些已加入 `.gitignore`。
3. 提交 `package-lock.json`，保证另一台电脑和 GitHub Actions 使用同一依赖集合。
4. ZIP 放在 GitHub Release 或 Actions Artifact，不要直接提交大型离线依赖包到 Git 历史。

仓库内的 Windows 工作流会在提交或手动运行时执行测试并生成联网便携包。

## 文档导航

- `docs/09-企业接入与权限方案.md`：TFVC、NAS、账号权限和试点边界。
- `docs/10-大规模资源加载与交接.md`：增量索引、缓存、性能与技术交接。
- `docs/11-操作变更轴与本机联调.md`：变更轴、VS2022、TFVC 和共享盘实验。
- `docs/13-Windows便携演示与跨电脑连接.md`：另一台电脑的完整演示手册。
- 本机 `交付` 目录另存可直接发送给主美的图文 Word；内部截图与沟通稿不会上传公开 GitHub。

## 重要边界

当前是个人验证原型，不是公司生产系统。它尚未接入公司真实 Team Foundation、NAS、统一登录、签入签出、正式审计或海量历史目录规则。企业试点应使用只读账号、非敏感样本和限定路径。
