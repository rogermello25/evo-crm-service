class MigrateExistingServicesToCatalog < ActiveRecord::Migration[7.1]
  class PipelineServiceDefinition < ActiveRecord::Base
    self.table_name = 'pipeline_service_definitions'
  end

  class PipelineItem < ActiveRecord::Base
    self.table_name = 'pipeline_items'
    belongs_to :pipeline, class_name: 'MigrateExistingServicesToCatalog::Pipeline'
  end

  class Pipeline < ActiveRecord::Base
    self.table_name = 'pipelines'
    has_many :pipeline_items, class_name: 'MigrateExistingServicesToCatalog::PipelineItem', foreign_key: :pipeline_id
    has_many :pipeline_service_definitions, class_name: 'MigrateExistingServicesToCatalog::PipelineServiceDefinition', foreign_key: :pipeline_id
  end

  def up
    unless table_exists?(:pipeline_service_definitions)
      say 'Table pipeline_service_definitions does not exist, skipping migration...', true
      return
    end

    unless table_exists?(:pipeline_items)
      say 'Table pipeline_items does not exist, skipping migration...', true
      return
    end

    migrated_count = 0
    updated_items_count = 0

    Pipeline.find_each do |pipeline|
      service_map = {}
      pipeline_items_with_services = pipeline.pipeline_items.where("custom_fields ? 'services'")

      next if pipeline_items_with_services.empty?

      pipeline_items_with_services.find_each do |item|
        next unless item.custom_fields&.dig('services').is_a?(Array)

        item.custom_fields['services'].each do |service|
          next unless service.is_a?(Hash) && service['name'].present?

          service_name = service['name'].to_s.strip
          service_value = service['value']&.to_f || 0.0
          currency = item.custom_fields['currency'] || 'BRL'

          service_key = "#{service_name.downcase}_#{currency}"

          unless service_map[service_key]
            catalog_service = pipeline.pipeline_service_definitions.find_or_create_by!(
              name: service_name,
              pipeline: pipeline
            ) do |sd|
              sd.default_value = service_value
              sd.currency = currency
              sd.active = true
            end

            service_map[service_key] = catalog_service
            migrated_count += 1
          end
        end
      end

      updated_items = 0
      pipeline_items_with_services.find_each do |item|
        next unless item.custom_fields&.dig('services').is_a?(Array)

        updated_services = item.custom_fields['services'].map do |service|
          next unless service.is_a?(Hash) && service['name'].present?

          service_name = service['name'].to_s.strip
          service_value = service['value']&.to_f || 0.0
          currency = item.custom_fields['currency'] || 'BRL'
          service_key = "#{service_name.downcase}_#{currency}"

          catalog_service = service_map[service_key]
          next unless catalog_service

          updated_service = {
            'name' => service_name,
            'value' => service_value.round(2).to_s,
            'service_definition_id' => catalog_service.id.to_s
          }

          updated_service
        end.compact

        if updated_services.any?
          updated_custom_fields = item.custom_fields.dup
          updated_custom_fields['services'] = updated_services

          item.update_column(:custom_fields, updated_custom_fields)
          updated_items += 1
        end
      end

      updated_items_count += updated_items
    end
  end

  def down
    PipelineItem.find_each do |item|
      next unless item.custom_fields&.dig('services').is_a?(Array)

      updated_services = item.custom_fields['services'].map do |service|
        next unless service.is_a?(Hash)

        {
          'name' => service['name'],
          'value' => service['value']
        }
      end.compact

      if updated_services.any?
        updated_custom_fields = item.custom_fields.dup
        updated_custom_fields['services'] = updated_services
        item.update_column(:custom_fields, updated_custom_fields)
      end
    end
  end
end
