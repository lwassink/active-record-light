require_relative '02_searchable'
require 'active_support/inflector'

# Phase IIIa
class AssocOptions
  attr_accessor(
    :foreign_key,
    :class_name,
    :primary_key
  )

  def model_class
    class_name.constantize
  end

  def table_name
    name = class_name.to_s.underscore.pluralize
    name == "humen" ? "humans" : name
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    @foreign_key = options[:foreign_key] || "#{name.to_s}_id".to_sym
    @primary_key = options[:primary_key] || :id
    @class_name = options[:class_name] || name.to_s.camelcase.singularize
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    @foreign_key = options[:foreign_key] || "#{self_class_name.to_s.underscore}_id".to_sym
    @primary_key = options[:primary_key] || :id
    @class_name = options[:class_name] || name.to_s.camelcase.singularize
  end
end

module Associatable
  def belongs_to(name, options = {})
    options = BelongsToOptions.new(name, options)

    sql_string = <<-SQL
        SELECT
          #{options.table_name}.*
        FROM
          #{options.table_name} JOIN #{table_name}
            ON #{options.table_name}.#{options.primary_key} = #{table_name}.#{options.foreign_key}
        WHERE
          #{table_name}.id = ?
    SQL

    define_method(name) do
      data = DBConnection.execute(sql_string, self.id).first
      return nil if data.nil?
      options.model_class.new(data)
    end
  end

  def has_many(name, options = {})
    options = HasManyOptions.new(name, self.name, options)
    sql_string = <<-SQL
      SELECT
        #{options.table_name}.*
      FROM
        #{options.table_name} JOIN #{table_name}
          ON #{options.table_name}.#{options.foreign_key} = #{table_name}.#{options.primary_key}
      WHERE
        #{table_name}.#{options.primary_key} = ?
    SQL

    define_method(name) do
      puts sql_string
      data = DBConnection.execute(sql_string, self.id)
      return [] if data.empty?
      options.model_class.parse_all(data)
    end
  end

  def assoc_options
    # Wait to implement this in Phase IVa. Modify `belongs_to`, too.
  end
end

class SQLObject
  extend Associatable
end
