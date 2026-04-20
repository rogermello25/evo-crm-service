json.id resource.id
json.name resource.name
json.description resource.description
json.thumbnail resource.avatar_url
json.outgoing_url resource.outgoing_url unless resource.system_bot?
json.api_key resource.api_key unless resource.system_bot?
json.message_signature resource.message_signature unless resource.system_bot?
json.text_segmentation_enabled resource.text_segmentation_enabled unless resource.system_bot?
json.text_segmentation_limit resource.text_segmentation_limit unless resource.system_bot?
json.text_segmentation_min_size resource.text_segmentation_min_size unless resource.system_bot?
json.delay_per_character resource.delay_per_character unless resource.system_bot?
json.debounce_time resource.debounce_time unless resource.system_bot?
json.bot_type resource.bot_type
json.bot_provider resource.bot_provider
json.bot_config resource.bot_config
json.access_token resource.access_token if resource.access_token.present?
json.system_bot resource.system_bot?
