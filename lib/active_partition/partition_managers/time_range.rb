# frozen_string_literal: true

module ActivePartition::PartitionManagers
  class TimeRange
    def initialize(partition_adapter, table_name)
      @partition_adapter = partition_adapter
      @table_name = table_name
    end

    # Retrieves the active ranges from the partition adapter.
    #
    # The active ranges are cached in an instance variable `@active_ranges` to improve performance.
    # If the `@active_ranges` variable is `nil`, the method calls the `reload_active_ranges` method
    # with the result of `@partition_adapter.get_all_supported_partition_tables` as the argument.
    #
    # @return [Array] The array of active ranges.
    def active_ranges
      @active_ranges ||= reload_active_ranges(@partition_adapter.get_all_supported_partition_tables)
    end

    # Reloads the active ranges based on the given partition names.
    #
    # @param partition_names [Array<String>] An array of partition names.
    # @return [Array<Range>] An array of Range objects representing the active ranges.
    def reload_active_ranges(partition_names)
      @active_ranges = partition_names.map do |partition_name|
        start_at, end_at = partition_name.split("_").last(2).map { |t| Time.at(t.to_i).utc }
        (start_at...end_at)
      end
    end

    # Checks if the active partitions cover the given value.
    #
    # @param value [Time] The value to check if it is covered by the active partitions.
    # @return [Boolean] Returns true if the value is covered by any of the active partitions, otherwise returns false.
    def active_partitions_cover?(value)
      active_ranges.any? { |range| range.cover? value.utc }
    end

    # Returns the latest coverage time for the partition.
    #
    # This method memoizes the latest coverage time by caching the result in an instance variable.
    # If the latest coverage time has already been calculated, it will be returned from the cache.
    # Otherwise, it will call the `latest_partition_coverage_time` method to calculate the latest coverage time.
    #
    # @return [Time] The latest coverage time for the partition.
    def latest_coverage_at
      @latest_coverage_at ||= latest_partition_coverage_time
    end

    # Prepares a partition for the given partitioned value and period.
    #
    # If the active partitions do not cover the partitioned value, a new partition is created.
    #
    # @param partitioned_value [Time] The value to be partitioned.
    # @param period [Integer] The duration of each partition.
    # @return [void]
    def prepare_partition(partitioned_value, period)
      return if active_partitions_cover?(partitioned_value)

      diff = (partitioned_value.utc - latest_coverage_at) / period
      from_time = latest_coverage_at + (diff.floor * period)
      to_time = from_time + period

      create_partition(from_time, to_time)
    end

    # Builds a partition name based on the given time range.
    #
    # @param from [DateTime] The start time of the partition range.
    # @param to [DateTime] The end time of the partition range.
    # @return [String] The generated partition name.
    def build_partition_name(from, to)
      unix_from = from.utc.to_i
      unix_to = to.utc.to_i

      # It's easier to manage when having readable part in the name
      readable_from = from.utc.strftime("%y%m%d_%H")

      "#{@table_name}_p_#{readable_from}_#{unix_from}_#{unix_to}"
    end

    # Creates a new partition for the table based on the specified time range.
    #
    # @param from [Time] The start time of the partition range.
    # @param to [Time] The end time of the partition range.
    # @return [Range] The time range of the created partition.
    def create_partition(from, to)
      from = from.utc
      to = to.utc

      partition_name = build_partition_name(from, to)
      puts "create partition #{partition_name} from #{from} to #{to}"
      @partition_adapter.exec_create_partition_by_time_range(partition_name, from, to)

      reload_active_ranges(@partition_adapter.get_all_supported_partition_tables)

      # rescue ActiveRecord::StatementInvalid => e
      # byebug
      # # When overlapping partition, the message will be like this:
      # # PG::InvalidObjectDefinition: ERROR:  partition "table_name_p_240626_09_1719395833_1719482233" would overlap partition "table_name_p_240627_09_1719481818_1719568218"
      # # LINE 3:   FOR VALUES FROM ('2024-06-26 09:57:13') TO ('2024-06-27 09
      # # catchup the floor of the from time to the conflict partition and retry
      # # handle the floor? what about the ceil?
      # if e.message.include?("would overlap partition")
      #   overlapped_partition = e.message.split("would overlap partition").last.split("\n").first.delete('"').strip
      #   overlapped_from, overlapped_to = overlapped_partition.split("_").last(2).map { |t| Time.at(t.to_i).utc }

      #   return true if (overlapped_from..overlapped_to).cover?(unix_from..unix_to)
      #   # unix_from < unix_to
      #   # overlapped_from < overlapped_to
      #   # if unix_from < overlapped_from
      #   #   overlapped_from = unix_from

      #   if floor_time > unix_from
      #     Rails.logger.warn "Retry create partition for #{unix_from} to #{floor_time}"
      #     create_partition(unix_from, floor_time)
      #   end
      # end
    end

    # Returns the coverage time of the latest partition.
    #
    # If there are no supported partition tables, the coverage time will be the beginning of the current hour in UTC.
    # Otherwise, the coverage time will be extracted from the latest partition table name.
    #
    # @return [Time] The coverage time of the latest partition in UTC.
    def latest_partition_coverage_time
      partition_tables = @partition_adapter.get_all_supported_partition_tables
      reload_active_ranges(partition_tables)
      return Time.current.beginning_of_hour.utc if partition_tables.empty?

      latest_partition_table = partition_tables.sort_by { |p_name| p_name.split("_").last.to_i }.last
      @latest_coverage_at = Time.at(latest_partition_table.split("_").last.to_i).utc
      @latest_coverage_at
    end

    # Creates multiple partitions in the database based on the given period, number, and starting time.
    #
    # @param period [ActiveSupport::Duration] The duration of each partition.
    # @param number [Integer] The number of partitions to create.
    # @param from [Time] The starting time for creating partitions. If not provided, the current time is used.
    #
    # @return [void]
    def premake(period = 1.month, number = 3, from = nil)
      new_latest_coverage_time = (from || Time.current).utc + (period * number)
      current_coverage_time = from || latest_partition_coverage_time

      while current_coverage_time < new_latest_coverage_time
        create_partition(current_coverage_time, current_coverage_time + period)
        current_coverage_time += period
      end
    end

    # Removes the specified partitions from the database.
    #
    # @param prunable_tables [Array<String>] An array of partition names to be removed.
    # @return [void]
    def remove_partitions(prunable_tables)
      table_names = prunable_tables.each do |partition_name|
        @partition_adapter.detach_partition(partition_name)
        @partition_adapter.drop_partition(partition_name)
      end

      reload_active_ranges(@partition_adapter.get_all_supported_partition_tables)
      table_names
    end

    # Retains a specified number of partition tables older than a given period.
    #
    # @param period [ActiveSupport::Duration] The duration of time to retain partitions.
    # @param number [Integer] The number of partitions to retain.
    # @param from [Time] The reference time from which to calculate the retention period.
    # @return [void]
    def retain(period = 1.months, number = 12, from = Time.current.utc)
      prune_time = (from - (period * (number + 1))).utc

      retain_by_time(prune_time)
    end

    def retain_by_time(prune_time)
      partition_tables = @partition_adapter.get_all_supported_partition_tables
      return if partition_tables.empty?

      prunable_tables = partition_tables.select do |name|
        p_to_time = Time.at(name.split("_").last.to_i).utc
        p_to_time < prune_time
      end

      remove_partitions (prunable_tables)
    end

    def retain_by_partition_count(retain_number)
      partition_tables = @partition_adapter.get_all_supported_partition_tables
      nil if partition_tables.empty?

      current_partition_name = build_partition_name(Time.current, Time.current + 1.hour)
      past_partitions = partition_tables.select { |name| name <= current_partition_name }.sort
      prunable_partitions = past_partitions[.. -(retain_number + 2)] # -1 of current partition and -1 as syntax

      remove_partitions(prunable_partitions)
    end
  end
end
