# ActivePartition

The active_partition gem is a Ruby library designed for Rails application that provides functionality for partitioning data in a database table. Partitioning is a technique used to divide large datasets into smaller, more manageable chunks called partitions. This can improve query performance and make it easier to manage and maintain the data.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_partition'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install active_partition

## Usage

TODO: List all use-cases

Apply partitioning to model.

```ruby
class Event < ActiveRecord::Base
  include ActivePartition::Partitionable
  # the name of partitioned colunn
  self.partitioned_by = "created_at"
  # You can change this range over time. from months to hours.
  self.partition_range = 1.day

  # You can choose 1 of the following 2 options
  # Keep all partitions within a time period
  self.retention_period = 1.month
  # Keep last n partitions
  self.retention_partition_count = 3
  # The start time of the partition range, default is Time.current.beginning_of_hour.utc
  # For example, if today is July 31, and you create a new record.
  # if the partition_start_from is 2021-01-01, the new partition should cover [2024-07-01 00:00:00 UTC...2024-08-01 00:00:00 UTC]
  # if the partition_start_from is nil, the coverage can be [2024-07-31 08:00:00 UTC...2024-08-31 08:00:00 UTC]
  # This configuration help us to sync partition ranges of all partitioned tables.
  # Therefore, you can easy to join/drop/manage related partitioned tables.
  self.partition_start_from = DateTime.new(2021, 1, 1)
end

# auto create a new partition if needed.
Event.create(created_at: Time.current)
# create partition events_p_240404_04_1712203200_1712289600 from 2024-04-04 04:00:00 UTC to 2024-04-05 04:00:00 UTC

# Delete expired partition (you can set cron job to run this command)
Event.delete_expired_partitions

# `premake` is also supported. create 3 1-month partitions
Event.premake 1.month, 3
# create partition outgoing_events_p_240801_04_1722484800_1725163200 from 2024-08-01 04:00:00 UTC to 2024-09-01 04:00:00 UTC
# create partition outgoing_events_p_240901_04_1725163200_1727755200 from 2024-09-01 04:00:00 UTC to 2024-10-01 04:00:00 UTC
# create partition outgoing_events_p_241001_04_1727755200_1730433600 from 2024-10-01 04:00:00 UTC to 2024-11-01 04:00:00 UTC

# You can change premake period if needed. For example, create 2 1-year partition.
Event.premake 1.year, 2
# create partition outgoing_events_p_241101_04_1730433600_1761969600 from 2024-11-01 04:00:00 UTC to 2025-11-01 04:00:00 UTC
# create partition outgoing_events_p_251101_04_1761969600_1793505600 from 2025-11-01 04:00:00 UTC to 2026-11-01 04:00:00 UTC
```

The partition name following the format
```ruby
"#{@table_name}_p_#{readable_from}_#{unix_from}_#{unix_to}"
```



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/active_partition. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/active_partition/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActivePartition project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/active_partition/blob/main/CODE_OF_CONDUCT.md).
