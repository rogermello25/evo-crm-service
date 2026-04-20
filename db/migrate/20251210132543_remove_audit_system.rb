# frozen_string_literal: true

class RemoveAuditSystem < ActiveRecord::Migration[7.0]
  def up
    drop_table :audit_logs, if_exists: true
    drop_table :audits, if_exists: true
  end

  def down
    # Recreate audit_logs table
    create_table :audit_logs, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid "user_id"
      t.string "action", null: false
      t.string "resource_type"
      t.uuid "resource_id"
      t.jsonb "details", default: {}
      t.string "ip_address"
      t.text "user_agent"
      t.boolean "success", default: true, null: false
      t.string "session_id"
      t.string "request_id"
      t.integer "severity", default: 0, null: false
      t.datetime "created_at", default: -> { "now()" }, null: false
      t.datetime "updated_at", default: -> { "now()" }, null: false
      t.index ["action"], name: "index_audit_logs_on_action"
      t.index ["created_at"], name: "index_audit_logs_on_created_at"
      t.index ["details"], name: "index_audit_logs_on_details", using: :gin
      t.index ["ip_address"], name: "index_audit_logs_on_ip_address"
      t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
      t.index ["severity"], name: "index_audit_logs_on_severity"
      t.index ["success"], name: "index_audit_logs_on_success"
      t.index ["user_id", "created_at"], name: "index_audit_logs_on_user_id_and_created_at"
    end

    # Recreate audits table (from audited gem)
    create_table :audits, force: :cascade do |t|
      t.uuid "auditable_id"
      t.string "auditable_type"
      t.uuid "associated_id"
      t.string "associated_type"
      t.uuid "user_id"
      t.string "user_type"
      t.string "username"
      t.string "action"
      t.jsonb "audited_changes"
      t.integer "version", default: 0
      t.string "comment"
      t.string "remote_address"
      t.string "request_uuid"
      t.datetime "created_at", precision: nil
      t.index ["associated_type", "associated_id"], name: "associated_index"
      t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
      t.index ["created_at"], name: "index_audits_on_created_at"
      t.index ["request_uuid"], name: "index_audits_on_request_uuid"
      t.index ["user_id", "user_type"], name: "user_index"
    end
  end
end

