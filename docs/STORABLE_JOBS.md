# Cloudtasker Storable Jobs

**Supported since**: `v0.14.0`  
**Note**: this extension requires redis

The Cloudtasker storage extension allows you to park jobs in a specific garage lane and enqueue (pull) them when specific conditions have been met.

This extension is useful when you need to prepare some jobs (e.g. you are retrieving data from an API and must process some of it asynchronously) but only process them when some programmatic conditions have been met (e.g. a series of preliminary preparation jobs have run successfully). Using parked jobs is a leaner (and cheaper) approach than using guard logic in the `perform` method to re-enqueue a job until a set of conditions is satisfied. The latter tends to generate a lot of jobs/logs pollution.

## Configuration

You can enable storable jobs by adding the following to your cloudtasker initializer:
```ruby
# The storable extension is optional and must be explicitly required
require 'cloudtasker/storable'

Cloudtasker.configure do |config|
  # Specify your redis url.
  # Defaults to `redis://localhost:6379/0` if unspecified
  config.redis = { url: 'redis://some-host:6379/0' }
end
```

Then you can make workers storable by including the `Cloudtasker::Storable::Worker` concern into your workers:
```ruby
class MyWorker
  include Cloudtasker::Worker
  include Cloudtasker::Storable::Worker

  def perform(...)
    # Do stuff
  end
end
```

## Parking jobs
You can park jobs to a specific garage lane using the `push_to_store(store_name, *worker_args)` class method:
```ruby
MyWorker.push_to_store('some-customer-reference:some-task-group', job_arg1, job_arg2)
```

## Pulling jobs
You can pull and enqueue jobs using the `pull_all_from_store(store_name)` class method:
```ruby
MyWorker.pull_all_from_store('some-customer-reference:some-task-group')
```

If you need to enqueue jobs with specific options or using any special means, you can call `pull_all_from_store(store_name)` with a block. When a block is passed the method yield each worker's set of arguments.
```ruby
# Delay the enqueuing of parked jobs by 30 seconds
MyWorker.pull_all_from_store('some-customer-reference:some-task-group') do |args|
  MyWorker.perform_in(30, *args)
end

# Enqueue parked jobs on a specific queue, with a 10s delay
MyWorker.pull_all_from_store('some-customer-reference:some-task-group') do |args|
  MyWorker.schedule(args: args, time_in: 10, queue: 'critical')
end

# Enqueue parked jobs as part of a job's current batch (the logic below assumes
# we are inside a job's `perform` method)
MyWorker.pull_all_from_store('some-customer-reference:some-task-group') do |args|
  batch.add(MyWorker, *args)

  # Or with a specific queue
  # batch.add_to_queue('critical', SubWorker, *args)
end
```
