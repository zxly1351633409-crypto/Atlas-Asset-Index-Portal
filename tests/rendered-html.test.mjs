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
  assert.match(html, /新增\/关联内容/);
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
});
