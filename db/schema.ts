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

export const teams = sqliteTable("teams", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  description: text("description").notNull().default(""),
  ...timestamps,
}, (table) => [uniqueIndex("teams_name_unique").on(table.name)]);

export const users = sqliteTable("users", {
  id: text("id").primaryKey(),
  externalId: text("external_id"),
  identityProvider: text("identity_provider", { enum: ["local-demo", "windows-ad", "entra-id"] }).notNull().default("local-demo"),
  email: text("email"),
  name: text("name").notNull(),
  jobTitle: text("job_title").notNull().default(""),
  teamId: text("team_id").references(() => teams.id, { onDelete: "set null" }),
  status: text("status", { enum: ["启用", "停用"] }).notNull().default("启用"),
  ...timestamps,
}, (table) => [
  uniqueIndex("users_external_identity_unique").on(table.identityProvider, table.externalId),
  uniqueIndex("users_email_unique").on(table.email),
  index("users_team_idx").on(table.teamId),
]);

export const roles = sqliteTable("roles", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  description: text("description").notNull().default(""),
  ...timestamps,
}, (table) => [uniqueIndex("roles_name_unique").on(table.name)]);

export const userRoles = sqliteTable("user_roles", {
  id: text("id").primaryKey(),
  userId: text("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  roleId: text("role_id").notNull().references(() => roles.id, { onDelete: "cascade" }),
  ...timestamps,
}, (table) => [
  uniqueIndex("user_roles_user_role_unique").on(table.userId, table.roleId),
  index("user_roles_user_idx").on(table.userId),
]);

export const domainPermissions = sqliteTable("domain_permissions", {
  id: text("id").primaryKey(),
  principalType: text("principal_type", { enum: ["user", "team", "role"] }).notNull(),
  principalId: text("principal_id").notNull(),
  domainId: text("domain_id").notNull().references(() => workDomains.id, { onDelete: "cascade" }),
  canRead: integer("can_read", { mode: "boolean" }).notNull().default(true),
  canUpload: integer("can_upload", { mode: "boolean" }).notNull().default(false),
  canDownload: integer("can_download", { mode: "boolean" }).notNull().default(true),
  canReview: integer("can_review", { mode: "boolean" }).notNull().default(false),
  canManage: integer("can_manage", { mode: "boolean" }).notNull().default(false),
  ...timestamps,
}, (table) => [
  uniqueIndex("domain_permissions_principal_domain_unique").on(table.principalType, table.principalId, table.domainId),
  index("domain_permissions_domain_idx").on(table.domainId),
]);

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
  lifecycleStatus: text("lifecycle_status", { enum: ["active", "deleted", "archived"] }).notNull().default("active"),
  deletedAt: text("deleted_at"),
  deletedByUserId: text("deleted_by_user_id").references(() => users.id, { onDelete: "set null" }),
  ...timestamps,
}, (table) => [
  index("content_items_version_idx").on(table.versionId),
  index("content_items_type_idx").on(table.contentType),
  index("content_items_integrity_idx").on(table.integrity),
  index("content_items_lifecycle_idx").on(table.lifecycleStatus),
]);

export const assetOperations = sqliteTable("asset_operations", {
  id: text("id").primaryKey(),
  contentItemId: text("content_item_id").notNull().references(() => contentItems.id, { onDelete: "cascade" }),
  actorUserId: text("actor_user_id").references(() => users.id, { onDelete: "set null" }),
  action: text("action", { enum: ["upload", "modify", "delete", "restore"] }).notNull(),
  source: text("source", { enum: ["TFVC", "NAS"] }).notNull(),
  sourceRevision: text("source_revision").notNull(),
  sourcePath: text("source_path").notNull(),
  summary: text("summary").notNull().default(""),
  rollbackFromSnapshotId: text("rollback_from_snapshot_id"),
  metadataJson: text("metadata_json").notNull().default("{}"),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
}, (table) => [
  index("asset_operations_content_created_idx").on(table.contentItemId, table.createdAt),
  index("asset_operations_source_revision_idx").on(table.source, table.sourceRevision),
]);

export const assetSnapshots = sqliteTable("asset_snapshots", {
  id: text("id").primaryKey(),
  contentItemId: text("content_item_id").notNull().references(() => contentItems.id, { onDelete: "cascade" }),
  operationId: text("operation_id").notNull().references(() => assetOperations.id, { onDelete: "cascade" }),
  revisionLabel: text("revision_label").notNull(),
  state: text("state", { enum: ["current", "historical", "deleted"] }).notNull().default("historical"),
  manifestJson: text("manifest_json").notNull().default("{}"),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
}, (table) => [
  uniqueIndex("asset_snapshots_content_revision_unique").on(table.contentItemId, table.revisionLabel),
  index("asset_snapshots_operation_idx").on(table.operationId),
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

export const auditLogs = sqliteTable("audit_logs", {
  id: text("id").primaryKey(),
  userId: text("user_id").references(() => users.id, { onDelete: "set null" }),
  action: text("action", { enum: ["login", "upload", "modify", "delete", "rollback", "download", "create_version", "review", "permission_change", "index"] }).notNull(),
  resourceType: text("resource_type").notNull(),
  resourceId: text("resource_id"),
  path: text("path"),
  detailsJson: text("details_json").notNull().default("{}"),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
}, (table) => [
  index("audit_logs_user_created_idx").on(table.userId, table.createdAt),
  index("audit_logs_action_created_idx").on(table.action, table.createdAt),
]);
