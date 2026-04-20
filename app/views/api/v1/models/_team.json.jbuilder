json.id resource.id
json.name resource.name
json.description resource.description
json.allow_auto_assign resource.allow_auto_assign
json.is_member Current.user.teams.include?(resource)
