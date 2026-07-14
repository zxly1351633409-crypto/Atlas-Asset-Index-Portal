import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", { headers: { accept: "text/html" } }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("server-renders the Atlas portal", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /Atlas/i);
  assert.match(html, /PROJECT AURORA/);
  assert.match(html, /工作域/);
  assert.match(html, /新增内容/);
  assert.match(html, /林澈/);
  assert.match(html, /场景美术/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape|Codex is working/i);
});

test("keeps preview assets separate from source files", async () => {
  const [dataModel, schema] = await Promise.all([
    readFile(new URL("../app/portal-data.ts", import.meta.url), "utf8"),
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
  ]);

  assert.match(dataModel, /previewAssets:\s*PreviewAsset\[\]/);
  assert.match(dataModel, /sourceFiles:\s*SourceFile\[\]/);
  assert.match(dataModel, /模型渲染预览/);
  assert.doesNotMatch(dataModel, /format:\s*"PDF"/);
  assert.match(schema, /sqliteTable\("preview_assets"/);
  assert.match(schema, /sqliteTable\("source_files"/);
  assert.match(schema, /sqliteTable\("content_items"/);
  assert.match(schema, /sqliteTable\("users"/);
  assert.match(schema, /sqliteTable\("domain_permissions"/);
  assert.match(schema, /sqliteTable\("audit_logs"/);
  assert.match(schema, /sqliteTable\("asset_operations"/);
  assert.match(schema, /sqliteTable\("asset_snapshots"/);
  assert.match(schema, /lifecycleStatus: text\("lifecycle_status"/);
});

test("models rollback as an append-only operation", async () => {
  const [portal, dataModel] = await Promise.all([
    readFile(new URL("../app/AssetPortal.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/portal-data.ts", import.meta.url), "utf8"),
  ]);

  assert.match(dataModel, /AssetOperationAction = "上传" \| "修改" \| "删除" \| "回溯"/);
  assert.match(dataModel, /operations:\s*AssetOperation\[\]/);
  assert.match(portal, /操作变更轴/);
  assert.match(portal, /删除不抹除历史，回溯会创建新修订/);
  assert.match(portal, /setOperations\(\(current\) => \[restored, \.\.\.current\]\)/);
  assert.match(portal, /operationOverrides/);
});

test("keeps enterprise connector probes safe by default", async () => {
  const [portal, connectorConfig, companyProbe, shareScanner, tfvcWorkspace, domainMap, externalShare, syncTest] = await Promise.all([
    readFile(new URL("../app/AssetPortal.tsx", import.meta.url), "utf8"),
    readFile(new URL("../config/connectors.example.json", import.meta.url), "utf8"),
    readFile(new URL("../tools/local-lab/Test-CompanyConnectors.ps1", import.meta.url), "utf8"),
    readFile(new URL("../tools/local-lab/Scan-ExternalContentShare.ps1", import.meta.url), "utf8"),
    readFile(new URL("../tools/local-lab/Configure-TfvcWorkspace.ps1", import.meta.url), "utf8"),
    readFile(new URL("../config/external-content-domains.json", import.meta.url), "utf8"),
    readFile(new URL("../app/external-share.ts", import.meta.url), "utf8"),
    readFile(new URL("../tools/local-lab/Test-ExternalContentSync.ps1", import.meta.url), "utf8"),
  ]);

  assert.match(portal, /canUploadToActiveDomain/);
  assert.match(portal, /canManageStructure/);
  assert.match(portal, /当前只能上传到/);
  assert.match(connectorConfig, /"mode": "read-only-pilot"/);
  assert.match(connectorConfig, /"sourceDownload": "on-demand"/);
  assert.match(connectorConfig, /"mode": "metadata-and-preview-only"/);
  assert.match(companyProbe, /\[switch\]\$AllowNasWriteProbe/);
  assert.match(portal, /external-content-share\.json/);
  assert.doesNotMatch(portal, /projectModules/);
  assert.match(shareScanner, /external-content-share\.json/);
  assert.match(shareScanner, /external-content-state\.json/);
  assert.match(shareScanner, /sourceFiles/);
  assert.match(shareScanner, /fingerprint/);
  assert.match(shareScanner, /previewIsDedicated/);
  assert.match(shareScanner, /modules = @\(\$moduleRecords\)/);
  assert.match(shareScanner, /\$segments\.Count -lt 3/);
  assert.equal(JSON.parse(domainMap).domains.length, 9);
  assert.match(externalShare, /modulesFromExternalShare/);
  assert.match(externalShare, /source: "共享盘"/);
  assert.match(syncTest, /Create synchronization failed/);
  assert.match(syncTest, /Modify synchronization failed/);
  assert.match(syncTest, /Delete synchronization failed/);
  assert.match(tfvcWorkspace, /\[switch\]\$Apply/);
  assert.match(tfvcWorkspace, /\[switch\]\$GetLatest/);
  assert.match(tfvcWorkspace, /GetLatest = "Skipped/);
});
