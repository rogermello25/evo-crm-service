class MigrateEmailTemplatesToMessageTemplates < ActiveRecord::Migration[7.1]
  # Define os modelos temporariamente para uso na migração
  class EmailTemplate < ActiveRecord::Base
    self.table_name = 'email_templates'
  end

  class EmailChannel < ActiveRecord::Base
    self.table_name = 'channel_email'
  end

  class MessageTemplate < ActiveRecord::Base
    self.table_name = 'message_templates'
  end

  def up
    say 'Migrando email_templates para message_templates...'

    # Verifica se a tabela existe antes de migrar
    unless table_exists?(:email_templates)
      say 'Tabela email_templates não existe, pulando migração...', true
      return
    end

    # Verifica se a tabela message_templates existe
    unless table_exists?(:message_templates)
      say 'Tabela message_templates não existe, pulando migração...', true
      return
    end

    total_templates = EmailTemplate.count
    say "  Encontrados #{total_templates} template(s) para migrar", true

    migrated_count = 0
    skipped_count = 0

    EmailTemplate.find_each do |email_template|
      # Migrate each template to all email channels
      channels_found = false
      EmailChannel.find_each do |email_channel|
        if migrate_email_template_to_channel(email_template, email_channel)
          migrated_count += 1
          channels_found = true
        end
      end

      unless channels_found
        say "  Pulando template '#{email_template.name}': nenhum canal de email encontrado", true
        skipped_count += 1
      end
    end

    say "  Migração concluída: #{migrated_count} migrado(s), #{skipped_count} pulado(s)", true
  end

  def down
    MessageTemplate.where(channel_type: 'Channel::Email').delete_all
  end

  private

  def migrate_email_template_to_channel(email_template, email_channel)
    return false unless email_template.name.present? && email_channel.present?

    # Verificar se já existe usando SQL direto para evitar problemas com associações
    existing = MessageTemplate.where(
      channel_id: email_channel.id,
      channel_type: 'Channel::Email',
      name: email_template.name
    ).first

    if existing
      say "  Template '#{email_template.name}' já existe para o canal #{email_channel.id}, pulando...", true
      return false
    end

    MessageTemplate.create!(
      channel_id: email_channel.id,
      channel_type: 'Channel::Email',
      name: email_template.name,
      content: email_template.body || '',
      language: map_locale_to_language(email_template.locale),
      category: 'EMAIL',
      template_type: map_template_type(email_template.template_type),
      components: {},
      variables: extract_liquid_variables(email_template.body),
      settings: {
        'template_type' => email_template.template_type,
        'original_locale' => email_template.locale
      },
      metadata: {
        'migrated_from_email_templates' => true,
        'original_id' => email_template.id,
        'migrated_at' => Time.current.iso8601
      },
      active: true,
      created_at: email_template.created_at || Time.current,
      updated_at: email_template.updated_at || Time.current
    )
    say "  ✓ Migrado template '#{email_template.name}' para canal #{email_channel.id}", true
    true
  rescue StandardError => e
    say "  ✗ Erro ao migrar template '#{email_template.name}': #{e.message}", true
    false
  end

  def map_locale_to_language(locale)
    # EmailTemplate usa enum locale com LANGUAGES_CONFIG (índice inteiro)
    # Primeiro, converter o índice para código ISO 639-1
    locale_index = locale.to_i

    # Carregar LANGUAGES_CONFIG (mesmo formato do initializer)
    languages_config = {
      0 => { iso_639_1_code: 'en' },
      1 => { iso_639_1_code: 'ar' },
      2 => { iso_639_1_code: 'nl' },
      3 => { iso_639_1_code: 'fr' },
      4 => { iso_639_1_code: 'de' },
      5 => { iso_639_1_code: 'hi' },
      6 => { iso_639_1_code: 'it' },
      7 => { iso_639_1_code: 'ja' },
      8 => { iso_639_1_code: 'ko' },
      9 => { iso_639_1_code: 'pt' },
      10 => { iso_639_1_code: 'ru' },
      11 => { iso_639_1_code: 'zh' },
      12 => { iso_639_1_code: 'es' },
      13 => { iso_639_1_code: 'ml' },
      14 => { iso_639_1_code: 'ca' },
      15 => { iso_639_1_code: 'el' },
      16 => { iso_639_1_code: 'pt_BR' },
      17 => { iso_639_1_code: 'ro' },
      18 => { iso_639_1_code: 'ta' },
      19 => { iso_639_1_code: 'fa' },
      20 => { iso_639_1_code: 'zh_TW' },
      21 => { iso_639_1_code: 'vi' },
      22 => { iso_639_1_code: 'da' },
      23 => { iso_639_1_code: 'tr' },
      24 => { iso_639_1_code: 'cs' },
      25 => { iso_639_1_code: 'fi' },
      26 => { iso_639_1_code: 'id' },
      27 => { iso_639_1_code: 'sv' },
      28 => { iso_639_1_code: 'hu' },
      29 => { iso_639_1_code: 'nb' },
      30 => { iso_639_1_code: 'zh_CN' },
      31 => { iso_639_1_code: 'pl' },
      32 => { iso_639_1_code: 'sk' },
      33 => { iso_639_1_code: 'uk' },
      34 => { iso_639_1_code: 'th' },
      35 => { iso_639_1_code: 'lv' },
      36 => { iso_639_1_code: 'is' },
      37 => { iso_639_1_code: 'he' },
      38 => { iso_639_1_code: 'lt' },
      39 => { iso_639_1_code: 'sr' }
    }

    iso_code = languages_config[locale_index]&.dig(:iso_639_1_code) || 'en'

    # Mapear para formato com país (ex: en_US)
    locale_map = {
      'en' => 'en_US',
      'pt_BR' => 'pt_BR',
      'es' => 'es_ES',
      'fr' => 'fr_FR',
      'de' => 'de_DE',
      'it' => 'it_IT',
      'nl' => 'nl_NL',
      'pt' => 'pt_PT',
      'ru' => 'ru_RU',
      'zh_CN' => 'zh_CN',
      'zh_TW' => 'zh_TW',
      'zh' => 'zh_CN',
      'ja' => 'ja_JP',
      'ko' => 'ko_KR',
      'ar' => 'ar_SA',
      'hi' => 'hi_IN',
      'tr' => 'tr_TR',
      'pl' => 'pl_PL',
      'cs' => 'cs_CZ',
      'da' => 'da_DK',
      'el' => 'el_GR',
      'fi' => 'fi_FI',
      'hu' => 'hu_HU',
      'id' => 'id_ID',
      'nb' => 'nb_NO',
      'ro' => 'ro_RO',
      'sk' => 'sk_SK',
      'sv' => 'sv_SE',
      'th' => 'th_TH',
      'uk' => 'uk_UA',
      'vi' => 'vi_VN',
      'ca' => 'ca_ES',
      'ta' => 'ta_IN',
      'ml' => 'ml_IN',
      'fa' => 'fa_IR',
      'he' => 'he_IL',
      'lv' => 'lv_LV',
      'is' => 'is_IS',
      'lt' => 'lt_LT',
      'sr' => 'sr_RS'
    }

    locale_map[iso_code] || 'en_US'
  end

  def map_template_type(template_type)
    # EmailTemplate.template_type: layout: 0, content: 1
    case template_type.to_s
    when 'layout', '0'
      'text'  # Layouts são templates de texto base
    when 'content', '1'
      'text'  # Conteúdo também é texto
    else
      'text'
    end
  end

  def extract_liquid_variables(body)
    # Extrair variáveis Liquid do template (formato: {{ variable }})
    return [] unless body.present?

    variables = []

    # Regex para capturar variáveis Liquid
    body.to_s.scan(/\{\{\s*([a-zA-Z_][a-zA-Z0-9_\.]*)\s*\}\}/).flatten.uniq.each do |var_name|
      variables << {
        'name' => var_name,
        'type' => 'text',
        'required' => false,
        'format' => 'liquid'
      }
    end

    variables
  end
end
