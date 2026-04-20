if @conversation
  json.id @conversation.id.to_s
  json.display_id @conversation.display_id
  json.inbox_id @conversation.inbox_id
  json.contact_last_seen_at @conversation.contact_last_seen_at.to_i
  json.status @conversation.status
end
