require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns

    table_info = DBConnection.execute(<<-SQL)
      PRAGMA table_info(#{table_name})
    SQL

    @columns = table_info.map { |column| column['name'].to_sym }
  end

  def self.finalize!
    columns.each do |column|
      define_method(column) do
        attributes[column]
      end

      define_method("#{column}=") do |val|
        attributes[column] = val
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.name.underscore.pluralize
    @table_name
  end

  def self.all
    data = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
    SQL

    data.map { |datum| self.new(datum) }
  end

  def self.parse_all(results)
    results.map { |result| self.new(result) }
  end

  def self.find(id)
    data = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        id = ?
    SQL

    return nil if data.first.nil?
    self.new(data.first)
  end

  def initialize(params = {})
    columns = self.class.columns
    params.keys.each do |column|
      raise "unknown attribute '#{column}'" unless columns.include? column.to_sym
      send("#{column}=", params[column])
    end
  end

  def attributes
    @attributes ||= {}
    @attributes
  end

  def attribute_values
    vals = self.class.columns.map { |col| send(col) }
    vals.reject(&:nil?)
  end

  def insert
    question_marks = (['?'] * attribute_values.length).join(', ')
    sql_string = <<-SQL
      INSERT INTO
        #{self.class.table_name} (#{col_names.join(', ')})
      VALUES
        (#{question_marks})
    SQL

    DBConnection.execute(sql_string, *attribute_values)
    self.id = DBConnection.last_insert_row_id
  end

  def update
    col_string = col_names.join(' = ?, ') + ' = ?'
    sql_string = <<-SQL
      UPDATE
        #{self.class.table_name}
      SET
        #{col_string}
      WHERE
        id = #{self.id}
    SQL

    DBConnection.execute(sql_string, *attribute_values)
  end

  def save
    self.id ? update : insert
  end

  private

  def col_names
    self.class.columns.select do |col|
      attributes.keys.include? col
    end
  end
end

class String
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
end

