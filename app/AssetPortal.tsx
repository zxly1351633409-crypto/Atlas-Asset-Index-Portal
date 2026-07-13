"use client";

import {
  Archive, ArrowUpRight, Box, Check, ChevronLeft, ChevronRight, Download,
  CheckCircle2, CircleAlert, ClipboardPenLine, CloudDownload, Database, Eye, FileImage, FileText,
  FileUp, FolderOpen, History, Image as ImageIcon, LayoutGrid, Link2,
  Maximize2, Menu, Minus, Mountain, PanelsTopLeft, Plus, Search, SwatchBook,
  TableProperties, UserRound, Workflow, X, type LucideIcon,
} from "lucide-react";
import { useEffect, useMemo, useRef, useState, type InputHTMLAttributes } from "react";
import {
  domainById, modulesForDomain, projectModules, workDomains,
  type ContentItem, type ContentType, type ProjectModule, type SourceFile,
} from "./portal-data";

const domainIcons: Record<string, LucideIcon> = {
  mountain: Mountain,
  user: UserRound,
  "file-text": FileText,
  workflow: Workflow,
  clipboard: ClipboardPenLine,
  image: ImageIcon,
  panels: PanelsTopLeft,
  box: Box,
  swatch: SwatchBook,
};

const domainGroups = [
  { label: "内容与产出", ids: ["scene", "character", "illustration", "ui"] },
  { label: "需求", ids: ["writing-request", "system-request", "illustration-request"] },
  { label: "生产资产", ids: ["model", "material"] },
];

export function AssetPortal() {
  const [domainId, setDomainId] = useState("scene");
  const [moduleId, setModuleId] = useState<string | null>(null);
  const [versionId, setVersionId] = useState("V6.2");
  const [itemId, setItemId] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [addOpen, setAddOpen] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [toast, setToast] = useState("");
  const [previewItem, setPreviewItem] = useState<ContentItem | null>(null);

  const activeDomain = domainById(domainId);
  const activeModule = projectModules.find((item) => item.id === moduleId) ?? null;
  const activeVersion = activeModule?.versions.find((version) => version.label === versionId) ?? null;
  const activeItem = activeVersion?.items.find((item) => item.id === itemId) ?? activeVersion?.items[0] ?? null;

  const visibleModules = useMemo(() => {
    const key = query.trim().toLowerCase();
    return modulesForDomain(domainId).filter((module) => {
      const text = `${module.name} ${module.description} ${module.owner}`.toLowerCase();
      return !key || text.includes(key);
    });
  }, [domainId, query]);

  const selectDomain = (nextDomainId: string) => {
    setDomainId(nextDomainId);
    setModuleId(null);
    setVersionId("V6.2");
    setItemId(null);
    setQuery("");
    setSidebarOpen(false);
  };

  const openModule = (module: ProjectModule) => {
    const current = module.versions.find((version) => version.label === module.currentVersion) ?? module.versions[0];
    setModuleId(module.id);
    setVersionId(current.label);
    setItemId(current.items[0]?.id ?? null);
    setQuery("");
  };

  const openVersion = (module: ProjectModule, nextVersion: string) => {
    setVersionId(nextVersion);
    const version = module.versions.find((item) => item.label === nextVersion);
    setItemId(version?.items[0]?.id ?? null);
  };

  return (
    <div className="v2-shell">
      <header className="v2-topbar">
        <button className="top-icon mobile-only" aria-label="打开工作域导航" onClick={() => setSidebarOpen(true)}><Menu size={19} /></button>
        <div className="v2-brand"><span><Archive size={18} /></span><div><strong>ATLAS</strong><small>项目内容档案</small></div></div>
        <button className="project-switch"><span>PROJECT AURORA</span><small>当前发布 V6.2</small><ChevronRight size={15} /></button>
        <div className="v2-search">
          <Search size={17} />
          <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={activeModule ? "搜索当前版本内容" : `搜索${activeDomain.label}模块`} aria-label="搜索" />
          <kbd>Ctrl K</kbd>
        </div>
        <button className="add-button" onClick={() => setAddOpen(true)}><Plus size={17} />新增/关联内容</button>
        <div className="user-chip">DEMO</div>
      </header>

      <aside className={`domain-sidebar ${sidebarOpen ? "open" : ""}`}>
        <div className="sidebar-mobile-header"><strong>工作域</strong><button className="plain-icon" aria-label="关闭导航" onClick={() => setSidebarOpen(false)}><X size={18} /></button></div>
        <div className="sidebar-title"><span>工作域</span><small>按项目目标浏览</small></div>
        {domainGroups.map((group) => (
          <div className="domain-group" key={group.label}>
            <div className="domain-group-label">{group.label}</div>
            <nav aria-label={group.label}>
              {group.ids.map((id) => {
                const domain = domainById(id);
                const Icon = domainIcons[domain.icon] ?? FolderOpen;
                const count = modulesForDomain(domain.id).length;
                return (
                  <button className={domainId === domain.id ? "active" : ""} key={domain.id} onClick={() => selectDomain(domain.id)}>
                    <Icon size={17} /><span>{domain.label}</span><small>{count}</small>
                  </button>
                );
              })}
            </nav>
          </div>
        ))}
        <div className="connector-status">
          <div className="connector-title"><Database size={15} /><span>来源连接</span></div>
          <div><i className="online" /><span>VS 索引</span><small>模拟在线</small></div>
          <div><i className="online" /><span>NAS 索引</span><small>模拟在线</small></div>
          <p>网页只加载预览，源文件按需获取。</p>
        </div>
      </aside>

      <main className="v2-main">
        {activeModule ? (
          <ModuleWorkspace
            domainLabel={activeDomain.label}
            module={activeModule}
            versionId={versionId}
            activeItem={activeItem}
            onBack={() => { setModuleId(null); setItemId(null); setQuery(""); }}
            onVersion={(next) => openVersion(activeModule, next)}
            onOverview={() => { setVersionId("overview"); setItemId(null); }}
            onItem={setItemId}
            onPreview={setPreviewItem}
            onAdd={() => setAddOpen(true)}
            onRequestFile={(file) => setToast(`已创建“${file.format}”按需获取请求（本地模拟）`)}
          />
        ) : (
          <ModuleCatalog domainId={domainId} modules={visibleModules} onOpen={openModule} onAdd={() => setAddOpen(true)} />
        )}
      </main>

      {sidebarOpen && <button className="mobile-scrim" aria-label="关闭导航" onClick={() => setSidebarOpen(false)} />}
      {addOpen && <AddContentDialog initialDomainId={domainId} initialModuleId={moduleId} initialVersion={versionId === "overview" ? activeModule?.currentVersion : versionId} onClose={() => setAddOpen(false)} />}
      {previewItem && <PreviewDialog item={previewItem} version={activeVersion?.label ?? activeModule?.currentVersion ?? versionId} onClose={() => setPreviewItem(null)} onRequestFile={(file) => setToast(`已创建“${file.format}”高清文件获取请求（本地模拟）`)} />}
      {toast && <div className="toast" role="status"><Check size={16} /><span>{toast}</span><button aria-label="关闭提示" onClick={() => setToast("")}><X size={14} /></button></div>}
    </div>
  );
}

function ModuleCatalog({ domainId, modules, onOpen, onAdd }: { domainId: string; modules: ProjectModule[]; onOpen: (module: ProjectModule) => void; onAdd: () => void }) {
  const domain = domainById(domainId);
  const Icon = domainIcons[domain.icon] ?? FolderOpen;
  return (
    <section className="module-catalog">
      <div className="crumbs"><span>PROJECT AURORA</span><ChevronRight size={13} /><strong>{domain.label}</strong></div>
      <div className="catalog-head">
        <div className="catalog-title"><span className="domain-emblem"><Icon size={22} /></span><div><h1>{domain.label}</h1><p>{domain.description}。选择模块后进入版本工作区。</p></div></div>
        <button className="secondary-action" onClick={onAdd}><Plus size={16} />新增模块内容</button>
      </div>
      <div className="module-list-head"><div><LayoutGrid size={16} /><strong>模块</strong><span>{modules.length}</span></div></div>
      <div className="module-grid">
        {modules.map((module) => (
          <button className="module-card" key={module.id} onClick={() => onOpen(module)}>
            <div className={`module-cover ${module.cover ? "" : "document-cover"}`}>
              {module.cover ? <img src={module.cover} alt={`${module.name}模块封面`} /> : <><Icon size={34} /><span>{domain.kind}</span></>}
              <span className={`module-state state-${module.status}`}>{module.status}</span>
            </div>
            <div className="module-body">
              <div className="module-title-line"><strong>{module.name}</strong><span>{module.currentVersion}</span></div>
              <p>{module.description}</p>
              <div className="module-footer"><span>{module.owner} · {module.updated}</span><span><History size={13} />{module.versions.length} 个版本<ChevronRight size={14} /></span></div>
            </div>
          </button>
        ))}
        {modules.length === 0 && <div className="catalog-empty"><Search size={24} /><strong>没有匹配的模块</strong><p>清除搜索词或切换工作域。</p></div>}
      </div>
    </section>
  );
}

type WorkspaceProps = {
  domainLabel: string;
  module: ProjectModule;
  versionId: string;
  activeItem: ContentItem | null;
  onBack: () => void;
  onVersion: (version: string) => void;
  onOverview: () => void;
  onItem: (id: string) => void;
  onPreview: (item: ContentItem) => void;
  onAdd: () => void;
  onRequestFile: (file: SourceFile) => void;
};

function ModuleWorkspace({ domainLabel, module, versionId, activeItem, onBack, onVersion, onOverview, onItem, onPreview, onAdd, onRequestFile }: WorkspaceProps) {
  const version = module.versions.find((item) => item.label === versionId);
  return (
    <section className="module-workspace">
      <div className="workspace-crumbs"><button onClick={onBack}><ChevronLeft size={15} />{domainLabel}模块</button><ChevronRight size={13} /><span>{module.name}</span></div>
      <div className="workspace-head">
        <div><div className="workspace-title-line"><h1>{module.name}</h1><span>{module.status}</span></div><p>{module.description}</p></div>
        <button className="add-button" onClick={onAdd}><Plus size={17} />新增/关联到此模块</button>
      </div>
      <div className="version-rail-wrap">
        <div className="version-rail-label">
          <History size={15} /><span>版本轴</span>
          <small>{module.versions.at(-1)?.date} 至 {module.versions[0]?.date}</small>
        </div>
        <div className="version-rail" role="tablist" aria-label="模块版本">
          <button className={versionId === "overview" ? "active overview" : "overview"} onClick={onOverview}><LayoutGrid size={14} /><span>总览</span></button>
          <div className="version-track">
            {module.versions.slice().reverse().map((item) => (
              <button className={`timeline-stop stop-${item.state} ${versionId === item.label ? "active" : ""}`} key={item.id} onClick={() => onVersion(item.label)}>
                <time>{item.date.slice(5).replace("-", ".")}</time>
                <i className="timeline-marker" />
                <strong>{item.label}</strong><small>{item.state}</small>
              </button>
            ))}
          </div>
        </div>
      </div>

      {versionId === "overview" ? (
        <ModuleOverview module={module} onVersion={onVersion} />
      ) : version ? (
        <>
          <div className="version-context">
            <div><span className={`version-state version-${version.state}`}>{version.state}</span><div><strong>{version.label} 内容</strong><p>{version.summary}</p></div></div>
          </div>
          <div className="workspace-content">
            <section className="content-items">
              <div className="content-items-head"><div><strong>内容</strong><span>{version.items.length}</span></div></div>
              <div className="content-grid">
                {version.items.map((item) => (
                  <button className={`content-card ${activeItem?.id === item.id ? "selected" : ""}`} key={item.id} onClick={() => onItem(item.id)} onDoubleClick={() => onPreview(item)}>
                    <div className={`content-preview ${item.previewAssets[0] ? "" : "document-preview"}`}>
                      {item.previewAssets[0] ? <img src={item.previewAssets[0].url} alt={`${item.title}预览`} /> : item.previewMode === "sheet" ? <><TableProperties size={31} /><span>需求表格</span></> : <><FileText size={31} /><span>需求文档</span></>}
                      <span className={`change-badge change-${item.change}`}>{item.change}</span>
                      <span className="preview-glyph" title="预览"><Maximize2 size={15} /></span>
                    </div>
                    <div className="content-card-body"><strong>{item.title}</strong><p>{item.description}</p><div><span>{item.owner}</span><span>{item.updated}</span></div></div>
                  </button>
                ))}
              </div>
            </section>
            {activeItem && <ItemInspector item={activeItem} version={version.label} onRequestFile={onRequestFile} />}
          </div>
        </>
      ) : null}
    </section>
  );
}

function ModuleOverview({ module, onVersion }: { module: ProjectModule; onVersion: (version: string) => void }) {
  const latest = module.versions[0];
  return (
    <div className="module-overview">
      <div className="overview-summary">
        <div><span>当前有效版本</span><strong>{module.currentVersion}</strong><small>{latest.date}</small></div>
        <div><span>关联需求</span><strong>{module.requirementCount}</strong><small>已建立关系</small></div>
        <div><span>产出条目</span><strong>{module.outputCount}</strong><small>跨全部版本</small></div>
        <div><span>可复用内容</span><strong>{module.reusableCount}</strong><small>人工确认</small></div>
      </div>
      <div className="overview-columns">
        <section>
          <div className="overview-section-head"><div><History size={16} /><strong>版本记录</strong></div><small>点击进入版本</small></div>
          <div className="version-list">
            {module.versions.map((version) => (
              <button key={version.id} onClick={() => onVersion(version.label)}>
                <span className={`version-dot dot-${version.state}`} /><div><strong>{version.label}</strong><small>{version.summary}</small></div><time>{version.date}</time><ChevronRight size={15} />
              </button>
            ))}
          </div>
        </section>
        <aside>
          <div className="overview-section-head"><div><ArrowUpRight size={16} /><strong>最近变更</strong></div></div>
          <ul>{latest.items.map((item) => <li key={item.id}><span className={`change-badge change-${item.change}`}>{item.change}</span><div><strong>{item.title}</strong><small>{item.owner} · {item.updated}</small></div></li>)}</ul>
        </aside>
      </div>
    </div>
  );
}

function ItemInspector({ item, version, onRequestFile }: { item: ContentItem; version: string; onRequestFile: (file: SourceFile) => void }) {
  const preview = item.previewAssets[0];
  const IntegrityIcon = item.integrity === "完整" ? CheckCircle2 : CircleAlert;
  return (
    <aside className="item-inspector">
      <div className={`inspector-hero ${preview ? "" : "document-hero"}`}>
        {preview ? <img src={preview.url} alt={`${item.title}详情预览`} /> : item.previewMode === "sheet" ? <><TableProperties size={40} /><span>需求表格</span></> : <><FileText size={40} /><span>需求文档</span></>}
      </div>
      <div className="inspector-title"><div><span>{item.entryType} · {version}</span><h2>{item.title}</h2></div><span className={`change-badge change-${item.change}`}>{item.change}</span></div>
      <p className="inspector-description">{item.description}</p>
      <dl className="item-meta"><div><dt>负责人</dt><dd>{item.owner}</dd></div><div><dt>更新时间</dt><dd>{item.updated}</dd></div><div><dt>关系</dt><dd>{item.relations.length} 项</dd></div></dl>
      <div className="source-heading"><div><CloudDownload size={16} /><strong>可获取文件</strong></div><span className={`integrity-pill integrity-${item.integrity}`}><IntegrityIcon size={13} />{item.integrity}</span></div>
      <div className="source-file-list">
        {preview && <a href={preview.url} download={`${item.title}-preview.${preview.format.toLowerCase()}`}><span className="format-tile">{preview.format}</span><span className="source-copy"><strong>{preview.label}</strong><small>{preview.storage} · {preview.size}</small><code>{preview.path}</code></span><span className="source-action"><Download size={16} /><small>下载</small></span></a>}
        {item.sourceFiles.map((file) => (
          <button key={file.id} onClick={() => onRequestFile(file)}>
            <span className="format-tile">{file.format}</span>
            <span className="source-copy"><strong>{file.label}</strong><small>{file.storage} · {file.size}</small><code>{file.path}</code></span>
            <span className="source-action"><CloudDownload size={16} /><small>获取</small></span>
          </button>
        ))}
      </div>
      <div className="preview-policy"><Eye size={15} /><p>当前页面只加载轻量预览。选择具体格式后，系统才会从 VS 或 NAS 获取源文件。</p></div>
      <div className="relation-list"><strong>关联关系</strong>{item.relations.map((relation) => <span key={relation}><Link2 size={13} />{relation}</span>)}</div>
    </aside>
  );
}

function PreviewDialog({ item, version, onClose, onRequestFile }: { item: ContentItem; version: string; onClose: () => void; onRequestFile: (file: SourceFile) => void }) {
  const [zoom, setZoom] = useState(1);
  const preview = item.previewAssets[0];
  const preferredFormats = item.previewMode === "sheet" ? ["XLSX"] : item.previewMode === "document" ? ["DOCX"] : ["JPG", "PNG"];
  const primaryFile = item.sourceFiles.find((file) => preferredFormats.includes(file.format)) ?? item.sourceFiles[0];

  useEffect(() => {
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [onClose]);

  return (
    <div className="preview-overlay" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <div className="preview-window" role="dialog" aria-modal="true" aria-labelledby="preview-title">
        <header className="preview-toolbar">
          <div><span>{item.entryType} · {version}</span><strong id="preview-title">{item.title}</strong></div>
          <div className="preview-tools">
            {preview && <>
              <button title="缩小" aria-label="缩小" onClick={() => setZoom((value) => Math.max(.75, value - .25))}><Minus size={17} /></button>
              <span>{Math.round(zoom * 100)}%</span>
              <button title="放大" aria-label="放大" onClick={() => setZoom((value) => Math.min(2, value + .25))}><Plus size={17} /></button>
            </>}
            <button title="关闭" aria-label="关闭预览" onClick={onClose}><X size={19} /></button>
          </div>
        </header>
        <div className={`preview-canvas ${preview ? "image-canvas" : item.previewMode === "sheet" ? "sheet-canvas" : "document-canvas"}`}>
          {preview ? (
            <img src={preview.url} alt={`${item.title}大图预览`} style={{ transform: `scale(${zoom})` }} />
          ) : item.previewMode === "sheet" ? (
            <LiveSheetPreview item={item} version={version} />
          ) : (
            <article className="live-document">
              <header><span>{version} · {item.entryType}</span><h1>{item.title}</h1><p>{item.description}</p></header>
              <section><h2>目标</h2><p>明确本条需求在当前模块中的目标、适用范围和交付边界，并作为后续产出的关联依据。</p></section>
              <section><h2>需求内容</h2><ul>{item.tags.map((tag) => <li key={tag}><Check size={15} />完成与“{tag}”相关的内容确认</li>)}</ul></section>
              <section><h2>关联与验收</h2><ul>{item.relations.map((relation) => <li key={relation}><Link2 size={15} />{relation}</li>)}</ul></section>
              <footer><span>负责人：{item.owner}</span><span>更新：{item.updated}</span></footer>
            </article>
          )}
        </div>
        <footer className="preview-footer">
          <div className="preview-file-strip">
            {preview && <a href={preview.url} download={`${item.title}-preview.${preview.format.toLowerCase()}`}><span>{preview.format}</span><div><strong>{preview.label}</strong><small>预览文件 · {preview.size}</small></div></a>}
            {item.sourceFiles.map((file) => <button key={file.id} onClick={() => onRequestFile(file)}><span>{file.format}</span><div><strong>{file.label}</strong><small>{file.storage} · {file.size}</small></div></button>)}
          </div>
          <div className="preview-primary-actions">
            {preview && <a href={preview.url} download={`${item.title}-preview.${preview.format.toLowerCase()}`}><Download size={16} />下载当前预览</a>}
            {primaryFile && <button onClick={() => onRequestFile(primaryFile)}><CloudDownload size={16} />获取 {primaryFile.format}{preview ? " 源文件" : ""}</button>}
          </div>
        </footer>
      </div>
    </div>
  );
}

function LiveSheetPreview({ item, version }: { item: ContentItem; version: string }) {
  const rows = [
    ["REQ-01", item.title, item.owner, "已确认"],
    ["REQ-02", `${item.tags[1] ?? "模块"}交付范围`, item.owner, "评审中"],
    ["REQ-03", "关联产出与验收标准", "待分配", "待处理"],
    ["REQ-04", "异常情况与补充说明", item.owner, "待确认"],
  ];
  return (
    <section className="live-sheet">
      <header><div><TableProperties size={19} /><strong>{item.title}</strong></div><span>{version} · 需求清单</span></header>
      <div className="sheet-grid">
        <table>
          <thead><tr><th>编号</th><th>需求项</th><th>负责人</th><th>状态</th></tr></thead>
          <tbody>{rows.map((row) => <tr key={row[0]}>{row.map((cell, index) => <td key={cell} className={index === 3 ? "sheet-status" : ""}>{cell}</td>)}</tr>)}</tbody>
        </table>
      </div>
      <footer><span>需求清单</span><small>更新：{item.updated}</small></footer>
    </section>
  );
}

type CustomDomain = { id: string; label: string };
type CustomModule = { id: string; domainId: string; name: string };
type CustomVersion = { moduleId: string; label: string };
type UploadKind = "preview" | "design" | "project" | "document";
type PendingUpload = { id: string; name: string; relativePath: string; kind: UploadKind };

const contentTypeOptions: Array<{ id: ContentType; label: string; formats: string; icon: LucideIcon }> = [
  { id: "visual", label: "视觉内容", formats: "JPG / PSD / 3D", icon: FileImage },
  { id: "model", label: "模型", formats: "JPG / 3D 工程", icon: Box },
  { id: "ui", label: "UI", formats: "PNG + PSD / 链接", icon: PanelsTopLeft },
  { id: "document", label: "文档需求", formats: "DOCX", icon: FileText },
  { id: "sheet", label: "表格需求", formats: "XLSX", icon: TableProperties },
];

function contentTypeForDomain(domainId: string): ContentType {
  if (domainId === "model") return "model";
  if (domainId === "ui") return "ui";
  if (["writing-request", "system-request", "illustration-request"].includes(domainId)) return "document";
  return "visual";
}

function AddContentDialog({ initialDomainId, initialModuleId, initialVersion, onClose }: { initialDomainId: string; initialModuleId: string | null; initialVersion?: string; onClose: () => void }) {
  const [domainId, setDomainId] = useState(initialDomainId);
  const [contentType, setContentType] = useState<ContentType>(contentTypeForDomain(initialDomainId));
  const [customDomains, setCustomDomains] = useState<CustomDomain[]>([]);
  const [customModules, setCustomModules] = useState<CustomModule[]>([]);
  const [customVersions, setCustomVersions] = useState<CustomVersion[]>([]);
  const [creatingLevel, setCreatingLevel] = useState<"domain" | "module" | "version" | null>(null);
  const [newLevelName, setNewLevelName] = useState("");
  const [showLocation, setShowLocation] = useState(false);
  const initialModules = modulesForDomain(initialDomainId);
  const [moduleId, setModuleId] = useState(initialModuleId && projectModules.some((module) => module.id === initialModuleId) ? initialModuleId : initialModules[0]?.id ?? "");
  const selectedModule = projectModules.find((module) => module.id === moduleId);
  const selectedCustomModule = customModules.find((module) => module.id === moduleId);
  const [version, setVersion] = useState(initialVersion ?? selectedModule?.currentVersion ?? "V6.2");
  const [title, setTitle] = useState("");
  const [path, setPath] = useState("");
  const [attachedFiles, setAttachedFiles] = useState<PendingUpload[]>([]);
  const [created, setCreated] = useState(false);
  const previewInputRef = useRef<HTMLInputElement>(null);
  const designInputRef = useRef<HTMLInputElement>(null);
  const projectInputRef = useRef<HTMLInputElement>(null);
  const documentInputRef = useRef<HTMLInputElement>(null);
  const domainOptions = [...workDomains.map((domain) => ({ id: domain.id, label: domain.label })), ...customDomains];
  const moduleOptions = [
    ...modulesForDomain(domainId).map((module) => ({ id: module.id, name: module.name })),
    ...customModules.filter((module) => module.domainId === domainId).map((module) => ({ id: module.id, name: module.name })),
  ];
  const versionOptions = [
    ...(selectedModule?.versions.map((item) => ({ label: item.label, state: item.state })) ?? []),
    ...customVersions.filter((item) => item.moduleId === moduleId).map((item) => ({ label: item.label, state: "新建" })),
  ];

  const changeDomain = (nextDomainId: string) => {
    setDomainId(nextDomainId);
    setContentType(contentTypeForDomain(nextDomainId));
    setAttachedFiles([]);
    const first = modulesForDomain(nextDomainId)[0];
    const firstCustom = customModules.find((module) => module.domainId === nextDomainId);
    setModuleId(first?.id ?? firstCustom?.id ?? "");
    setVersion(first?.currentVersion ?? (firstCustom ? customVersions.find((item) => item.moduleId === firstCustom.id)?.label : undefined) ?? "V1.0");
  };

  const changeModule = (nextModuleId: string) => {
    setModuleId(nextModuleId);
    const next = projectModules.find((module) => module.id === nextModuleId);
    setVersion(next?.currentVersion ?? customVersions.find((item) => item.moduleId === nextModuleId)?.label ?? "V1.0");
  };

  const beginCreate = (level: "domain" | "module" | "version") => {
    setCreatingLevel(level);
    setNewLevelName(level === "version" ? "V6.3" : "");
    setCreated(false);
  };

  const commitCreate = () => {
    const name = newLevelName.trim();
    if (!name || !creatingLevel) return;
    const token = Date.now().toString(36);
    if (creatingLevel === "domain") {
      const next = { id: `custom-domain-${token}`, label: name };
      setCustomDomains((items) => [...items, next]);
      setDomainId(next.id);
      setModuleId("");
      setVersion("V1.0");
    } else if (creatingLevel === "module") {
      const next = { id: `custom-module-${token}`, domainId, name };
      setCustomModules((items) => [...items, next]);
      setCustomVersions((items) => [...items, { moduleId: next.id, label: "V1.0" }]);
      setModuleId(next.id);
      setVersion("V1.0");
    } else if (moduleId) {
      const alreadyExists = versionOptions.some((item) => item.label === name);
      if (!alreadyExists) setCustomVersions((items) => [...items, { moduleId, label: name }]);
      setVersion(name);
    }
    setCreatingLevel(null);
    setNewLevelName("");
  };

  const typeRule = contentTypeOptions.find((item) => item.id === contentType)!;
  const hasFiles = attachedFiles.length > 0;
  const isRequirementFile = contentType === "document" || contentType === "sheet";
  const countByKind = (kind: UploadKind) => attachedFiles.filter((file) => file.kind === kind).length;
  const projectRoot = attachedFiles.find((file) => file.kind === "project")?.relativePath.split("/")[0];
  const integrity = hasFiles ? "完整" : path.trim() ? "路径待确认" : ["document", "sheet"].includes(contentType) ? "缺少源文件" : "缺少预览";
  const canCreate = Boolean(title.trim() && moduleId && (hasFiles || path.trim()));
  const selectedDomainLabel = domainOptions.find((domain) => domain.id === domainId)?.label ?? "未选择工作域";
  const selectedModuleName = selectedModule?.name ?? selectedCustomModule?.name ?? "未选择模块";

  const selectContentType = (nextType: ContentType) => {
    setContentType(nextType);
    setAttachedFiles([]);
    setCreated(false);
  };

  const addSelectedFiles = (files: FileList | null, kind: UploadKind) => {
    if (!files?.length) return;
    const incoming = Array.from(files).map((file) => ({
      id: `${kind}-${file.webkitRelativePath || file.name}-${file.size}-${file.lastModified}`,
      name: file.name,
      relativePath: file.webkitRelativePath || file.name,
      kind,
    }));
    setAttachedFiles((current) => {
      const merged = new Map(current.map((file) => [file.id, file]));
      incoming.forEach((file) => merged.set(file.id, file));
      return Array.from(merged.values());
    });
    setCreated(false);
  };

  const clearUploadKind = (kind: UploadKind) => {
    setAttachedFiles((files) => files.filter((file) => file.kind !== kind));
    setCreated(false);
  };

  return (
    <div className="dialog-scrim" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <div className="add-dialog compact-dialog" role="dialog" aria-modal="true" aria-labelledby="add-dialog-title">
        <header><div><span>内容登记</span><h2 id="add-dialog-title">新增内容</h2></div><button className="plain-icon" aria-label="关闭" onClick={onClose}><X size={19} /></button></header>
        <div className="dialog-form compact-form">
          <label>名称<input autoFocus value={title} onChange={(event) => { setTitle(event.target.value); setCreated(false); }} placeholder={`例如：${selectedModule?.versions[0]?.items[0]?.title ?? "输入内容名称"}`} /></label>
          <div className="location-summary"><FolderOpen size={17} /><span><small>归属</small><strong>{selectedDomainLabel} / {selectedModuleName} / {version}</strong></span><button type="button" onClick={() => setShowLocation((value) => !value)}>{showLocation ? "收起" : "修改"}<ChevronRight size={14} /></button></div>
          {showLocation && <div className="location-editor">
            <div className="three-fields">
              <label>工作域<div className="select-with-add"><select value={domainId} onChange={(event) => changeDomain(event.target.value)}>{domainOptions.map((domain) => <option value={domain.id} key={domain.id}>{domain.label}</option>)}</select><button type="button" title="新增工作域" aria-label="新增工作域" onClick={() => beginCreate("domain")}><Plus size={16} /></button></div></label>
              <label>模块<div className="select-with-add"><select value={moduleId} onChange={(event) => changeModule(event.target.value)}><option value="" disabled>请选择模块</option>{moduleOptions.map((module) => <option value={module.id} key={module.id}>{module.name}</option>)}</select><button type="button" title="新增模块" aria-label="新增模块" onClick={() => beginCreate("module")}><Plus size={16} /></button></div></label>
              <label>版本<div className="select-with-add"><select value={version} onChange={(event) => setVersion(event.target.value)}>{versionOptions.length === 0 && <option value="V1.0">V1.0</option>}{versionOptions.map((item) => <option value={item.label} key={`${moduleId}-${item.label}`}>{item.label} · {item.state}</option>)}</select><button type="button" title="新增版本" aria-label="新增版本" disabled={!moduleId} onClick={() => beginCreate("version")}><Plus size={16} /></button></div></label>
            </div>
            {creatingLevel && <div className="structure-create-row"><input autoFocus value={newLevelName} onChange={(event) => setNewLevelName(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") commitCreate(); }} placeholder={`输入${creatingLevel === "domain" ? "工作域" : creatingLevel === "module" ? "模块" : "版本"}名称`} /><button type="button" className="confirm" aria-label="确认新增" disabled={!newLevelName.trim()} onClick={commitCreate}><Check size={16} /></button><button type="button" aria-label="取消新增" onClick={() => setCreatingLevel(null)}><X size={16} /></button></div>}
          </div>}
          <label>类型<select value={contentType} onChange={(event) => selectContentType(event.target.value as ContentType)}>{contentTypeOptions.map((option) => <option value={option.id} key={option.id}>{option.label} · {option.formats}</option>)}</select></label>
          {isRequirementFile ? (
            <div className="upload-choice-grid single">
              <button className={countByKind("document") ? "selected" : ""} type="button" onClick={() => documentInputRef.current?.click()}><FileText size={18} /><span><strong>{contentType === "document" ? "DOCX 文档" : "XLSX 表格"}</strong><small>{countByKind("document") ? `${countByKind("document")} 个已选择` : typeRule.formats}</small></span></button>
            </div>
          ) : (
            <div className="upload-choice-grid">
              <button className={countByKind("preview") ? "selected" : ""} type="button" onClick={() => previewInputRef.current?.click()}><FileImage size={18} /><span><strong>JPG / PNG</strong><small>{countByKind("preview") ? `${countByKind("preview")} 个已选择` : "可多选"}</small></span></button>
              <button className={countByKind("design") ? "selected" : ""} type="button" onClick={() => designInputRef.current?.click()}><Archive size={18} /><span><strong>PSD 源文件</strong><small>{countByKind("design") ? `${countByKind("design")} 个已选择` : "可多选"}</small></span></button>
              <button className={countByKind("project") ? "selected" : ""} type="button" onClick={() => projectInputRef.current?.click()}><Box size={18} /><span><strong>3D 工程</strong><small>{projectRoot || "选择文件夹"}</small></span></button>
            </div>
          )}
          <label className="path-link"><Link2 size={16} /><input value={path} onChange={(event) => { setPath(event.target.value); setCreated(false); }} placeholder="已有资源可直接粘贴 VS / NAS 路径" /></label>
          <input ref={previewInputRef} hidden type="file" multiple accept=".jpg,.jpeg,.png,.webp" onChange={(event) => { addSelectedFiles(event.currentTarget.files, "preview"); event.currentTarget.value = ""; }} />
          <input ref={designInputRef} hidden type="file" multiple accept=".psd,.psb,.ai" onChange={(event) => { addSelectedFiles(event.currentTarget.files, "design"); event.currentTarget.value = ""; }} />
          <input ref={projectInputRef} hidden type="file" multiple {...({ webkitdirectory: "", directory: "" } as InputHTMLAttributes<HTMLInputElement>)} onChange={(event) => { addSelectedFiles(event.currentTarget.files, "project"); event.currentTarget.value = ""; }} />
          <input ref={documentInputRef} hidden type="file" multiple accept={contentType === "document" ? ".docx" : ".xlsx"} onChange={(event) => { addSelectedFiles(event.currentTarget.files, "document"); event.currentTarget.value = ""; }} />
          {hasFiles && <div className="attached-files">
            {countByKind("preview") > 0 && <span><FileImage size={13} />预览图 {countByKind("preview")}<button aria-label="移除预览图" onClick={() => clearUploadKind("preview")}><X size={12} /></button></span>}
            {countByKind("design") > 0 && <span><Archive size={13} />PSD {countByKind("design")}<button aria-label="移除 PSD" onClick={() => clearUploadKind("design")}><X size={12} /></button></span>}
            {countByKind("project") > 0 && <span><Box size={13} />3D 工程 {countByKind("project")} 个文件<button aria-label="移除 3D 工程" onClick={() => clearUploadKind("project")}><X size={12} /></button></span>}
            {countByKind("document") > 0 && <span><FileText size={13} />{typeRule.label} {countByKind("document")}<button aria-label="移除需求文件" onClick={() => clearUploadKind("document")}><X size={12} /></button></span>}
          </div>}
          {created && <div className="dialog-success"><Check size={16} />已创建 · {integrity}</div>}
        </div>
        <footer><button className="secondary-action" onClick={onClose}>取消</button><button className="add-button" disabled={!canCreate} onClick={() => setCreated(true)}>{created ? "已完成" : "创建内容记录"}<ChevronRight size={16} /></button></footer>
      </div>
    </div>
  );
}
