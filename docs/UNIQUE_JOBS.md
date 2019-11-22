# Cloudtasker Unique Jobs

**Note**: this extension requires redis

The Cloudtasker unique job extension allows you to define uniqueness rules for jobs you schedule or process based on job arguments.

## Configuration

You can enable unique jobs by adding the following to your cloudtasker initializer:
```ruby
# The unique job extension is optional and must be explicitly required
require 'cloudtasker/unique_job'

Cloudtasker.configure do |config|
  # Specify your redis url.
  # Defaults to `redis://localhost:6379/0` if unspecified
  config.redis = { url: 'redis://some-host:6379/0' }
end
```

## Example

The following example defines a worker that prevents more than one instance to run at the same time for the set of provided arguments. Any identical job scheduled after the first one will be re-enqueued until the first job has finished running.

```ruby
class UniqAtRuntimeWorker
  include Cloudtasker::Worker
  
  #
  # lock: specify the phase during which a worker must be unique based on class and arguments.
  # In this case the worker will be unique while it is processed.
  # Other types of locks are available - see below the rest of the documentation.
  #
  # on_conflict: specify what to do if another identical instance enter the lock phase. 
  # In this case the worker will be rescheduled until the lock becomes available.
  #
  cloudtasker_options lock: :while_executing, on_conflict: :reschedule

  def perform(arg1, arg2)
    sleep(10)
  end
end
```

Considering the worker and the code below:
```ruby
# Enqueue two jobs successively
UniqAtRuntimeWorker.perform_async # Job 1
UniqAtRuntimeWorker.perform_async # Job 2
```

The following will happen
1) Cloud Tasks sends job 1 and job 2 for processing to Rails
2) Job 1 acquires a `while_executing` lock
3) Job 2 does not acquire the lock and moves to `on_conflict` which is `reschedule`
4) Job 2 gets rescheduled in 5 seconds
5) Job 1 keeps processing for 5 seconds
6) Job 2 is re-sent by Cloud Tasks and cannot acquire the lock, therefore is rescheduled.
7) Job 1 processes for another 5 seconds and finishes (total = 10 seconds of processing)
8) Job 2 is re-sent by Cloud Tasks, can acquire the lock this time and starts processing

## Available locks

Below is the list of available locks that can be specified through the `cloudtasker_options lock: ...` configuration option.

For each lock strategy the table specifies the lock period (start/end) and which `on_conflict` strategies are available.

| Lock | Starts when | Ends when | On Conflict strategies |
|------|-------------|-----------|------------------------|
| `until_executing` | The job is scheduled | The job starts processing | `reject` (default) or `raise` |
| `while_executing` | The job starts processing | The job ends processing | `reject` (default), `reschedule` or `raise` |
| `until_executed` | The job is scheduled | The job ends processing | `reject` (default) or `raise` |

## Available conflict strategies

Below is the list of available conflict strategies can be specified through the `cloudtasker_options on_conflict: ...` configuration option.

| Strategy | Available with | Description |
|----------|----------------|----------------|
| `reject` | All locks | This is the default strategy. The job will be discarded when a conflict occurs |
| `raise` | All locks | A `Cloudtasker::UniqueJob::LockError` will be raised when a conflict occurs |
| `reschedule` | `while_executing` | The job will be rescheduled 5 seconds later when a conflict occurs |

## Configuring unique arguments

By default Cloudtasker considers all job arguments to evaluate the uniqueness of a job. This behaviour is configurable per worker by defining a `unique_args` method on the worker itself returning the list of args defining uniqueness.

Example 1: Uniqueness based on a subset of arguments
```ruby
class UniqBasedOnTwoArgsWorker
  include Cloudtasker::Worker
  
  cloudtasker_options lock: :until_executed

  # Only consider the first two args when evaluating uniqueness
  def unique_args(args)
    [arg[0], arg[1]]
  end

  def perform(arg1, arg2, arg3)
    # ...
  end
end
```

Example 2: Uniqueness based on modified arguments
```ruby
class ModuloArgsWorker
  include Cloudtasker::Worker
  
  cloudtasker_options lock: :until_executed

  # The remainder of `some_int` modulo 5 will be considered for
  # uniqueness instead of the full value of `some_int`
  def unique_args(args)
    [arg[0], arg[1], arg[2] % 5]
  end

  def perform(arg1, arg2, some_int)
    # ...
  end
end
```

## Beware of default method arguments

Default method arguments are ignored when evaluating worker uniqueness. See [this section](../../../#be-careful-with-default-arguments) for more details.
