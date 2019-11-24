# Cloudtasker

Background jobs for Ruby using Google Cloud Tasks.

Cloudtasker provides an easy to manage interface to Google Cloud Tasks for background job processing. Workers can be defined programmatically using the Cloudtasker DSL and enqueued for processing using a simple to use API.

Cloudtasker is particularly suited for serverless applications only responding to HTTP requests and where running a dedicated job processing is not an options. All jobs enqueued in Cloud Tasks via Cloudtasker eventually gets processed by your application via HTTP requests.

Cloudtasker also provides optional modules for running [cron jobs](docs/CRON_JOBS.md), [batch jobs](docs/BATCH_JOBS.md) and [unique jobs](docs/UNIQUE_JOBS.md).

A local processing server is also available in development. This local server processes jobs in lieu of Cloud Tasks and allow you to work offline.

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

Install redis on your machine (this required by the Cloudtasker local processing server)
```bash
# E.g. using brew
brew install redis
```

Add the following initializer
```ruby
# config/initializers/cloudtasker.rb

Cloudtasker.configure do |config|
  # Adapt the server port to be the one used by your Rails web process
  config.processor_host = 'http://localhost:3000'
  
  # If you do not have any Rails secret_key_base defined, uncomment the following
  # This secret is used to authenticate jobs sent to the processing endpoint
  # of your application.
  # config.secret = 'some-long-token'
end
```

Define your first worker
```ruby
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

Open a Rails console and enqueue your job
```ruby
  # Process job as soon as possible
  DummyWorker.perform_async('foo')

  # Process job in 60 seconds
  DummyWorker.perform_in(10, 'foo')
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

Now jump to the next section to configure your app to use Google Tasks.

## Configuring Cloudtasker

The Cloustaker gem can be configured through an initializer. See below all the available configuration options.

```ruby
# config/initializers/cloudtasker.rb

Cloudtasker.configure do |config|
  #
  # If you do not have any Rails secret_key_base defined, uncomment the following.
  # This secret is used to authenticate jobs sent to the processing endpoint 
  # of your application.
  #
  # config.secret = 'some-long-token'

  # 
  # Specify the details of your Google Cloud Task queue.
  #
  # This not required in development using the Cloudtasker local server.
  #
  config.gcp_location_id = 'us-central1' # defaults to 'us-east1'
  config.gcp_project_id = 'my-gcp-project'
  config.gcp_queue_id = 'my-queue'

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
  # :development => jobs will be pushed to Redis and picked up by the Cloudtasker local server
  # :production => jobs will be pushed to Google Cloud Tasks. Requires a publicly accessible domain.
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

## Enqueuing jobs

Cloudtasker provides multiple ways of enqueuing jobs.

```ruby
# Worker will be processed as soon as possible
MyWorker.perform_async(arg1, arg2)

# Worker will be processed in 5 minutes
MyWorker.perform_in(5 * 60, arg1, arg2)
# or with Rails
MyWorker.perform_in(5.minutes, arg1, arg2)

# Worker will be processed on specific date
MyWorker.perform_at(Time.parse('2025-01-01 00:50:00Z'), arg1, arg2)
# also with Rails
MyWorker.perform_at(3.days.from_now, arg1, arg2)
```

Cloudtasker also provides a helper for re-enqueuing jobs. Re-enqueued jobs keep the same worker id. Some middlewares may rely on this to track the fact that that a job didn't actually complete (e.g. Cloustasker batch). This is optional and you can always fallback to using exception management (raise an error) to retry/re-enqueue jobs.

E.g.
```ruby
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

You can configure your applicatiion to use the Cloudtasker local server using the following initializer:
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
cloudtasker
# or
bundle exec cloudtasker
```

You can as well define a Procfile to manage the cloudtasker process via foreman. Then use `foreman start` to launch both your Rails server and the Cloudtasker local server.
```yaml
# Procfile
web: rails s
worker: cloudtasker
```

### Option 2: Using ngrok

Want to test your application end to end with Google Cloud Task? Then [ngrok](https://ngrok.io) is the way to go.

First start your ngrok tunnel and take note of the :
```bash
ngrok tls 3000
```

Take note of your ngrok domain and configure Cloudtasker to use Google Cloud Task in development via ngrok.
```ruby
# config/initializers/cloudtasker.rb

Cloudtasker.configure do |config|
  # Specify your Google Cloud Task queue configuration
  # config.gcp_location_id = 'us-central1'
  # config.gcp_project_id = 'my-gcp-project'
  # config.gcp_queue_id = 'my-queue'

  # Use your ngrok domain as the processor host
  config.processor_host = 'https://your-tunnel-id.ngrok.io'
  
  # Force Cloudtasker to use Google Cloud Tasks in development
  config.mode = :production
end
```

Finally start Rails to accept jobs from Google Cloud Tasks
```bash
rails s
```

## Logging
There are several options available to configure logging and logging context.

### Configuring a logger
Cloudtasker uses `Rails.logger` if Rails is available and falls back on a plain ruby logger `Logger.new(STDOUT)` if not.

It is also possible to configure your own logger. For example you can setup Cloudtasker with [semantic_logger](http://rocketjob.github.io/semantic_logger) by doing the following your initializer:
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

You could also decide to log all available context (including arguments passed to perform) for specific workers only:
```ruby
class FullContextWorker
  include Cloudtasker::Worker

  cloudtasker_options log_context_processor: ->(worker) { worker.to_h }

  def perform(some_arg)
    logger.info("This log entry will have full context!")
  end
end
```

See the [Cloudtasker::Worker class](blob/master/lib/cloudtasker/worker.rb) for more information on attributes available to be logged in your `log_context_processor` proc.

## Error Handling

Jobs failing will automatically return an HTTP error to Cloud Task and trigger a retry at a later time. The number of retries Cloud Task will do depends on the configuration of your queue in Cloud Tasks.

### HTTP Error codes

Jobs failing will automatically return the following HTTP error code to Cloud Tasks, based on the actual reason:

| Code | Description |
|------|-------------|-----------|
| 205 | The job is dead and has been removed from the queue |
| 404 | The job has specified an incorrect worker class.  |
| 422 | An error happened during the execution of the worker (`perform` method) |

### Error callbacks

Workers can implement the `on_error(error)` and `on_dead(error)` callbacks to do things when a job fails during its execution:

E.g.
```ruby
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
class UserEmailWorker
  include Cloudtasker::Worker

  def perform(user)
    user.reload.send_email
  end
end
```

Do that:
```ruby
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
Default arguments passed to the `perform` method are not actually considered as job arguments. Default arguments will therefore be ignored in contextual logging and by extensions relying on arguments such as the `unique-job` extension.

Consider the following worker:
```ruby
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
Keep in mind that jobs are pushed to Google Cloud Tasks via API and then delivered to your application via API as well. Therefore any excessive job payload will slow down the enqueuing of jobs and create additional processing when receiving the job.

If you feel that a job payload is going to get big, prefer to store the payload using a datastore (e.g. Redis) and pass a reference to the job to retrieve the payload inside your job `perform` method.

E.g. Define a job like this
```ruby
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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/alachaum/cloudtasker. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Cloudtasker project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/alachaum/cloudtasker/blob/master/CODE_OF_CONDUCT.md).

## Author

Provided with :heart: by [keypup.io](https://keypup.io/)
