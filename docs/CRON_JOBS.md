# Cloudtasker Cron Jobs

**Note**: this extension requires redis

The Cloudtasker cron job extension allows you to register workers to run at fixed intervals, using a cron expression. You can validate your cron expressions using [crontab.guru](https://crontab.guru).

## Configuration

You can schedule cron jobs by adding the following to your cloudtasker initializer:
```ruby
# The cron job extension is optional and must be explicitly required
require 'cloudtasker/cron_job'

Cloudtasker.configure do |config|
  # Specify your redis url.
  # Defaults to `redis://localhost:6379/0` if unspecified
  config.redis = { url: 'redis://some-host:6379/0' }
end

# Specify all your cron jobs below. This will synchronize your list of cron jobs (cron jobs previously created and not listed below will be removed).
Cloudtasker::Cron::Schedule.load_from_hash!(
  # Run job every minute
  some_schedule_name: {
    worker: 'SomeCronWorker',
    cron: '* * * * *'
  },
  # Run job every hour on the fifteenth minute 
  other_cron_schedule: {
    worker: 'OtherCronWorker',
    cron: '15 * * * *'
  }
)
```

## Using a configuration file

You can maintain the list of cron jobs in a YAML file inside your config folder if you prefer:
```yml
# config/cloudtasker_cron.yml

# Run job every minute
some_schedule_name:
  worker: 'SomeCronWorker'
  cron: => '* * * * *'
  
# Run job every hour on the fifteenth minute 
other_cron_schedule:
  worker: 'OtherCronWorker'
  cron: => '15 * * * *'
```

Then register the jobs inside your Cloudtasker initializer this way:
```ruby
# config/initializers/cloudtasker.rb

# ... Cloudtasker configuration ...

schedule_file = 'config/cloudtasker_cron.yml'
if File.exist?(schedule_file)
  Cloudtasker::Cron::Schedule.load_from_hash!(YAML.load_file(schedule_file))
end
```

