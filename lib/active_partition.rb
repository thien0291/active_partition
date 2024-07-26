# frozen_string_literal: true

require_relative "active_partition/version"
require "active_support/concern"
require "active_support/core_ext/module/delegation"
require "active_partition/adapters/postgresql_adapter"
require "active_partition/partition_managers/time_range"
require "range_operators"

module ActivePartition
  class Error < StandardError; end

  module Partitionable
    extend ActiveSupport::Concern

    # rubocop:disable Metrics
    included do
      # when partitioned column change, create partition if needed
      # before_validation will be called with create, update, save, and create! methods
      before_validation :create_partition_if_needed

      def create_partition_if_needed
        if ["created_at", "updated_at"].include?(self.class.partitioned_by.to_s) && self.attributes[self.class.partitioned_by].nil?
          # set default value if created_at or updated_at is nil
          self.assign_attributes(self.class.partitioned_by => Time.current.utc)
        end

        return unless self.class.partitioned_by && attribute_changed?(self.class.partitioned_by.to_s)

        # get partitioned attribute value
        partitioned_value = attributes[self.class.partitioned_by.to_s]
        self.class.prepare_partition(partitioned_value, self.class.partition_range)
      end

      class << self
        def partition_adapter
          @partition_adapter ||= ActivePartition::Adapters::PostgresqlAdapter.new(connection, table_name)
        end

        def partition_manager
          @partition_manager ||= case columns_hash[partitioned_by.to_s].type.to_s
                                 when "datetime"
                                   ActivePartition::PartitionManagers::TimeRange.new(partition_adapter, table_name)
                                 else
                                   ActivePartition::PartitionManagers::TimeRange.new(partition_adapter, table_name)
          end
        end

        # The range of each partition. You can change this value over time.
        # example: 1.month, 2.weeks, 3.hours
        attr_accessor :partition_range
        # The column name to partition the table by
        attr_accessor :partitioned_by
        # Retains partitions until the specified time [Choose one of retention_period or retention_partition_count]
        # For example: 1.month (1 month from now), 2.weeks (2 weeks from now), 3.hours (3 hours from now)
        attr_accessor :retention_period
        # Retains the specified number of partitions [Choose one of retention_period or retention_partition_count]
        attr_accessor :retention_partition_count

        def delete_expired_partitions
          if retention_period && retention_period.is_a?(ActiveSupport::Duration)
            partition_manager.retain_by_time(retention_period.ago)
          elsif retention_partition_count
            partition_manager.retain_by_partition_count(retention_partition_count)
          end
        end

        delegate :premake, :latest_partition_coverage_time, to: :partition_manager
        delegate :retain, :retain_by_time, :retain_by_partition_count, to: :partition_manager
        delegate :prepare_partition, "active_partitions_cover?", to: :partition_manager
        delegate :get_all_supported_partition_tables, to: :partition_adapter
        delegate :drop_partition, to: :partition_adapter
      end
    end

    # rubocop:disable Metrics
    # class_methods do
    # end
  end
end
