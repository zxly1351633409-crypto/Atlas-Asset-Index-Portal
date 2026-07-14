CREATE TABLE `asset_operations` (
	`id` text PRIMARY KEY NOT NULL,
	`content_item_id` text NOT NULL,
	`actor_user_id` text,
	`action` text NOT NULL,
	`source` text NOT NULL,
	`source_revision` text NOT NULL,
	`source_path` text NOT NULL,
	`summary` text DEFAULT '' NOT NULL,
	`rollback_from_snapshot_id` text,
	`metadata_json` text DEFAULT '{}' NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`content_item_id`) REFERENCES `content_items`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`actor_user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
CREATE INDEX `asset_operations_content_created_idx` ON `asset_operations` (`content_item_id`,`created_at`);--> statement-breakpoint
CREATE INDEX `asset_operations_source_revision_idx` ON `asset_operations` (`source`,`source_revision`);--> statement-breakpoint
CREATE TABLE `asset_snapshots` (
	`id` text PRIMARY KEY NOT NULL,
	`content_item_id` text NOT NULL,
	`operation_id` text NOT NULL,
	`revision_label` text NOT NULL,
	`state` text DEFAULT 'historical' NOT NULL,
	`manifest_json` text DEFAULT '{}' NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`content_item_id`) REFERENCES `content_items`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`operation_id`) REFERENCES `asset_operations`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `asset_snapshots_content_revision_unique` ON `asset_snapshots` (`content_item_id`,`revision_label`);--> statement-breakpoint
CREATE INDEX `asset_snapshots_operation_idx` ON `asset_snapshots` (`operation_id`);--> statement-breakpoint
ALTER TABLE `content_items` ADD `lifecycle_status` text DEFAULT 'active' NOT NULL;--> statement-breakpoint
ALTER TABLE `content_items` ADD `deleted_at` text;--> statement-breakpoint
ALTER TABLE `content_items` ADD `deleted_by_user_id` text REFERENCES users(id);--> statement-breakpoint
CREATE INDEX `content_items_lifecycle_idx` ON `content_items` (`lifecycle_status`);