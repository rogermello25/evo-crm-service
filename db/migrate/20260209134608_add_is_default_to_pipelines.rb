# frozen_string_literal: true

class AddIsDefaultToPipelines < ActiveRecord::Migration[7.1]
  def change
    add_column :pipelines, :is_default, :boolean, default: false, null: false
    add_index :pipelines, :is_default,
              where: "is_default = true",
              name: "index_pipelines_on_is_default_unique"
  end
end
