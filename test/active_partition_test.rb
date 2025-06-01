# frozen_string_literal: true

require "test_helper"
require "ostruct"

class ActivePartitionTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::ActivePartition::VERSION
  end

  def test_it_does_something_useful
    # This test is a placeholder and should be replaced with a meaningful test or removed.
    assert true
  end

  def test_partitionable_module_methods
    # Dummy model to test Partitionable
    klass = Class.new do
      attr_accessor :attributes
      def self.table_name; "test_table"; end
      def self.connection; OpenStruct.new; end
      def self.columns_hash; {"created_at" => OpenStruct.new(type: :datetime)}; end
      def self.before_validation(*); end
      include ActivePartition::Partitionable
      def initialize(attrs = {})
        @attributes = attrs
      end
      def self.reset_partition_manager
        @partition_manager = nil
      end
      def self.reset_partition_adapter
        @partition_adapter = nil
      end
      def self.partitioned_by; :created_at; end
      def self.partition_range; 3600; end
    end

    # Set up partitioning
    klass.partitioned_by = :created_at
    klass.partition_range = 3600
    klass.retention_period = nil
    klass.retention_partition_count = nil
    klass.partition_start_from = Time.utc(2025, 6, 1, 0)
    klass.reset_partition_manager
    klass.reset_partition_adapter

    # Test partition_adapter and partition_manager
    assert_instance_of ActivePartition::Adapters::PostgresqlAdapter, klass.partition_adapter
    assert_instance_of ActivePartition::PartitionManagers::TimeRange, klass.partition_manager

    # Test delegate methods
    assert_respond_to klass, :premake
    assert_respond_to klass, :latest_partition_coverage_time
    assert_respond_to klass, :retain
    assert_respond_to klass, :retain_by_time
    assert_respond_to klass, :retain_by_partition_count
    assert_respond_to klass, :prepare_partition
    assert_respond_to klass, :active_partitions_cover?
    assert_respond_to klass, :get_all_supported_partition_tables
    assert_respond_to klass, :drop_partition
  end
end
