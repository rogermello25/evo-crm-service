# frozen_string_literal: true

require 'prometheus/client'
require 'prometheus/client/formats/text'

# Initialize Prometheus registry with default metrics
Prometheus::Client.registry

unless defined?(EVO_AI_CRM_CONCURRENT_USERS_GAUGE)
  EVO_AI_CRM_CONCURRENT_USERS_GAUGE = Prometheus::Client.registry.gauge(
    :evo_ai_crm_concurrent_users,
    docstring: 'Concurrent CRM users in the current presence window'
  )
end
