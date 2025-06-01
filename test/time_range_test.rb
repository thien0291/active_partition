# frozen_string_literal: true

require "test_helper"
require "ostruct"

unless defined?(Rails)
  Rails = Module.new
end
Rails.singleton_class.send(:define_method, :env) { OpenStruct.new(test?: false) }

module ActivePartition
  module PartitionManagers
    class TimeRangeTest < Minitest::Test
      def setup
        @executed = []
        @mock_adapter = Class.new do
          attr_reader :executed
          def initialize(executed)
            @executed = executed
            @supported_tables = []
          end
          def exec_create_partition_by_time_range(name, from, to)
            @executed << [:create, name, from, to]
            @supported_tables << name
          end
          def get_all_supported_partition_tables
            @supported_tables
          end
          def detach_partition(name)
            @executed << [:detach, name]
            @supported_tables.delete(name)
          end
          def drop_partition(name)
            @executed << [:drop, name]
            @supported_tables.delete(name)
          end
        end.new(@executed)
        @table_name = "my_table"
        @manager = TimeRange.new(@mock_adapter, @table_name)
      end

      def test_build_partition_name
        from = Time.utc(2025, 6, 1, 0)
        to = Time.utc(2025, 6, 1, 1)
        name = @manager.build_partition_name(from, to)
        assert_match /^my_table_p_\d{6}_\d{2}_\d+_\d+$/, name
      end

      def test_create_partition_and_reload_active_ranges
        from = Time.utc(2025, 6, 1, 0)
        to = Time.utc(2025, 6, 1, 1)
        @manager.create_partition(from, to)
        assert_equal 1, @mock_adapter.get_all_supported_partition_tables.size
        assert_equal :create, @executed.first[0]
      end

      def test_reload_active_ranges
        from = Time.utc(2025, 6, 1, 0)
        to = Time.utc(2025, 6, 1, 1)
        name = @manager.build_partition_name(from, to)
        ranges = @manager.reload_active_ranges([name])
        assert_equal 1, ranges.size
        assert_instance_of Range, ranges.first
        assert_equal from, ranges.first.begin
        assert_equal to, ranges.first.end
      end

      def test_active_partitions_cover
        from = Time.utc(2025, 6, 1, 0)
        to = Time.utc(2025, 6, 1, 1)
        @manager.create_partition(from, to)
        assert @manager.active_partitions_cover?(Time.utc(2025, 6, 1, 0, 30))
        refute @manager.active_partitions_cover?(Time.utc(2025, 6, 1, 2, 0))
      end

      def test_latest_coverage_at_and_latest_partition_coverage_time
        from = Time.utc(2025, 6, 1, 0)
        to = Time.utc(2025, 6, 1, 1)
        @manager.create_partition(from, to)
        assert_equal to, @manager.latest_coverage_at
      end

      def test_prepare_partition_creates_if_not_covered
        from = Time.utc(2025, 6, 1, 0)
        to = Time.utc(2025, 6, 1, 1)
        @manager.create_partition(from, to)
        @manager.prepare_partition(Time.utc(2025, 6, 1, 2), 3600)
        assert @mock_adapter.get_all_supported_partition_tables.size >= 2
      end

      def test_remove_partitions
        from = Time.utc(2025, 6, 1, 0)
        to = Time.utc(2025, 6, 1, 1)
        @manager.create_partition(from, to)
        name = @mock_adapter.get_all_supported_partition_tables.first
        @manager.remove_partitions([name])
        assert_empty @mock_adapter.get_all_supported_partition_tables
        assert_includes @executed.map(&:first), :detach
        assert_includes @executed.map(&:first), :drop
      end
    end
  end
end
