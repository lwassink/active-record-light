require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    sql_string = <<-SQL
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{qmarks(params)}
    SQL

    data = DBConnection.execute(sql_string, *params.values)
    self.parse_all(data)
  end

  private

  def qmarks(hash)
    hash.keys.join(' = ? AND ') + ' = ?'
  end
end

class SQLObject
  extend Searchable
end
