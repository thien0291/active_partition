# frozen_string_literal: true

require "test_helper"
require "ostruct"

module ActivePartition
  module Adapters
    class PostgresqlAdapterTest < Minitest::Test
      def setup
        @executed_sql = []
        @mock_connection = Class.new {
          define_method(:execute) do |sql|
            @executed_sql << sql
            [{"relname" => "my_table_p_202406_01_1719878400_1722470400"}]
          end

          define_method(:initialize) do |executed_sql|
            @executed_sql = executed_sql
          end
        }.new(@executed_sql)
        @adapter = PostgresqlAdapter.new(@mock_connection, "my_table")
      end

      def test_exec_create_partition_by_time_range
        from = Time.utc(2024, 6, 1)
        to = Time.utc(2024, 7, 1)
        @adapter.exec_create_partition_by_time_range("my_table_p_202406_01_1719878400_1722470400", from, to)
        assert_includes @executed_sql.first, "CREATE TABLE IF NOT EXISTS my_table_p_202406_01_1719878400_1722470400"
        assert_includes @executed_sql.first, "FOR VALUES FROM ('2024-06-01 00:00:00') TO ('2024-07-01 00:00:00')"
      end

      def test_get_all_supported_partition_tables
        result = @adapter.get_all_supported_partition_tables
        assert_equal ["my_table_p_202406_01_1719878400_1722470400"], result
      end

      def test_detach_partition
        @adapter.detach_partition("my_table_p_202406_01_1719878400_1722470400")
        assert_includes @executed_sql.last, "ALTER TABLE IF EXISTS my_table DETACH PARTITION my_table_p_202406_01_1719878400_1722470400"
      end

      def test_drop_partition
        @adapter.drop_partition("my_table_p_202406_01_1719878400_1722470400")
        assert_includes @executed_sql.last, "DROP TABLE IF EXISTS my_table_p_202406_01_1719878400_1722470400"
      end
    end
  end
end
