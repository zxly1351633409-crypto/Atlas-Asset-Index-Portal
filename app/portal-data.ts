export type DomainKind = "需求" | "产出" | "生产资产";
export type VersionState = "当前" | "历史" | "制作中";
export type ChangeState = "新增" | "修改" | "延续" | "待确认";
export type ContentType = "visual" | "model" | "ui" | "document" | "sheet";
export type IntegrityState = "完整" | "缺少预览" | "缺少源文件" | "路径待确认";
export type AssetOperationAction = "上传" | "修改" | "删除" | "回溯";

export type WorkDomain = {
  id: string;
  label: string;
  kind: DomainKind;
  description: string;
  icon: string;
};

export type SourceFile = {
  id: string;
  label: string;
  format: string;
  storage: "VS" | "NAS" | "工具链接";
  path: string;
  size: string;
  availability: "可按需获取" | "仅有预览" | "路径待确认";
};

export type PreviewAsset = {
  id: string;
  label: string;
  format: "JPG" | "PNG" | "WEBP";
  storage: "VS" | "NAS";
  path: string;
  size: string;
  url: string;
};

export type AssetOperation = {
  id: string;
  action: AssetOperationAction;
  revision: string;
  sourceRevision: string;
  actor: string;
  actorGroup: string;
  time: string;
  source: "TFVC" | "NAS";
  path: string;
  summary: string;
  fileCount: number;
};

export type ContentItem = {
  id: string;
  title: string;
  entryType: DomainKind;
  change: ChangeState;
  owner: string;
  updated: string;
  contentType: ContentType;
  previewMode: "image" | "document" | "sheet";
  previewAssets: PreviewAsset[];
  integrity: IntegrityState;
  description: string;
  tags: string[];
  sourceFiles: SourceFile[];
  relations: string[];
  operations: AssetOperation[];
};

export type ModuleVersion = {
  id: string;
  label: string;
  date: string;
  state: VersionState;
  summary: string;
  items: ContentItem[];
};

export type ProjectModule = {
  id: string;
  domainId: string;
  name: string;
  description: string;
  owner: string;
  updated: string;
  cover?: string;
  currentVersion: string;
  status: "正常" | "制作中" | "待整理";
  source: "演示" | "共享盘";
  requirementCount: number;
  outputCount: number;
  reusableCount: number;
  versions: ModuleVersion[];
};

export const workDomains: WorkDomain[] = [
  { id: "scene", label: "场景", kind: "产出", description: "地图场景、剧情空间与战斗区域", icon: "mountain" },
  { id: "character", label: "角色", kind: "产出", description: "角色设定、立绘与表现资源", icon: "user" },
  { id: "writing-request", label: "文案需求", kind: "需求", description: "剧情、对白、任务和包装文案", icon: "file-text" },
  { id: "system-request", label: "系统需求", kind: "需求", description: "玩法系统、流程与界面规则", icon: "workflow" },
  { id: "illustration-request", label: "插画需求", kind: "需求", description: "主视觉、过场图和宣传图需求", icon: "clipboard" },
  { id: "illustration", label: "插画", kind: "产出", description: "插画成图、差分与源文件", icon: "image" },
  { id: "ui", label: "UI", kind: "产出", description: "界面视觉、切图与交互稿", icon: "panels" },
  { id: "model", label: "模型", kind: "生产资产", description: "场景组件、角色模型与工程", icon: "box" },
  { id: "material", label: "材质贴图", kind: "生产资产", description: "PBR 材质、纹理和通用贴图", icon: "swatch" },
];

const previews = [
  "/previews/canyon.jpg",
  "/previews/forest.jpg",
  "/previews/snow.jpg",
  "/previews/warehouse.jpg",
  "/previews/pine.jpg",
  "/previews/stone-gate.jpg",
];

type ModuleSeed = {
  id: string;
  domainId: string;
  name: string;
  description: string;
  owner: string;
  cover?: string;
  status?: ProjectModule["status"];
  titles: string[];
};

const requirementDomains = new Set(["writing-request", "system-request", "illustration-request"]);
const productionDomains = new Set(["model", "material"]);

function previewAssetsFor(domainId: string, moduleName: string, version: string, title: string, cover?: string): PreviewAsset[] {
  if (!cover || requirementDomains.has(domainId)) return [];
  const base = `${domainId}/${moduleName}/${version}/${title}`;
  const isUi = domainId === "ui";
  return [{
    id: `${base}-preview`,
    label: domainId === "model" ? "模型渲染预览" : domainId === "material" ? "材质球预览" : "内容预览图",
    format: isUi ? "PNG" : "JPG",
    storage: "VS",
    path: `VS/预览/${base}.${isUi ? "png" : "jpg"}`,
    size: domainId === "model" ? "4.6 MB" : "3.2 MB",
    url: cover,
  }];
}

function sourceFilesFor(domainId: string, moduleName: string, version: string, title: string, previewMode: ContentItem["previewMode"]): SourceFile[] {
  const base = `${domainId}/${moduleName}/${version}/${title}`;

  if (requirementDomains.has(domainId)) {
    return previewMode === "sheet"
      ? [{ id: `${base}-xlsx`, label: "需求清单表格", format: "XLSX", storage: "VS", path: `VS/需求/${base}.xlsx`, size: "860 KB", availability: "可按需获取" }]
      : [{ id: `${base}-docx`, label: "可编辑需求文档", format: "DOCX", storage: "VS", path: `VS/需求/${base}.docx`, size: "1.8 MB", availability: "可按需获取" }];
  }

  if (domainId === "model") {
    return [
      { id: `${base}-blend`, label: "Blender 工程", format: "BLEND", storage: "NAS", path: `\\\\NAS\\项目资产\\模型\\${moduleName}\\${version}\\${title}.blend`, size: "684 MB", availability: "可按需获取" },
      { id: `${base}-fbx`, label: "交换模型", format: "FBX", storage: "NAS", path: `\\\\NAS\\项目资产\\模型\\${moduleName}\\${version}\\${title}.fbx`, size: "126 MB", availability: "可按需获取" },
    ];
  }

  if (domainId === "material") {
    return [
      { id: `${base}-maps`, label: "PBR 贴图包", format: "ZIP", storage: "NAS", path: `\\\\NAS\\项目资产\\材质\\${moduleName}\\${version}\\${title}.zip`, size: "238 MB", availability: "可按需获取" },
    ];
  }

  if (domainId === "ui") {
    return [
      { id: `${base}-psd`, label: "设计源文件", format: "PSD", storage: "VS", path: `VS/UI/psd/${base}.psd`, size: "286 MB", availability: "可按需获取" },
      { id: `${base}-figma`, label: "交互稿", format: "LINK", storage: "工具链接", path: `figma://project/${moduleName}/${version}`, size: "在线", availability: "可按需获取" },
    ];
  }

  return [
    { id: `${base}-psd`, label: "分层源文件", format: "PSD", storage: "VS", path: `VS/${domainId}/psd/${moduleName}/${version}/${title}.psd`, size: "412 MB", availability: "可按需获取" },
    ...(["scene", "illustration"].includes(domainId) ? [{ id: `${base}-3d`, label: "3D 辅助工程", format: "BLEND", storage: "NAS" as const, path: `\\\\NAS\\项目资产\\3D工程\\${moduleName}\\${version}\\${title}.blend`, size: "1.7 GB", availability: "可按需获取" as const }] : []),
  ];
}

function operationHistoryFor(seed: ModuleSeed, version: string, versionIndex: number, itemIndex: number, title: string, sourceFiles: SourceFile[]): AssetOperation[] {
  const primarySource = sourceFiles[0];
  const source = primarySource?.storage === "NAS" ? "NAS" : "TFVC";
  const path = primarySource?.path ?? `TFVC/${seed.domainId}/${seed.name}/${version}/${title}`;
  const date = versionIndex === 0 ? "2026-07-14" : versionIndex === 1 ? "2026-06-18" : "2026-05-07";
  const baseRevision = 4200 + versionIndex * 100 + itemIndex * 10;
  const actorGroup = productionDomains.has(seed.domainId) ? "资产组" : requirementDomains.has(seed.domainId) ? "策划组" : `${workDomains.find((domain) => domain.id === seed.domainId)?.label ?? "内容"}组`;
  const operationId = `${seed.id}-${version}-${itemIndex}`;

  return [
    {
      id: `${operationId}-operation-4`, action: "修改", revision: `${version}-R4`, sourceRevision: source === "TFVC" ? `C${baseRevision + 4}` : `NAS-${baseRevision + 4}`,
      actor: seed.owner, actorGroup, time: `${date} 14:26`, source, path,
      summary: "更新当前交付文件和预览，并保留上一修订快照。", fileCount: Math.max(sourceFiles.length, 1),
    },
    {
      id: `${operationId}-operation-3`, action: "回溯", revision: `${version}-R3`, sourceRevision: source === "TFVC" ? `C${baseRevision + 3}` : `NAS-${baseRevision + 3}`,
      actor: "周遥", actorGroup: "项目管理", time: `${date} 11:42`, source, path,
      summary: `从 ${version}-R1 回溯并创建新修订，没有覆盖删除记录。`, fileCount: Math.max(sourceFiles.length, 1),
    },
    {
      id: `${operationId}-operation-2`, action: "删除", revision: `${version}-R2`, sourceRevision: source === "TFVC" ? `C${baseRevision + 2}` : `NAS-${baseRevision + 2}`,
      actor: seed.owner, actorGroup, time: `${date} 10:18`, source, path,
      summary: "删除错误交付；门户保留元数据和快照，可从此节点恢复。", fileCount: 1,
    },
    {
      id: `${operationId}-operation-1`, action: "上传", revision: `${version}-R1`, sourceRevision: source === "TFVC" ? `C${baseRevision + 1}` : `NAS-${baseRevision + 1}`,
      actor: seed.owner, actorGroup, time: `${date} 09:05`, source, path,
      summary: "首次登记预览与源文件，建立内容和来源路径关系。", fileCount: Math.max(sourceFiles.length, 1),
    },
  ];
}

function makeItems(seed: ModuleSeed, version: string, versionIndex: number): ContentItem[] {
  const domain = workDomains.find((item) => item.id === seed.domainId)!;
  const visibleTitles = versionIndex === 0 ? seed.titles : seed.titles.slice(0, 2);
  return visibleTitles.map((title, index) => {
    const previewMode: ContentItem["previewMode"] = requirementDomains.has(seed.domainId) ? (index % 2 === 0 ? "document" : "sheet") : "image";
    const previewAssets = previewAssetsFor(seed.domainId, seed.name, version, title, seed.cover);
    const sourceFiles = sourceFilesFor(seed.domainId, seed.name, version, title, previewMode);
    const contentType: ContentType = seed.domainId === "model" ? "model" : seed.domainId === "ui" ? "ui" : previewMode === "document" ? "document" : previewMode === "sheet" ? "sheet" : "visual";
    const integrity: IntegrityState = previewMode === "image" && previewAssets.length === 0 ? "缺少预览" : sourceFiles.length === 0 ? "缺少源文件" : sourceFiles.some((file) => file.availability === "路径待确认") ? "路径待确认" : "完整";
    return {
    id: `${seed.id}-${version}-${index}`,
    title,
    entryType: domain.kind,
    change: versionIndex === 0 ? (["新增", "修改", "延续"][index] as ChangeState) : index === 0 ? "修改" : "延续",
    owner: seed.owner,
    updated: versionIndex === 0 ? "今天 14:26" : versionIndex === 1 ? "6月18日" : "5月07日",
    contentType,
    previewMode,
    previewAssets,
    integrity,
    description: `${seed.name}在 ${version} 的${domain.kind}条目，已建立版本、负责人和来源文件关系。`,
    tags: [domain.label, seed.name, version],
    sourceFiles,
    relations: requirementDomains.has(seed.domainId) ? ["关联评审记录", "等待绑定产出"] : ["关联上游需求", "可加入复用清单"],
    operations: operationHistoryFor(seed, version, versionIndex, index, title, sourceFiles),
    };
  });
}

function makeModule(seed: ModuleSeed, index: number): ProjectModule {
  const versions: Array<{ label: string; date: string; state: VersionState }> = [
    { label: "V6.2", date: "2026-07-11", state: seed.status === "制作中" ? "制作中" : "当前" },
    { label: "V6.1", date: "2026-06-18", state: "历史" },
    { label: "V6.0", date: "2026-05-07", state: "历史" },
  ];
  return {
    id: seed.id,
    domainId: seed.domainId,
    name: seed.name,
    description: seed.description,
    owner: seed.owner,
    updated: index % 2 === 0 ? "今天更新" : "昨天更新",
    cover: seed.cover,
    currentVersion: "V6.2",
    status: seed.status ?? "正常",
    source: "演示",
    requirementCount: 3 + index,
    outputCount: 8 + index * 3,
    reusableCount: productionDomains.has(seed.domainId) || seed.domainId === "scene" ? 4 + index * 2 : index,
    versions: versions.map((version, versionIndex) => ({
      id: `${seed.id}-${version.label}`,
      label: version.label,
      date: version.date,
      state: version.state,
      summary: `${version.label} 包含 ${versionIndex === 0 ? seed.titles.length : 2} 条内容，记录该版本的新增、修改与延续项。`,
      items: makeItems(seed, version.label, versionIndex),
    })),
  };
}

const moduleSeeds: ModuleSeed[] = [
  { id: "wasteland", domainId: "scene", name: "荒原地图", description: "荒原主线、探索区域与远景空间", owner: "林澈", cover: previews[0], titles: ["风蚀峡谷入口", "旧路驿站", "盐湖远景"] },
  { id: "capital-event", domainId: "scene", name: "主城活动地图", description: "主城节庆、活动和剧情空间", owner: "周遥", cover: previews[1], titles: ["雨林遗迹中庭", "节庆广场夜景", "南门集市"] },
  { id: "roguelike-map", domainId: "scene", name: "肉鸽地图", description: "随机房间、战斗节点与结算空间", owner: "陈朔", cover: previews[2], status: "制作中", titles: ["雪原观测站", "遗迹战斗房", "补给节点"] },
  { id: "chapter-cast", domainId: "character", name: "第六章角色组", description: "第六章主要角色设定与立绘", owner: "许沐", cover: previews[3], titles: ["逐光者设定", "荒原向导立绘", "守门人差分"] },
  { id: "wasteland-enemy", domainId: "character", name: "荒原敌对单位", description: "荒原区域敌人和首领视觉", owner: "高屿", cover: previews[5], titles: ["岩壳兽", "风暴猎手", "峡谷首领"] },
  { id: "main-story-copy", domainId: "writing-request", name: "第六章主线", description: "主线剧情、对白和演出文案", owner: "沈墨", titles: ["峡谷初遇对白", "观测站剧情说明", "章节收束文本"] },
  { id: "event-copy", domainId: "writing-request", name: "夏季活动", description: "活动任务、包装和奖励文案", owner: "唐语", status: "制作中", titles: ["活动世界观说明", "任务链文案", "商店包装文本"] },
  { id: "equipment-system", domainId: "system-request", name: "装备淬炼", description: "淬炼规则、数值流程和异常处理", owner: "赵策", titles: ["系统规则说明", "操作流程需求", "错误状态清单"] },
  { id: "roguelike-system", domainId: "system-request", name: "肉鸽词条", description: "词条组合、刷新和结算规则", owner: "顾淮", titles: ["词条池需求", "刷新规则", "结算继承说明"] },
  { id: "key-visual-request", domainId: "illustration-request", name: "V6.2 主视觉", description: "版本主视觉的构图和投放需求", owner: "叶澄", titles: ["主视觉需求单", "角色站位说明", "渠道尺寸清单"] },
  { id: "chapter-cover-request", domainId: "illustration-request", name: "章节封面", description: "章节封面与过场图需求", owner: "江禾", titles: ["第六章封面需求", "过场图拆分", "差分清单"] },
  { id: "key-visual", domainId: "illustration", name: "V6.2 主视觉", description: "版本主视觉、渠道差分和源文件", owner: "苏文", cover: previews[0], titles: ["主视觉原图", "横版渠道差分", "竖版渠道差分"] },
  { id: "story-illustration", domainId: "illustration", name: "剧情过场", description: "主线剧情过场插画", owner: "林澈", cover: previews[2], titles: ["峡谷初遇", "观测站危机", "荒原落日"] },
  { id: "main-ui", domainId: "ui", name: "主界面改版", description: "主界面导航、信息层级和视觉资源", owner: "楚宁", cover: previews[3], titles: ["主界面视觉稿", "导航展开态", "弹窗组件表"] },
  { id: "roguelike-ui", domainId: "ui", name: "肉鸽结算", description: "肉鸽结算、奖励和词条展示", owner: "温岚", cover: previews[1], titles: ["结算主界面", "奖励选择弹窗", "词条详情"] },
  { id: "wasteland-kit", domainId: "model", name: "荒原组件库", description: "岩石、植被和建筑可复用组件", owner: "高屿", cover: previews[4], titles: ["风化岩柱组", "悬崖松树组", "木质路标组"] },
  { id: "capital-kit", domainId: "model", name: "主城建筑组件", description: "主城遗迹和街区模块化组件", owner: "苏文", cover: previews[5], titles: ["古代石门构件", "遗迹拱门组", "仓库立面组"] },
  { id: "terrain-material", domainId: "material", name: "荒原地表材质", description: "沙砾、风化岩与盐碱地表", owner: "顾川", cover: previews[0], titles: ["风化岩地表", "盐碱地裂纹", "峡谷沙砾"] },
  { id: "building-material", domainId: "material", name: "建筑表面材质", description: "石材、木材和金属建筑表面", owner: "季衡", cover: previews[5], titles: ["遗迹石材", "旧木板", "锈蚀金属"] },
];

export const projectModules: ProjectModule[] = moduleSeeds.map(makeModule);

export function domainById(id: string) {
  return workDomains.find((domain) => domain.id === id) ?? workDomains[0];
}

export function modulesForDomain(domainId: string) {
  return projectModules.filter((module) => module.domainId === domainId);
}
