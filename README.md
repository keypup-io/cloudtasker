[![Build Status](https://travis-ci.org/keypup-io/cloudtasker.svg?branch=master)](https://travis-ci.org/keypup-io/cloudtasker) [![Gem Version](https://badge.fury.io/rb/cloudtasker.svg)](https://badge.fury.io/rb/cloudtasker)

# Cloudtasker

Background jobs for Ruby using Google Cloud Tasks.

Cloudtasker provides an easy to manage interface to Google Cloud Tasks for background job processing. Workers can be defined programmatically using the Cloudtasker DSL and enqueued for processing using a simple to use API.

Cloudtasker is particularly suited for serverless applications only responding to HTTP requests and where running a dedicated job processing is not an option (e.g. deploy via [Cloud Run](https://cloud.google.com/run)). All jobs enqueued in Cloud Tasks via Cloudtasker eventually get processed by your application via HTTP requests.

Cloudtasker also provides optional modules for running [cron jobs](docs/CRON_JOBS.md), [batch jobs](docs/BATCH_JOBS.md) and [unique jobs](docs/UNIQUE_JOBS.md).

A local processing server is also available in development. This local server processes jobs in lieu of Cloud Tasks and allows you to work offline.

## Summary

1. [Installation](#installation)
2. [Get started with Rails](#get-started-with-rails)
3. [Configuring Cloudtasker](#configuring-cloudtasker)
    1. [Cloud Tasks authentication & permissions](#cloud-tasks-authentication--permissions)
    2. [Cloudtasker initializer](#cloudtasker-initializer)
4. [Enqueuing jobs](#enqueuing-jobs)
5. [Managing worker queues](#managing-worker-queues)
    1. [Creating queues](#creating-queues)
    2. [Assigning queues to workers](#assigning-queues-to-workers)
6. [Extensions](#extensions)
7. [Working locally](#working-locally)
    1. [Option 1: Cloudtasker local server](#option-1-cloudtasker-local-server)
    2. [Option 2: Using ngrok](#option-2-using-ngrok)
8. [Logging](#logging)
    1. [Configuring a logger](#configuring-a-logger)
    2. [Logging context](#logging-context)
9. [Error Handling](#error-handling)
    1. [HTTP Error codes](#http-error-codes)
    2. [Error callbacks](#error-callbacks)
    3. [Max retries](#max-retries)
10. [Best practices building workers](#best-practices-building-workers)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cloudtasker'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cloudtasker

## Get started with Rails

Cloudtasker is pre-integrated with Rails. Follow the steps below to get started.

Install redis on your machine (this is required by the Cloudtasker local processing server)
```bash
# E.g. using brew
brew install redis
```

Add the following initializer
```ruby
# config/initializers/cloudtasker.rb

Cloudtasker.configure do |config|
  #
  # Adapt the server port to be the one used by your Rails web process
  #
  config.processor_host = 'http://localhost:3000'
  
  #
  # If you do not have any Rails secret_key_base defined, uncomment the following
  # This secret is used to authenticate jobs sent to the processing endpoint
  # of your application.
  #
  # config.secret = 'some-long-token'
end
```

Define your first worker:
```ruby
# app/workers/dummy_worker.rb

class DummyWorker
  include Cloudtasker::Worker

  def perform(some_arg)
    logger.info("Job run with #{some_arg}. This is working!")
  end
end
```

Launch Rails and the local Cloudtasker processing server (or add `cloudtasker` to your foreman config as a `worker` process)
```bash
# In one terminal
> rails s -p 3000

# In another terminal
> cloudtasker
```

Open a Rails console and enqueue some jobs
```ruby
  # Process job as soon as possible
  DummyWorker.perform_async('foo')

  # Process job in 60 seconds
  DummyWorker.perform_in(60, 'foo')
```

Your Rails logs should display the following:
```log
Started POST "/cloudtasker/run" for ::1 at 2019-11-22 09:20:09 +0100

Processing by Cloudtasker::WorkerController#run as */*
  Parameters: {"worker"=>"DummyWorker", "job_id"=>"d76040a1-367e-4e3b-854e-e05a74d5f773", "job_args"=>["foo"], "job_meta"=>{}}

I, [2019-11-22T09:20:09.319336 #49257]  INFO -- [Cloudtasker][d76040a1-367e-4e3b-854e-e05a74d5f773] Starting job...: {:worker=>"DummyWorker", :job_id=>"d76040a1-367e-4e3b-854e-e05a74d5f773", :job_meta=>{}}
I, [2019-11-22T09:20:09.319938 #49257]  INFO -- [Cloudtasker][d76040a1-367e-4e3b-854e-e05a74d5f773] Job run with foo. This is working!: {:worker=>"DummyWorker", :job_id=>"d76040a1-367e-4e3b-854e-e05a74d5f773", :job_meta=>{}}
I, [2019-11-22T09:20:09.320966 #49257]  INFO -- [Cloudtasker][d76040a1-367e-4e3b-854e-e05a74d5f773] Job done: {:worker=>"DummyWorker", :job_id=>"d76040a1-367e-4e3b-854e-e05a74d5f773", :job_meta=>{}}
```

That's it! Your job was picked up by the Cloudtasker local server and sent for processing to your Rails web process.

Now jump to the next section to configure your app to use Google Cloud Tasks as a backend.

## Configuring Cloudtasker

### Cloud Tasks authentication & permissions

The Google Cloud library authenticates via the Google Cloud SDK by default. If you do not have it setup then we recommend you [install it](https://cloud.google.com/sdk/docs/quickstarts).

Other options are available such as using a service account. You can see all authentication options in the [Google Cloud Authentication guide](https://github.com/googleapis/google-cloud-ruby/blob/master/google-cloud-bigquery/AUTHENTICATION.md).

In order to function properly Cloudtasker requires the authenticated account to have the following IAM permissions:
- `cloudtasks.tasks.get`
- `cloudtasks.tasks.create`
- `cloudtasks.tasks.delete`

To get started quickly you can add the `roles/cloudtasks.queueAdmin` role to your account via the [IAM Console](https://console.cloud.google.com/iam-admin/iam). This is not required if your account is a project admin account.


### Cloudtasker initializer

The gem can be configured through an initializer. See below all the available configuration options.

```ruby
# config/initializers/cloudtasker.rb

Cloudtasker.configure do |config|
  #
  # If you do not have any Rails secret_key_base defined, uncomment the following.
  # This secret is used to authenticate jobs sent to the processing endpoint 
  # of your application.
  #
  # Default with Rails: Rails.application.credentials.secret_key_base
  #
  # config.secret = 'some-long-token'

  # 
  # Specify the details of your Google Cloud Task location.
  #
  # This not required in development using the Cloudtasker local server.
  #
  config.gcp_location_id = 'us-central1' # defaults to 'us-east1'
  config.gcp_project_id = 'my-gcp-project'

  #
  # Specify the namespace for your Cloud Task queues.
  #
  # The gem assumes that a least a default queue named 'my-app-default'
  # exists in Cloud Tasks. You can create this default queue using the
  # gcloud SDK or via the `rake cloudtasker:setup_queue` task if you use Rails.
  #
  # Workers can be scheduled on different queues. The name of the queue
  # in Cloud Tasks is always assumed to be prefixed with the prefix below.
  #
  # E.g.
  # Setting `cloudtasker_options queue: 'critical'` on a worker means that
  # the worker will be pushed to 'my-app-critical' in Cloud Tasks.
  #
  # Specific queues can be created in Cloud Tasks using the gcloud SDK or
  # via the `rake cloudtasker:setup_queue name=<queue_name>` task.
  # 
  config.gcp_queue_prefix = 'my-app'

  # 
  # Specify the publicly accessible host for your application
  #
  # > E.g. in development, using the cloudtasker local server
  # config.processor_host = 'http://localhost:3000'
  # 
  # > E.g. in development, using `config.mode = :production` and ngrok
  # config.processor_host = 'https://111111.ngrok.io'
  #
  config.processor_host = 'https://app.mydomain.com'

  # 
  # Specify the mode of operation:
  # - :development => jobs will be pushed to Redis and picked up by the Cloudtasker local server
  # - :production => jobs will be pushed to Google Cloud Tasks. Requires a publicly accessible domain.
  #
  # Defaults to :development unless CLOUDTASKER_ENV or RAILS_ENV or RACK_ENV is set to something else.
  #
  # config.mode = Rails.env.production? || Rails.env.my_other_env? ? :production : :development

  # 
  # Specify the logger to use
  # 
  # Default with Rails: Rails.logger
  # Default without Rails: Logger.new(STDOUT)
  # 
  # config.logger = MyLogger.new(STDOUT)

  # 
  # Specify how many retries are allowed on jobs. This number of retries excludes any
  # connectivity error that would be due to the application being down or unreachable.
  # 
  # Default: 25
  # 
  # config.max_retries = 10

  # 
  # Specify the redis connection hash.
  #
  # This is ONLY required in development for the Cloudtasker local server and in
  # all environments if you use any cloudtasker extension (unique jobs, cron jobs or batch jobs)
  #
  # See https://github.com/redis/redis-rb for examples of configuration hashes.
  #
  # Default: redis-rb connects to redis://127.0.0.1:6379/0
  #
  # config.redis = { url: 'redis://localhost:6379/5' }
end
```

If the default queue `<gcp_queue_prefix>-default` does not exist in Cloud Tasks you should [create it using the gcloud sdk](https://cloud.google.com/tasks/docs/creating-queues). 

Alternatively with Rails you can simply run the following rake task if you have queue admin permissions (`cloudtasks.queues.get` and `cloudtasks.queues.create`).
```bash
bundle exec rake cloudtasker:setup_queue
```

## Enqueuing jobs

Cloudtasker provides multiple ways of enqueuing jobs.

```ruby
# Worker will be processed as soon as possible
MyWorker.perform_async(arg1, arg2)

# Worker will be processed in 5 minutes
MyWorker.perform_in(5 * 60, arg1, arg2)
# or with Rails
MyWorker.perform_in(5.minutes, arg1, arg2)

# Worker will be processed on a specific date
MyWorker.perform_at(Time.parse('2025-01-01 00:50:00Z'), arg1, arg2)
# also with Rails
MyWorker.perform_at(3.days.from_now, arg1, arg2)

# With all options, including which queue to run the worker on.
MyWorker.schedule(args: [arg1, arg2], time_at: Time.parse('2025-01-01 00:50:00Z'), queue: 'critical')
# or
MyWorker.schedule(args: [arg1, arg2], time_in: 5 * 60, queue: 'critical')
```

Cloudtasker also provides a helper for re-enqueuing jobs. Re-enqueued jobs keep the same worker id. Some middlewares may rely on this to track the fact that that a job didn't actually complete (e.g. Cloustasker batch). This is optional and you can always fallback to using exception management (raise an error) to retry/re-enqueue jobs.

E.g.
```ruby
# app/workers/fetch_resource_worker.rb

class FetchResourceWorker
  include Cloudtasker::Worker

  def perform(id)
    # ...do some logic...
    if some_condition
      # Stop and re-enqueue the job to be run again in 10 seconds.
      return reenqueue(10)
    else
      # ...keep going...
    end
  end
end
```

## Managing worker queues

Cloudtasker allows you to manage several queues and distribute workers across them based on job priority. By default jobs are pushed to the `default` queue, which is `<gcp_queue_prefix>-default` in Cloud Tasks.

### Creating queues

More queues can be created using the gcloud sdk or the `cloudtasker:setup_queue` rake task.

E.g. Create a `critical` queue with a concurrency of 5 via the gcloud SDK
```bash
gcloud tasks queues create <gcp_queue_prefix>-critical --max-concurrent-dispatches=5
```

E.g. Create a `real-time` queue with a concurrency of 15 via the rake task (Rails only)
```bash
rake cloudtasker:setup_queue name=real-time concurrency=15
```

When running the Cloudtasker local processing server, you can specify the concurrency for each queue using:
```bash
cloudtasker -q critical,5 -q important,4 -q default,3
```

### Assigning queues to workers

Queues can be assigned to workers via the `cloudtasker_options` directive on the worker class:

```ruby
# app/workers/critical_worker.rb

class CriticalWorker
  include Cloudtasker::Worker

  cloudtasker_options queue: :critical

  def perform(some_arg)
    logger.info("This is a critical job run with arg=#{some_arg}.")
  end
end
```

Queues can also be assigned at runtime when scheduling a job:
```ruby
CriticalWorker.schedule(args: [1], queue: :important)
```

## Extensions
Cloudtasker comes with three optional features:
- Cron Jobs [[docs](docs/CRON_JOBS.md)]: Run jobs at fixed intervals.
- Batch Jobs [[docs](docs/BATCH_JOBS.md)]: Run jobs in jobs and track completion of the overall batch.
- Unique Jobs [[docs](docs/UNIQUE_JOBS.md)]: Ensure uniqueness of jobs based on job arguments. 

## Working locally

Cloudtasker pushes jobs to Google Cloud Tasks, which in turn sends jobs for processing to your application via HTTP POST requests to the `/cloudtasker/run` endpoint of the publicly accessible domain of your application.

When working locally on your application it is usually not possible to have a public domain. So what are the options?

### Option 1: Cloudtasker local server
The Cloudtasker local server is a ruby daemon that looks for jobs pushed to Redis and sends them to your application via HTTP POST requests. The server mimics the way Google Cloud Tasks works, but locally!

You can configure your application to use the Cloudtasker local server using the following initializer:
```ruby
# config/initializers/cloudtasker.rb

Cloudtasker.configure do |config|
  # ... other options
  
  # Push jobs to redis and let the Cloudtasker local server collect them
  # This is the default mode unless CLOUDTASKER_ENV or RAILS_ENV or RACK_ENV is set 
  # to a non-development environment
  config.mode = :development
end
```

The Cloudtasker server can then be started using:
```bash
bundle exec cloudtasker
```

You can as well define a Procfile to manage the cloudtasker process via foreman. Then use `foreman start` to launch both your Rails server and the Cloudtasker local server.
```yaml
# Procfile
web: bundle exec rails s
worker: bundle exec cloudtasker
```

Note that the local development server runs with `5` concurrent threads by default. You can tune the number of threads per queue by running `cloudtasker` the following options:
```bash
bundle exec cloudtasker -q critical,5 -q important,4 -q default,3
```

### Option 2: Using ngrok

Want to test your application end to end with Google Cloud Task? Then [ngrok](https://ngrok.io) is the way to go.

First start your ngrok tunnel:
```bash
ngrok http 3000
```

Take note of your ngrok domain and configure Cloudtasker to use Google Cloud Task in development via ngrok.
```ruby
# config/initializers/cloudtasker.rb

Cloudtasker.configure do |config|
  # Specify your Google Cloud Task queue configuration
  config.gcp_location_id = 'us-central1'
  config.gcp_project_id = 'my-gcp-project'
  config.gcp_queue_prefix = 'my-app'

  # Use your ngrok domain as the processor host
  config.processor_host = 'https://your-tunnel-id.ngrok.io'
  
  # Force Cloudtasker to use Google Cloud Tasks in development
  config.mode = :production
end
```

Finally start Rails to accept jobs from Google Cloud Tasks
```bash
bundle exec rails s
```

## Logging
There are several options available to configure logging and logging context.

### Configuring a logger
Cloudtasker uses `Rails.logger` if Rails is available and falls back on a plain ruby logger `Logger.new(STDOUT)` if not.

It is also possible to configure your own logger. For example you can setup Cloudtasker with [semantic_logger](http://rocketjob.github.io/semantic_logger) by doing the following in your initializer:
```ruby
# config/initializers/cloudtasker.rb

Cloudtasker.configure do |config|
  config.logger = SemanticLogger[Cloudtasker]
end
```

### Logging context
Cloudtasker provides worker contextual information to the worker `logger` method inside your worker methods.

For example:
```ruby
# app/workers/dummy_worker.rb

class DummyWorker
  include Cloudtasker::Worker

  def perform(some_arg)
    logger.info("Job run with #{some_arg}. This is working!")
  end
end
```

Will generate the following log with context `{:worker=> ..., :job_id=> ..., :job_meta=> ...}`
```log
[Cloudtasker][d76040a1-367e-4e3b-854e-e05a74d5f773] Job run with foo. This is working!: {:worker=>"DummyWorker", :job_id=>"d76040a1-367e-4e3b-854e-e05a74d5f773", :job_meta=>{}}
```

The way contextual information is displayed depends on the logger itself. For example with [semantic_logger](http://rocketjob.github.io/semantic_logger) contextual information might not appear in the log message but show up as payload data on the log entry itself (e.g. using the fluentd adapter).

Contextual information can be customised globally and locally using a log context_processor. By default the `Cloudtasker::WorkerLogger` is configured the following way:
```ruby
Cloudtasker::WorkerLogger.log_context_processor = ->(worker) { worker.to_h.slice(:worker, :job_id, :job_meta) }
```

You can decide to add a global identifier for your worker logs using the following:
```ruby
# config/initializers/cloudtasker.rb

Cloudtasker::WorkerLogger.log_context_processor = lambda { |worker|
  worker.to_h.slice(:worker, :job_id, :job_meta).merge(app: 'my-app')
}
```

You could also decide to log all available context - including arguments passed to `perform` - for specific workers only:
```ruby
# app/workers/full_context_worker.rb

class FullContextWorker
  include Cloudtasker::Worker

  cloudtasker_options log_context_processor: ->(worker) { worker.to_h }

  def perform(some_arg)
    logger.info("This log entry will have full context!")
  end
end
```

See the [Cloudtasker::Worker class](lib/cloudtasker/worker.rb) for more information on attributes available to be logged in your `log_context_processor` proc.

## Error Handling

Jobs failing will automatically return an HTTP error to Cloud Task and trigger a retry at a later time. The number of retries Cloud Task will do depends on the configuration of your queue in Cloud Tasks.

### HTTP Error codes

Jobs failing will automatically return the following HTTP error code to Cloud Tasks, based on the actual reason:

| Code | Description |
|------|-------------|
| 205 | The job is dead and has been removed from the queue |
| 404 | The job has specified an incorrect worker class.  |
| 422 | An error happened during the execution of the worker (`perform` method) |

### Error callbacks

Workers can implement the `on_error(error)` and `on_dead(error)` callbacks to do things when a job fails during its execution:

E.g.
```ruby
# app/workers/handle_error_worker.rb

class HandleErrorWorker
  include Cloudtasker::Worker

  def perform
    raise(ArgumentError)
  end

  # The runtime error is passed as an argument.
  def on_error(error)
    logger.error("The following error happened: #{error}")
  end

  # The job has been retried too many times and will be removed
  # from the queue.
  def on_dead(error)
    logger.error("The job died with the following error: #{error}")
  end
end
```

### Max retries

By default jobs are retried 25 times - using an exponential backoff - before being declared dead. This number of retries can be customized locally on workers and/or globally via the Cloudtasker initializer.

Note that the number of retries set on your Cloud Task queue should be many times higher than the number of retries configured in Cloudtasker because Cloud Task also includes failures to connect to your application. Ideally set the number of retries to `unlimited` in Cloud Tasks.

E.g. Set max number of retries globally via the cloudtasker initializer.
```ruby
# config/initializers/cloudtasker.rb

Cloudtasker.configure do |config|
  # 
  # Specify how many retries are allowed on jobs. This number of retries excludes any
  # connectivity error that would be due to the application being down or unreachable.
  # 
  # Default: 25
  # 
  config.max_retries = 10
end
```

E.g. Set max number of retries to 3 on a given worker

E.g.
```ruby
# app/workers/some_error_worker.rb

class SomeErrorWorker
  include Cloudtasker::Worker

  # This will override the global setting
  cloudtasker_options max_retries: 3

  def perform()
    raise(ArgumentError)
  end
end
```



## Best practices building workers

Below are recommendations and notes about creating workers.

### Use primitive arguments
Pushing a job via `MyWorker.perform_async(arg1, arg2)` will serialize all arguments as JSON. Cloudtasker does not do any magic marshalling and therefore passing user-defined class instance as arguments is likely to make your jobs fail because of JSON serialization/deserialization.

When defining your worker `perform` method, use primitive arguments (integers, strings, hashes).

Don't do that:
```ruby
# app/workers/user_email_worker.rb

class UserEmailWorker
  include Cloudtasker::Worker

  def perform(user)
    user.reload.send_email
  end
end
```

Do that:
```ruby
# app/workers/user_email_worker.rb

class UserEmailWorker
  include Cloudtasker::Worker

  def perform(user_id)
    User.find_by(id: user_id)&.send_email
  end
end
```

### Assume hash arguments are stringified
Because of JSON serialization/deserialization hashes passed to `perform_*` methods will eventually be passed as stringified hashes to the worker `perform` method.

```ruby
# Enqueuing a job with:
MyWorker.perform_async({ foo: 'bar', 'baz' => { key: 'value' } })

# will be processed as
MyWorker.new.perform({ 'foo' => 'bar', 'baz' => { 'key' => 'value' } })
```

### Be careful with default arguments
Default arguments passed to the `perform` method are not actually considered as job arguments. Default arguments will therefore be ignored in contextual logging and by extensions relying on arguments such as the [unique job](docs/UNIQUE_JOBS.md) extension.

Consider the following worker:
```ruby
# app/workers/user_email_worker.rb

class UserEmailWorker
  include Cloudtasker::Worker

  cloudtasker_options lock: :until_executed

  def perform(user_id, time_at = Time.now.iso8601)
    User.find_by(id: user_id)&.send_email(Time.parse(time_at))
  end
end
```

If you enqueue this worker by omitting the second argument `MyWorker.perform_async(123)` then:
- The `time_at` argument will not be included in contextual logging
- The `time_at` argument will be ignored by the `unique-job` extension, meaning that job uniqueness will be only based on the `user_id` argument.

### Handling big job payloads
Google Cloud Tasks enforces a limit of 100 KB for job payloads. Taking into accounts Cloudtasker authentication headers and meta information this leave ~85 KB of free space for JSONified job arguments.

Any excessive job payload (> 100 KB) will raise a `Cloudtasker::MaxTaskSizeExceededError`, both in production and development mode.

If you feel that a job payload is going to get big, prefer to store the payload using a datastore (e.g. Redis) and pass a reference to the job to retrieve the payload inside your job `perform` method.

E.g. Define a job like this
```ruby
# app/workers/big_payload_worker.rb

class BigPayloadWorker
  include Cloudtasker::Worker

  def perform(payload_id)
    data = Rails.cache.fetch(payload_id)
    # ...do some processing...
  end
end
```

Then enqueue your job like this:
```ruby
# Fetch and store the payload
data = ApiClient.fetch_thousands_of_records
payload_id = SecureRandom.uuid
Rails.cache.write(payload_id, data)

# Enqueue the processing job
BigPayloadWorker.perform_async(payload_id)
```

### Sizing the concurrency of your queues

When defining the max concurrency of your queues (`max_concurrent_dispatches` in Cloud Tasks) you must keep in mind the maximum number of threads that your application provides. Otherwise your application threads may eventually get exhausted and your users will experience outages if all your web threads are busy running jobs.

#### With server based applications

Let's consider an application deployed in production with 3 instances, each having `RAILS_MAX_THREADS` set to `20`. This gives us a total of `60` threads available.

Now let's say that we distribute jobs across two queues: `default` and `critical`. We can set the concurrency of each queue depending on the profile of the application:

E.g. 1: The application serves requests from web users and runs backgrounds jobs in a balanced way
```
concurrency for default queue: 20
concurrency for critical queue: 10

Total threads consumed by jobs at most: 30
Total threads always available to web users at worst: 30
```

E.g. 2: The application is a micro-service API heavily focused on running jobs (e.g. data processing)
```
concurrency for default queue: 35
concurrency for critical queue: 15

Total threads consumed by jobs at most: 50
Total threads always available to API clients at worst: 10
```

Also always ensure that your total number of threads does not exceed the available number of database connections (if you use any).

#### With serverless applications

In a serverless context your application will be scaled up/down based on traffic. When we say 'traffic' this includes requests from Cloud Tasks to run jobs.

Because your application is auto-scaled - and assuming you haven't set a maximum - your job processing capacity if theoretically unlimited. The main limiting factor in a serverless context becomes external constraints such as the number of database connections available.

To size the concurrency of your queues you should therefore take the most limiting factor - which is often the database connection pool size of relational databases - and use the calculations of the previous section with this limiting factor as the capping parameter instead of threads.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/keypup-io/cloudtasker. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Cloudtasker project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/keypup-io/cloudtasker/blob/master/CODE_OF_CONDUCT.md).

## Author

Provided with :heart: by [keypup.io](https://keypup.io/)
