CREATE TABLE `content_items` (
	`id` text PRIMARY KEY NOT NULL,
	`version_id` text NOT NULL,
	`title` text NOT NULL,
	`content_type` text NOT NULL,
	`entry_type` text NOT NULL,
	`change_state` text DEFAULT '新增' NOT NULL,
	`integrity` text DEFAULT '缺少源文件' NOT NULL,
	`owner` text DEFAULT '' NOT NULL,
	`description` text DEFAULT '' NOT NULL,
	`tags_json` text DEFAULT '[]' NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`version_id`) REFERENCES `module_versions`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `content_items_version_idx` ON `content_items` (`version_id`);--> statement-breakpoint
CREATE INDEX `content_items_type_idx` ON `content_items` (`content_type`);--> statement-breakpoint
CREATE INDEX `content_items_integrity_idx` ON `content_items` (`integrity`);--> statement-breakpoint
CREATE TABLE `content_relations` (
	`id` text PRIMARY KEY NOT NULL,
	`content_item_id` text NOT NULL,
	`label` text NOT NULL,
	`target_type` text NOT NULL,
	`target_id` text,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`content_item_id`) REFERENCES `content_items`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `content_relations_content_idx` ON `content_relations` (`content_item_id`);--> statement-breakpoint
CREATE TABLE `module_versions` (
	`id` text PRIMARY KEY NOT NULL,
	`module_id` text NOT NULL,
	`label` text NOT NULL,
	`version_date` text NOT NULL,
	`state` text DEFAULT '制作中' NOT NULL,
	`summary` text DEFAULT '' NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`module_id`) REFERENCES `project_modules`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `module_versions_module_label_unique` ON `module_versions` (`module_id`,`label`);--> statement-breakpoint
CREATE INDEX `module_versions_module_date_idx` ON `module_versions` (`module_id`,`version_date`);--> statement-breakpoint
CREATE TABLE `preview_assets` (
	`id` text PRIMARY KEY NOT NULL,
	`content_item_id` text NOT NULL,
	`label` text NOT NULL,
	`format` text NOT NULL,
	`storage` text NOT NULL,
	`path` text NOT NULL,
	`size` text DEFAULT '' NOT NULL,
	`preview_url` text,
	`sort_order` integer DEFAULT 0 NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`content_item_id`) REFERENCES `content_items`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `preview_assets_content_idx` ON `preview_assets` (`content_item_id`);--> statement-breakpoint
CREATE TABLE `project_modules` (
	`id` text PRIMARY KEY NOT NULL,
	`domain_id` text NOT NULL,
	`name` text NOT NULL,
	`description` text DEFAULT '' NOT NULL,
	`owner` text DEFAULT '' NOT NULL,
	`status` text DEFAULT '正常' NOT NULL,
	`current_version_label` text DEFAULT 'V1.0' NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`domain_id`) REFERENCES `work_domains`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `project_modules_domain_name_unique` ON `project_modules` (`domain_id`,`name`);--> statement-breakpoint
CREATE INDEX `project_modules_domain_idx` ON `project_modules` (`domain_id`);--> statement-breakpoint
CREATE TABLE `source_files` (
	`id` text PRIMARY KEY NOT NULL,
	`content_item_id` text NOT NULL,
	`label` text NOT NULL,
	`format` text NOT NULL,
	`storage` text NOT NULL,
	`path` text NOT NULL,
	`size` text DEFAULT '' NOT NULL,
	`availability` text DEFAULT '路径待确认' NOT NULL,
	`sort_order` integer DEFAULT 0 NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`content_item_id`) REFERENCES `content_items`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `source_files_content_idx` ON `source_files` (`content_item_id`);--> statement-breakpoint
CREATE INDEX `source_files_path_idx` ON `source_files` (`path`);--> statement-breakpoint
CREATE TABLE `work_domains` (
	`id` text PRIMARY KEY NOT NULL,
	`label` text NOT NULL,
	`kind` text NOT NULL,
	`description` text DEFAULT '' NOT NULL,
	`icon` text DEFAULT 'folder' NOT NULL,
	`sort_order` integer DEFAULT 0 NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `work_domains_label_unique` ON `work_domains` (`label`);