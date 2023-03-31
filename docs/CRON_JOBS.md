# Cloudtasker Cron Jobs

**Note**: this extension requires redis

The Cloudtasker cron job extension allows you to register workers to run at fixed intervals, using a cron expression. You can validate your cron expressions using [crontab.guru](https://crontab.guru).

## Configuration

You can schedule cron jobs by adding the following to your cloudtasker initializer:
```ruby
# The cron job extension is optional and must be explicitly required
require 'cloudtasker/cron'

Cloudtasker.configure do |config|
  # Specify your redis url.
  # Defaults to `redis://localhost:6379/0` if unspecified
  config.redis = { url: 'redis://some-host:6379/0' }
end

# Specify all your cron jobs below. This will synchronize your list of cron jobs (cron jobs previously created and not listed below will be removed).
unless Rails.env.test?
  Cloudtasker::Cron::Schedule.load_from_hash!(
    # Run job every minute
    some_schedule_name: {
      worker: 'SomeCronWorker',
      cron: '* * * * *'
    },
    # Run job every hour on the fifteenth minute 
    other_cron_schedule: {
      worker: 'OtherCronWorker',
      cron: '15 * * * *',
      queue: 'critical'
      args: ['foo', 'bar']
    }
  )
end
```

## Using a configuration file

You can maintain the list of cron jobs in a YAML file inside your config folder if you prefer:
```yml
# config/cloudtasker_cron.yml

# Run job every minute
some_schedule_name:
  worker: 'SomeCronWorker'
  cron: '* * * * *'
  
# Run job every hour on the fifteenth minute 
other_cron_schedule:
  worker: 'OtherCronWorker'
  cron: '15 * * * *'
```

Then register the jobs inside your Cloudtasker initializer this way:
```ruby
# config/initializers/cloudtasker.rb

# ... Cloudtasker configuration ...

schedule_file = 'config/cloudtasker_cron.yml'
if File.exist?(schedule_file) && !Rails.env.test?
  Cloudtasker::Cron::Schedule.load_from_hash!(YAML.load_file(schedule_file))
end
```

## With Puma Cluster-mode
Due to this issue with gRPC here: https://github.com/grpc/grpc/issues/7951.

TLTR: 
> Forking processes and using gRPC across processes is not supported behavior due to very low-level resource issues. Either delay your use of gRPC until you've forked from fresh processes (similar to Python 3's use of a zygote process), or don't expect things to work after a fork.

In order to make it works, we should schedule cron jobs (which triggers gPRC calls) once puma is booted.

Example:
```ruby
config/puma.rb

workers ENV.fetch("WEB_CONCURRENCY") { 2 }
preload_app!

on_booted do
  schedule_file = "config/cloudtasker_cron.yml"
  if File.exist?(schedule_file) && !Rails.env.test?
    Cloudtasker::Cron::Schedule.load_from_hash!(YAML.load_file(schedule_file))
  end
end
```

## Limitations
GCP Cloud Tasks does not allow tasks to be scheduled more than 30 days (720h) in the future. Cron schedules should therefore be limited to 30 days intervals at most.

If you need to schedule a job to run on a monthly basis (e.g. on the first of the month), schedule this job to run every day then add the following logic in your job:
```ruby
#
# Cron schedule (8am UTC every day): 0 8 * * *
#
class MyMonthlyWorker
  include Cloudtasker::Worker

  def perform(*args)
    # Abort unless we're the first of the month
    return unless Time.current.day == 1

    # ... job logic
  end
end
```

The same approach can be used to schedule a job every quarter.
```ruby
#
# Cron schedule (8am UTC every day): 0 8 * * *
#
class MyQuarterlyWorker
  include Cloudtasker::Worker

  def perform(*args)
    # Abort unless we're the first month of a quarter (Jan, Apr, Jul, Oct)
    return unless Time.current.month == 1
    
    # Abort unless we're the first of the month
    return unless Time.current.day == 1

    # ... job logic
  end
end
```
