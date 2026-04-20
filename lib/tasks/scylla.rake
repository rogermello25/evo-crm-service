namespace :scylla do
  desc 'Create keyspace and tables'
  task setup: :environment do
    require 'cassandra'

    unless ScyllaDB.enabled?
      puts 'ScyllaDB is disabled. Set SCYLLA_ENABLED=true to enable.'
      exit 0
    end

    cluster_options = {
      hosts: ScyllaDB.scylla_hosts,
      port: ScyllaDB.scylla_port,
      connect_timeout: 60,  # Aumentar timeout para conexões mais lentas com ScyllaDB Cloud
      timeout: 30,          # Timeout para operações
      consistency: :quorum,
      # Configurações para melhorar conexão com ScyllaDB Cloud
      connections_per_host: 2,  # Reduzir conexões por host para evitar sobrecarga
      # Retry policy padrão do driver
    }

    # Adicionar autenticação se username e password estiverem configurados
    if ScyllaDB.scylla_username.present? && ScyllaDB.scylla_password.present?
      cluster_options[:username] = ScyllaDB.scylla_username
      cluster_options[:password] = ScyllaDB.scylla_password
    end

    puts "Connecting to ScyllaDB Cloud..."
    puts "  Hosts: #{ScyllaDB.scylla_hosts.join(', ')}"
    puts "  Port: #{ScyllaDB.scylla_port}"
    puts "  Username: #{ScyllaDB.scylla_username}"
    puts "  Timeout: #{cluster_options[:connect_timeout]}s"
    puts ""

    begin
      cluster = Cassandra.cluster(cluster_options)
      puts "✅ Successfully connected to ScyllaDB cluster"
    rescue => e
      puts "❌ Failed to connect to ScyllaDB: #{e.class.name}: #{e.message}"
      puts ""
      puts "Troubleshooting tips:"
      puts "  1. Verify your IP is whitelisted in ScyllaDB Cloud firewall"
      puts "  2. Check if hosts are reachable: #{ScyllaDB.scylla_hosts.first}:#{ScyllaDB.scylla_port}"
      puts "  3. Verify credentials are correct"
      puts "  4. Check network connectivity"
      raise e
    end

    # Conectar sem keyspace primeiro (keyspace será criado na migration)
    session = cluster.connect

    migration_files = Dir[Rails.root.join('db/scylla/migrations/*.cql')].sort

    if migration_files.empty?
      puts 'No migration files found in db/scylla/migrations/'
      session.close
      cluster.close
      exit 0
    end

    # Obter o keyspace da variável de ambiente
    expected_keyspace = ScyllaDB.keyspace

    migration_files.each do |file|
      puts "Executing #{File.basename(file)}..."
      begin
        cql = File.read(file)

        # Substituir o nome do keyspace hardcoded pelo valor da variável de ambiente
        # IMPORTANTE: Fazer isso ANTES de remover comentários para evitar match em comentários
        # Buscar linha por linha para evitar problemas com regex em múltiplas linhas
        hardcoded_keyspace = nil

        # Procurar CREATE KEYSPACE linha por linha (ignorando comentários)
        cql.lines.each_with_index do |line, line_num|
          # Ignorar linhas que são comentários
          next if line.strip.start_with?('--')

          # Procurar CREATE KEYSPACE nesta linha
          # Regex: capturar o nome do keyspace que vem DEPOIS de "KEYSPACE IF NOT EXISTS" ou "KEYSPACE"
          match = line.match(/CREATE\s+KEYSPACE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z_][a-zA-Z0-9_]*)/i)
          if match && match[1]
            captured = match[1]
            # Validar que não é uma palavra reservada
            reserved_words = ['CREATE', 'KEYSPACE', 'IF', 'NOT', 'EXISTS', 'WITH', 'REPLICATION']
            if reserved_words.include?(captured.upcase)
              puts "  ⚠ Skipping reserved word on line #{line_num + 1}: '#{captured}'"
            else
              hardcoded_keyspace = captured
              puts "  → Found keyspace on line #{line_num + 1}: '#{hardcoded_keyspace}'"
              break
            end
          end
        end

        # Se não encontrou no CREATE KEYSPACE, verificar no USE statement
        if !hardcoded_keyspace
          cql.lines.each do |line|
            next if line.strip.start_with?('--')
            use_match = line.match(/USE\s+([a-zA-Z_][a-zA-Z0-9_]*)/i)
            if use_match && use_match[1]
              hardcoded_keyspace = use_match[1]
              break
            end
          end
        end

        # Debug: mostrar o que foi encontrado (já foi mostrado acima, mas manter para compatibilidade)

        # Se encontrou um keyspace hardcoded diferente do esperado, substituir
        if hardcoded_keyspace && hardcoded_keyspace != expected_keyspace
          # Validar que o keyspace encontrado não é uma palavra reservada
          reserved_words = ['CREATE', 'KEYSPACE', 'IF', 'NOT', 'EXISTS', 'WITH', 'REPLICATION']
          if reserved_words.include?(hardcoded_keyspace.upcase)
            puts "  ⚠ Error: Invalid keyspace name detected: '#{hardcoded_keyspace}' (reserved word)"
            puts "  → Using expected keyspace: #{expected_keyspace}"
            # Não fazer substituição, apenas usar o esperado
            hardcoded_keyspace = nil
          else
            puts "  → Replacing keyspace '#{hardcoded_keyspace}' with '#{expected_keyspace}'"
            # Substituir todas as ocorrências do keyspace hardcoded (usando word boundary para evitar substituir partes de outras palavras)
            cql = cql.gsub(/\b#{Regexp.escape(hardcoded_keyspace)}\b/, expected_keyspace)
          end
        elsif !hardcoded_keyspace
          puts "  ⚠ Warning: Could not find keyspace name in migration file"
          puts "  → Will use expected keyspace: #{expected_keyspace}"
        end

        # Remover comentários de linha completa primeiro (linhas que começam com --)
        lines = cql.split("\n")
        cleaned_lines = lines.map do |line|
          # Remover comentários de linha completa, mas preservar comentários inline se necessário
          if line.strip.start_with?('--')
            ''
          else
            line
          end
        end
        cql = cleaned_lines.join("\n")

        # Split by semicolon and execute each statement separately
        # Mas preservar statements multi-linha (como CREATE KEYSPACE ... WITH replication = {...})
        statements = []
        current_statement = ''
        in_brackets = 0

        cql.split(/([{};])/).each do |token|
          case token
          when '{'
            in_brackets += 1
            current_statement += token
          when '}'
            in_brackets -= 1
            current_statement += token
          when ';'
            current_statement += token
            if in_brackets == 0
              stmt = current_statement.strip
              statements << stmt unless stmt.empty?
              current_statement = ''
            end
          else
            current_statement += token
          end
        end

        # Adicionar último statement se não terminou com ;
        last_stmt = current_statement.strip
        if !last_stmt.empty?
          statements << last_stmt
        end

        statements.reject!(&:empty?)

        # Inicializar como nil - só será definido após CREATE KEYSPACE ou USE
        keyspace_name = nil

        statements.each_with_index do |statement, index|
          next if statement.empty?

          # Remover espaços em branco extras
          statement = statement.strip
          next if statement.empty?

          # Debug: mostrar qual statement está sendo executado
          statement_type = statement.split.first&.upcase || 'UNKNOWN'
          puts "  [#{index + 1}/#{statements.length}] Executing: #{statement_type}..."

          # Detectar CREATE KEYSPACE e extrair o nome
          if statement.upcase.include?('CREATE KEYSPACE')
            match = statement.match(/CREATE\s+KEYSPACE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)/i)
            extracted_keyspace = match[1] if match

            # Garantir que o keyspace criado seja o esperado
            keyspace_name = expected_keyspace

            # Substituir o nome do keyspace no statement se necessário
            if extracted_keyspace && extracted_keyspace != expected_keyspace
              statement = statement.gsub(extracted_keyspace, expected_keyspace)
              puts "    → Replacing keyspace name with: #{expected_keyspace}"
            end

            # Executar CREATE KEYSPACE (sem conectar a um keyspace específico ainda)
            session.execute(statement)
            puts "    ✓ Keyspace created: #{keyspace_name}"

            # Agora sim, reconectar usando o keyspace criado
            session.close
            session = cluster.connect(keyspace_name)
            puts "    → Connected to keyspace: #{keyspace_name}"
            next
          end

          # Detectar USE keyspace
          if statement.upcase.start_with?('USE')
            match = statement.match(/USE\s+(\w+)/i)
            extracted_keyspace = match[1] if match

            # Garantir que o keyspace usado seja o esperado
            keyspace_name = expected_keyspace

            # Substituir o nome do keyspace no statement se necessário
            if extracted_keyspace && extracted_keyspace != expected_keyspace
              statement = statement.gsub(extracted_keyspace, expected_keyspace)
              puts "    → Replacing keyspace name with: #{expected_keyspace}"
            end

            # Reconectar usando o keyspace
            session.close
            session = cluster.connect(keyspace_name)
            puts "    → Connected to keyspace: #{keyspace_name}"
            next
          end

          # Para outros statements (CREATE TABLE, CREATE INDEX, etc), garantir que estamos no keyspace correto
          if keyspace_name
            # Sempre garantir que estamos conectados ao keyspace antes de criar tabelas/índices
            begin
              # Tentar verificar se estamos no keyspace correto
              current_keyspace = session.keyspace rescue nil
              if current_keyspace != keyspace_name
                session.close
                session = cluster.connect(keyspace_name)
                puts "    → Reconnected to keyspace: #{keyspace_name}"
              end
            rescue => e
              # Se não conseguir verificar, reconectar de qualquer forma
              session.close
              session = cluster.connect(keyspace_name)
              puts "    → Reconnected to keyspace: #{keyspace_name}"
            end
          else
            puts "    ⚠ Warning: No keyspace set, statement may fail"
          end

          # Executar statement
          begin
            session.execute(statement)
            puts "    ✓ Success"
          rescue => e
            puts "    ✗ Error: #{e.message}"
            puts "    Statement: #{statement[0..100]}..." if statement.length > 100
            raise e
          end
        end
        puts "✓ #{File.basename(file)}"
      rescue => e
        puts "✗ Error executing #{File.basename(file)}: #{e.message}"
        puts e.backtrace.first(5)
      end
    end

    session.close
    cluster.close

    puts 'ScyllaDB setup complete!'
  end

  desc 'Reset database: drop keyspace and recreate schema'
  task reset: :environment do
    require 'cassandra'

    unless ScyllaDB.enabled?
      puts 'ScyllaDB is disabled. Set SCYLLA_ENABLED=true to enable.'
      exit 0
    end

    expected_keyspace = ScyllaDB.keyspace

    puts '⚠️  WARNING: This will DELETE ALL DATA in ScyllaDB!'
    puts "   Keyspace: #{expected_keyspace}"
    puts ''
    print 'Are you sure you want to continue? (yes/no): '
    confirmation = STDIN.gets.chomp.downcase

    unless confirmation == 'yes'
      puts 'Aborted.'
      exit 0
    end

    cluster_options = {
      hosts: ScyllaDB.scylla_hosts,
      port: ScyllaDB.scylla_port,
      connect_timeout: 30
    }

    # Adicionar autenticação se username e password estiverem configurados
    if ScyllaDB.scylla_username.present? && ScyllaDB.scylla_password.present?
      cluster_options[:username] = ScyllaDB.scylla_username
      cluster_options[:password] = ScyllaDB.scylla_password
    end

    cluster = Cassandra.cluster(cluster_options)

    # Conectar sem keyspace primeiro
    session = cluster.connect

    begin
      # Tentar dropar a tabela messages se existir
      begin
        puts "Dropping table messages..."
        session.execute("DROP TABLE IF EXISTS #{expected_keyspace}.messages")
        puts "  ✓ Table messages dropped"
      rescue => e
        puts "  ⚠ Could not drop table messages: #{e.message}"
      end

      # Tentar dropar índices se existirem
      ['messages_inbox_id_idx', 'messages_sender_id_idx', 'messages_source_id_idx'].each do |index_name|
        begin
          puts "Dropping index #{index_name}..."
          session.execute("DROP INDEX IF EXISTS #{expected_keyspace}.#{index_name}")
          puts "  ✓ Index #{index_name} dropped"
        rescue => e
          puts "  ⚠ Could not drop index #{index_name}: #{e.message}"
        end
      end

      # Dropar o keyspace inteiro
      begin
        puts "Dropping keyspace #{expected_keyspace}..."
        session.execute("DROP KEYSPACE IF EXISTS #{expected_keyspace}")
        puts "  ✓ Keyspace #{expected_keyspace} dropped"
      rescue => e
        puts "  ⚠ Could not drop keyspace: #{e.message}"
      end

      puts ''
      puts '✓ Database cleaned!'
      puts ''
    ensure
      session.close
      cluster.close
    end

    # Agora rodar o setup para recriar tudo
    puts 'Running setup to recreate schema...'
    puts ''
    Rake::Task['scylla:setup'].invoke
  end

  desc 'Test connection'
  task test: :environment do
    unless ScyllaDB.enabled?
      puts 'ScyllaDB is disabled. Set SCYLLA_ENABLED=true to enable.'
      exit 0
    end

    begin
      result = ScyllaDB.session.execute('SELECT now() FROM system.local')
      puts '✓ ScyllaDB connection successful!'
      puts "  Keyspace: #{ScyllaDB.keyspace}"
      puts "  Hosts: #{ScyllaDB.scylla_hosts.join(', ')}"
      puts "  Port: #{ScyllaDB.scylla_port}"
    rescue => e
      puts "✗ ScyllaDB connection failed: #{e.message}"
      puts e.backtrace.first(5)
      exit 1
    end
  end

  desc 'Migrate messages from PostgreSQL to ScyllaDB'
  task migrate_messages: :environment do
    require_relative '../../app/services/scylla_db/migration_service'

    unless ScyllaDB.enabled?
      puts 'ScyllaDB is disabled. Set SCYLLA_ENABLED=true to enable.'
      exit 0
    end

    conversation_id = ENV['CONVERSATION_ID']

    puts 'Starting migration from PostgreSQL to ScyllaDB...'
    puts "Conversation ID: #{conversation_id || 'ALL'}"

    result = ScyllaDB::MigrationService.new.migrate_messages_from_postgresql(
      conversation_id: conversation_id
    )

    puts "\nMigration complete!"
    puts "  Processed: #{result[:processed]}"
    puts "  Errors: #{result[:errors]}"
    puts "  Total: #{result[:total]}"
  end
end
