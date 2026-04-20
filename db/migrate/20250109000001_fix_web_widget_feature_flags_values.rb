# frozen_string_literal: true

# Migration to fix feature flags values after correcting bitwise flag definitions
# Old incorrect values: 3 (end_conversation), 4 (use_inbox_avatar_for_bot)
# New correct values:   4 (end_conversation), 8 (use_inbox_avatar_for_bot)
#
# This migration recalculates feature_flags for existing web widgets
class FixWebWidgetFeatureFlagsValues < ActiveRecord::Migration[7.1]
  def up
    return unless table_exists?(:channel_web_widgets)

    # Log início da correção
    say 'Fixing web widget feature flags...'

    # Processar cada widget existente
    execute <<-SQL
      UPDATE channel_web_widgets
      SET feature_flags = (
        -- Preservar bits 0 e 1 (attachments e emoji_picker)
        (feature_flags & 3) +
        -- Se bit 2 estava setado (valor 4 na soma), manter como 4 (end_conversation)
        CASE WHEN (feature_flags & 4) != 0 THEN 4 ELSE 0 END +
        -- Se havia o valor bugado 3+4=7, significa que use_inbox_avatar_for_bot deveria estar ativo
        -- Como não temos certeza, vamos assumir que valores >= 7 tinham use_inbox_avatar_for_bot ativo
        CASE WHEN feature_flags >= 7 THEN 8 ELSE 0 END
      )
      WHERE feature_flags > 0;
    SQL

    # Log estatísticas
    widget_count = execute('SELECT COUNT(*) FROM channel_web_widgets WHERE feature_flags > 0').first['count'].to_i
    say "Fixed feature flags for #{widget_count} web widget(s)"
  end

  def down
    # Rollback não é seguro devido à ambiguidade dos valores antigos
    say 'Cannot safely rollback feature flags values - migration is irreversible'
    raise ActiveRecord::IrreversibleMigration
  end
end

