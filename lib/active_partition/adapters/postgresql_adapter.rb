# frozen_string_literal: true

module ActivePartition::Adapters
  class PostgresqlAdapter
    def initialize(connection, table_name)
      @connection = connection
      @table_name = table_name
    end
    # Creates a new partition for the table based on the specified time range.
    #
    # @param from [Time] The start time of the partition range.
    # @param to [Time] The end time of the partition range.
    # @return [Range] The time range of the created partition.
    def exec_create_partition_by_time_range(partition_name, unix_from, unix_to)
      sql_from = unix_from.utc.strftime("%Y-%m-%d %H:%M:%S")
      sql_to = unix_to.utc.strftime("%Y-%m-%d %H:%M:%S")

      @connection.execute <<~SQL
      CREATE TABLE IF NOT EXISTS #{partition_name}
        PARTITION OF #{@table_name}
        FOR VALUES FROM ('#{sql_from}') TO ('#{sql_to}');
      SQL
    end

    # Retrieves all supported partition tables for a given table name.
    #
    # @return [Array<String>] An array of table names representing the supported partition tables.
    def get_all_supported_partition_tables
      table_names_tuples = @connection.execute <<~SQL
      SELECT relname
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE nspname = 'public' AND
              relname LIKE '#{@table_name}_%' AND
              relkind = 'r'
      SQL

      table_names = table_names_tuples.map { |tuple| tuple["relname"] }
      # Filter supported partition names
      table_names.select { |name| name.match(/#{@table_name}_p_[0-9]{6}_[0-9]{2}_[0-9]{10}_[0-9]{10}/) }
    end

    # Detaches a partition from the table.
    #
    # @param partition_name [String] The name of the partition to detach.
    # @return [void]
    def detach_partition(partition_name)
      @connection.execute <<~SQL
        ALTER TABLE IF EXISTS #{@table_name} DETACH PARTITION #{partition_name};
      SQL
    end

    # Drops a partition table with the given name.
    #
    # @param partition_name [String] the name of the partition table to drop
    # @return [void]
    def drop_partition(partition_name)
      @connection.execute <<~SQL
        DROP TABLE IF EXISTS #{partition_name};
      SQL
    end
  end
end
