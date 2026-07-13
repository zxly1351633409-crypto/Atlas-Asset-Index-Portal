import { sql } from "drizzle-orm";
import { index, integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";

const timestamps = {
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  updatedAt: text("updated_at").notNull().default(sql`CURRENT_TIMESTAMP`),
};

export const workDomains = sqliteTable("work_domains", {
  id: text("id").primaryKey(),
  label: text("label").notNull(),
  kind: text("kind", { enum: ["需求", "产出", "生产资产"] }).notNull(),
  description: text("description").notNull().default(""),
  icon: text("icon").notNull().default("folder"),
  sortOrder: integer("sort_order").notNull().default(0),
  ...timestamps,
}, (table) => [uniqueIndex("work_domains_label_unique").on(table.label)]);

export const projectModules = sqliteTable("project_modules", {
  id: text("id").primaryKey(),
  domainId: text("domain_id").notNull().references(() => workDomains.id, { onDelete: "cascade" }),
  name: text("name").notNull(),
  description: text("description").notNull().default(""),
  owner: text("owner").notNull().default(""),
  status: text("status", { enum: ["正常", "制作中", "待整理"] }).notNull().default("正常"),
  currentVersionLabel: text("current_version_label").notNull().default("V1.0"),
  ...timestamps,
}, (table) => [
  uniqueIndex("project_modules_domain_name_unique").on(table.domainId, table.name),
  index("project_modules_domain_idx").on(table.domainId),
]);

export const moduleVersions = sqliteTable("module_versions", {
  id: text("id").primaryKey(),
  moduleId: text("module_id").notNull().references(() => projectModules.id, { onDelete: "cascade" }),
  label: text("label").notNull(),
  versionDate: text("version_date").notNull(),
  state: text("state", { enum: ["当前", "历史", "制作中"] }).notNull().default("制作中"),
  summary: text("summary").notNull().default(""),
  ...timestamps,
}, (table) => [
  uniqueIndex("module_versions_module_label_unique").on(table.moduleId, table.label),
  index("module_versions_module_date_idx").on(table.moduleId, table.versionDate),
]);

export const contentItems = sqliteTable("content_items", {
  id: text("id").primaryKey(),
  versionId: text("version_id").notNull().references(() => moduleVersions.id, { onDelete: "cascade" }),
  title: text("title").notNull(),
  contentType: text("content_type", { enum: ["visual", "model", "ui", "document", "sheet"] }).notNull(),
  entryType: text("entry_type", { enum: ["需求", "产出", "生产资产"] }).notNull(),
  changeState: text("change_state", { enum: ["新增", "修改", "延续", "待确认"] }).notNull().default("新增"),
  integrity: text("integrity", { enum: ["完整", "缺少预览", "缺少源文件", "路径待确认"] }).notNull().default("缺少源文件"),
  owner: text("owner").notNull().default(""),
  description: text("description").notNull().default(""),
  tagsJson: text("tags_json").notNull().default("[]"),
  ...timestamps,
}, (table) => [
  index("content_items_version_idx").on(table.versionId),
  index("content_items_type_idx").on(table.contentType),
  index("content_items_integrity_idx").on(table.integrity),
]);

export const previewAssets = sqliteTable("preview_assets", {
  id: text("id").primaryKey(),
  contentItemId: text("content_item_id").notNull().references(() => contentItems.id, { onDelete: "cascade" }),
  label: text("label").notNull(),
  format: text("format", { enum: ["JPG", "PNG", "WEBP"] }).notNull(),
  storage: text("storage", { enum: ["VS", "NAS"] }).notNull(),
  path: text("path").notNull(),
  size: text("size").notNull().default(""),
  previewUrl: text("preview_url"),
  sortOrder: integer("sort_order").notNull().default(0),
  ...timestamps,
}, (table) => [index("preview_assets_content_idx").on(table.contentItemId)]);

export const sourceFiles = sqliteTable("source_files", {
  id: text("id").primaryKey(),
  contentItemId: text("content_item_id").notNull().references(() => contentItems.id, { onDelete: "cascade" }),
  label: text("label").notNull(),
  format: text("format").notNull(),
  storage: text("storage", { enum: ["VS", "NAS", "工具链接"] }).notNull(),
  path: text("path").notNull(),
  size: text("size").notNull().default(""),
  availability: text("availability", { enum: ["可按需获取", "仅有预览", "路径待确认"] }).notNull().default("路径待确认"),
  sortOrder: integer("sort_order").notNull().default(0),
  ...timestamps,
}, (table) => [
  index("source_files_content_idx").on(table.contentItemId),
  index("source_files_path_idx").on(table.path),
]);

export const contentRelations = sqliteTable("content_relations", {
  id: text("id").primaryKey(),
  contentItemId: text("content_item_id").notNull().references(() => contentItems.id, { onDelete: "cascade" }),
  label: text("label").notNull(),
  targetType: text("target_type", { enum: ["content", "module", "requirement", "external"] }).notNull(),
  targetId: text("target_id"),
  ...timestamps,
}, (table) => [index("content_relations_content_idx").on(table.contentItemId)]);
