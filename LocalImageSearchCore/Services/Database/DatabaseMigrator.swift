import Foundation
import GRDB

public enum DatabaseMigrations {
    public static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "watched_folder") { t in
                t.column("id", .text).primaryKey()
                t.column("display_name", .text).notNull()
                t.column("bookmark_data", .blob).notNull()
                t.column("last_resolved_path", .text).notNull()
                t.column("is_enabled", .boolean).notNull().defaults(to: true)
                t.column("recursive", .boolean).notNull().defaults(to: true)
                t.column("added_at", .datetime).notNull()
                t.column("last_scan_started_at", .datetime)
                t.column("last_scan_completed_at", .datetime)
                t.column("last_event_id", .integer)
                t.column("access_state", .text).notNull()
                t.column("last_error", .text)
            }

            try db.create(table: "image_content") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sha256", .blob).notNull().unique()
                t.column("byte_count", .integer).notNull()
                t.column("created_at", .datetime).notNull()
            }

            try db.create(table: "image_asset") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("folder_id", .text).notNull().references("watched_folder", onDelete: .cascade)
                t.column("relative_path", .text).notNull()
                t.column("normalized_relative_path", .text).notNull()
                t.column("file_resource_id", .blob)
                t.column("content_id", .integer).references("image_content", onDelete: .setNull)
                t.column("file_size", .integer).notNull()
                t.column("modified_at", .datetime).notNull()
                t.column("created_at", .datetime)
                t.column("pixel_width", .integer)
                t.column("pixel_height", .integer)
                t.column("uti", .text)
                t.column("discovered_at", .datetime).notNull()
                t.column("last_seen_scan_id", .text).notNull()
                t.column("availability", .text).notNull()
                t.column("last_error", .text)

                t.uniqueKey(["folder_id", "normalized_relative_path"])
            }
            try db.create(index: "idx_image_asset_reconcile", on: "image_asset", columns: ["folder_id", "last_seen_scan_id"])
            try db.create(index: "idx_image_asset_content_id", on: "image_asset", columns: ["content_id"])

            try db.create(table: "image_analysis") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("content_id", .integer).notNull().references("image_content", onDelete: .cascade)
                t.column("provider_kind", .text).notNull()
                t.column("base_url_fingerprint", .text).notNull()
                t.column("model", .text).notNull()
                t.column("prompt_version", .integer).notNull()
                t.column("schema_version", .integer).notNull()
                t.column("description", .text).notNull()
                t.column("short_title", .text).notNull()
                t.column("categories_json", .text).notNull()
                t.column("objects_json", .text).notNull()
                t.column("scene", .text)
                t.column("dominant_colors_json", .text).notNull()
                t.column("visible_text", .text)
                t.column("people_count", .integer)
                t.column("time_of_day", .text)
                t.column("searchable_text", .text).notNull()
                t.column("raw_response_json", .text)
                t.column("created_at", .datetime).notNull()
                t.column("is_current", .boolean).notNull().defaults(to: true)

                t.uniqueKey(["content_id", "base_url_fingerprint", "model", "prompt_version", "schema_version"])
            }

            try db.create(table: "embedding") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("analysis_id", .integer).notNull().references("image_analysis", onDelete: .cascade)
                t.column("engine_kind", .text).notNull()
                t.column("model", .text).notNull()
                t.column("revision", .text).notNull()
                t.column("dimension", .integer).notNull()
                t.column("vector", .blob).notNull()
                t.column("source_text_sha256", .blob).notNull()
                t.column("created_at", .datetime).notNull()

                t.uniqueKey(["analysis_id", "engine_kind", "model", "revision"])
            }

            try db.create(table: "index_job") { t in
                t.column("id", .text).primaryKey()
                t.column("asset_id", .integer).references("image_asset", onDelete: .setNull)
                t.column("content_id", .integer).references("image_content", onDelete: .setNull)
                t.column("kind", .text).notNull()
                t.column("state", .text).notNull()
                t.column("attempt_count", .integer).notNull().defaults(to: 0)
                t.column("next_attempt_at", .datetime)
                t.column("priority", .integer).notNull().defaults(to: 0)
                t.column("configuration_fingerprint", .text)
                t.column("error_code", .text)
                t.column("error_message", .text)
                t.column("created_at", .datetime).notNull()
                t.column("started_at", .datetime)
                t.column("finished_at", .datetime)
            }
            try db.create(index: "idx_index_job_state_priority", on: "index_job", columns: ["state", "priority", "next_attempt_at"])

            try db.execute(sql: "CREATE VIRTUAL TABLE analysis_fts USING fts5(analysis_id UNINDEXED, short_title, description, categories, objects, scene, visible_text, tokenize = \'porter unicode61\');")
        }

        return migrator
    }
}
