# When working with experimental extensions, which doesn't have support on all providers
# This monkey patch will help us to ignore the extensions when dumping the schema
# Additionally we will also ignore the tables associated with those features and exentions

# Once the feature stabilizes, we can remove the tables/extension from the ignore list
# Ensure you write appropriate migrations when you do that.

# TEMPORARILY DISABLED - Rails 7.1 compatibility issue
# TODO: Fix this monkey patch for Rails 7.1 or remove if not needed

# module ActiveRecord
#   module ConnectionAdapters
#     module PostgreSQL
#       module SchemaDumper
#         def self.included(base)
#           base.class_eval do
#             cattr_accessor :ignore_extentions, default: []
#           end
#         end

#         private

#         def extensions(stream)
#           extensions = @connection.extensions
#           return unless extensions.any?

#           stream.puts '  # These extensions should be enabled to support this database'
#           extensions.sort.each do |extension|
#             stream.puts "  enable_extension #{extension.inspect}" unless self.class.ignore_extentions.include?(extension)
#           end
#           stream.puts
#         end
#       end
#     end
#   end
# end

# # Include the module in the appropriate class
# if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
#   ActiveRecord::SchemaDumper.prepend(ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper)
# end
