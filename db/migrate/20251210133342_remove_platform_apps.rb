# frozen_string_literal: true

class RemovePlatformApps < ActiveRecord::Migration[7.0]
  def up
    # Drop platform_app_permissibles first (has foreign key to platform_apps)
    drop_table :platform_app_permissibles, if_exists: true

    # Drop platform_apps table
    drop_table :platform_apps, if_exists: true
  end

  def down
    # Recreate platform_apps table
    create_table :platform_apps, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.string "name", null: false
      t.datetime "created_at", precision: nil, null: false
      t.datetime "updated_at", precision: nil, null: false
    end

    # Recreate platform_app_permissibles table
    create_table :platform_app_permissibles, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid "platform_app_id", null: false
      t.string "permissible_type", null: false
      t.uuid "permissible_id", null: false
      t.datetime "created_at", precision: nil, null: false
      t.datetime "updated_at", precision: nil, null: false
      t.index ["permissible_type", "permissible_id"], name: "index_platform_app_permissibles_on_permissibles"
      t.index ["platform_app_id", "permissible_id", "permissible_type"], name: "unique_permissibles_index", unique: true
      t.index ["platform_app_id"], name: "index_platform_app_permissibles_on_platform_app_id"
    end
  end
end

