import {
  domainById,
  type AssetOperation,
  type ContentItem,
  type ContentType,
  type PreviewAsset,
  type ProjectModule,
  type SourceFile,
  type VersionState,
} from "./portal-data";

export type ExternalShareSourceFile = {
  name: string;
  path: string;
  uncPath?: string;
  relativePath: string;
  category: string;
  format: string;
  size: number;
  lastWriteTime: string;
};

export type ExternalShareAsset = {
  id: string;
  domainId: string;
  domainLabel: string;
  name: string;
  module: string;
  version: string;
  description: string;
  owner: string;
  actorGroup: string;
  tags: string[];
  rootPath: string;
  uncPath?: string;
  previewUrl?: string;
  previewPath?: string;
  previewUncPath?: string;
  previewSize: number;
  previewFormat?: string;
  sourceFiles: ExternalShareSourceFile[];
  fileCount: number;
  totalBytes: number;
  updatedAt: string;
  lifecycleStatus: "active";
  operations: AssetOperation[];
};

export type ExternalShareDomain = {
  domainId: string;
  label: string;
  relativeRoot: string;
  rootPath: string;
  uncPath?: string;
  fileCount: number;
  totalBytes: number;
  moduleCount: number;
  assetCount: number;
};

export type ExternalShareModuleVersion = {
  label: string;
  rootPath: string;
  uncPath?: string;
  updatedAt: string;
  assetCount: number;
};

export type ExternalShareModule = {
  id: string;
  domainId: string;
  domainLabel: string;
  name: string;
  rootPath: string;
  uncPath?: string;
  updatedAt: string;
  versions: ExternalShareModuleVersion[];
};

export type ExternalShareIndex = {
  status: "online";
  shareName: string;
  rootPath: string;
  uncPath?: string;
  projectRoot: string;
  scannedAt: string;
  fileCount: number;
  totalBytes: number;
  deletedAssetCount: number;
  domains: ExternalShareDomain[];
  modules: ExternalShareModule[];
  assets: ExternalShareAsset[];
};

const requirementDomains = new Set(["writing-request", "system-request", "illustration-request"]);
const versionCollator = new Intl.Collator("zh-CN", { numeric: true, sensitivity: "base" });

export function formatFileSize(bytes: number) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
  return `${(bytes / 1024 / 1024 / 1024).toFixed(1)} GB`;
}

function contentTypeFor(asset: ExternalShareAsset): ContentType {
  if (asset.domainId === "model") return "model";
  if (asset.domainId === "ui") return "ui";
  if (requirementDomains.has(asset.domainId)) {
    return asset.sourceFiles.some((file) => file.format === "XLSX") ? "sheet" : "document";
  }
  return "visual";
}

function previewFor(asset: ExternalShareAsset): PreviewAsset[] {
  if (!asset.previewUrl) return [];
  const format = asset.previewFormat === "PNG" ? "PNG" : asset.previewFormat === "WEBP" ? "WEBP" : "JPG";
  return [{
    id: `${asset.id}-preview`,
    label: "共享盘预览",
    format,
    storage: "NAS",
    path: asset.previewUncPath ?? asset.previewPath ?? asset.uncPath ?? asset.rootPath,
    size: formatFileSize(asset.previewSize),
    url: asset.previewUrl,
  }];
}

function sourceFilesFor(asset: ExternalShareAsset): SourceFile[] {
  return asset.sourceFiles.map((file, index) => ({
    id: `${asset.id}-source-${index}`,
    label: file.name,
    format: file.format || "FILE",
    storage: "NAS",
    path: file.uncPath ?? file.path,
    size: formatFileSize(file.size),
    availability: "可按需获取",
  }));
}

function itemFor(asset: ExternalShareAsset): ContentItem {
  const domain = domainById(asset.domainId);
  const contentType = contentTypeFor(asset);
  const previewAssets = previewFor(asset);
  const sourceFiles = sourceFilesFor(asset);
  const needsPreview = !requirementDomains.has(asset.domainId);
  const integrity = needsPreview && previewAssets.length === 0
    ? "缺少预览"
    : sourceFiles.length === 0
      ? "缺少源文件"
      : "完整";
  const latestAction = asset.operations[0]?.action;

  return {
    id: `share-item-${asset.id}`,
    title: asset.name,
    entryType: domain.kind,
    change: latestAction === "上传" ? "新增" : latestAction === "修改" ? "修改" : "延续",
    owner: asset.owner,
    updated: `共享盘 · ${asset.updatedAt.slice(0, 10)}`,
    contentType,
    previewMode: requirementDomains.has(asset.domainId) ? (contentType === "sheet" ? "sheet" : "document") : "image",
    previewAssets,
    integrity,
    description: asset.description,
    tags: asset.tags,
    sourceFiles,
    relations: ["共享盘自动索引", `${asset.module} / ${asset.version}`],
    operations: asset.operations,
  };
}

function stableModuleId(domainId: string, moduleName: string) {
  return `share-module-${domainId}-${encodeURIComponent(moduleName)}`;
}

export function modulesFromExternalShare(share: ExternalShareIndex | null): ProjectModule[] {
  if (!share) return [];
  return share.modules.map((sharedModule) => {
    const assets = share.assets.filter((asset) => asset.domainId === sharedModule.domainId && asset.module === sharedModule.name);
    const domain = domainById(sharedModule.domainId);
    const sortedVersionRecords = [...sharedModule.versions].sort((a, b) => versionCollator.compare(b.label, a.label));
    const versions = sortedVersionRecords.map((versionRecord, index) => {
      const versionAssets = assets.filter((asset) => asset.version === versionRecord.label).sort((a, b) => a.name.localeCompare(b.name, "zh-CN"));
      const latestDate = versionAssets.map((asset) => asset.updatedAt.slice(0, 10)).sort().at(-1) ?? versionRecord.updatedAt.slice(0, 10);
      const state: VersionState = index === 0 ? "当前" : "历史";
      return {
        id: `${stableModuleId(sharedModule.domainId, sharedModule.name)}-${encodeURIComponent(versionRecord.label)}`,
        label: versionRecord.label,
        date: latestDate,
        state,
        summary: `${versionRecord.label} 从共享盘读取到 ${versionAssets.length} 条真实内容。`,
        items: versionAssets.map(itemFor),
      };
    });
    const items = versions.flatMap((version) => version.items);
    const currentVersion = versions[0]?.label ?? "待建版本";
    const firstAsset = assets[0];

    return {
      id: stableModuleId(sharedModule.domainId, sharedModule.name),
      domainId: sharedModule.domainId,
      name: sharedModule.name,
      description: `${domain.label}共享目录自动生成，模块、版本和内容来自真实文件路径。`,
      owner: firstAsset?.owner ?? "共享盘",
      updated: `共享盘 · ${sharedModule.updatedAt.slice(0, 10)}`,
      cover: assets.find((asset) => asset.previewUrl)?.previewUrl,
      currentVersion,
      status: versions.length === 0 || items.length === 0 || items.some((item) => item.integrity !== "完整") ? "待整理" : "正常",
      source: "共享盘",
      requirementCount: domain.kind === "需求" ? items.length : 0,
      outputCount: domain.kind === "需求" ? 0 : items.length,
      reusableCount: domain.kind === "生产资产" ? items.length : 0,
      versions,
    };
  }).sort((a, b) => {
    const domainOrder = a.domainId.localeCompare(b.domainId);
    return domainOrder || a.name.localeCompare(b.name, "zh-CN");
  });
}
