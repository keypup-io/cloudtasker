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

## Lock Time To Live (TTL) & deadlocks
**Note**: Lock TTL has been introduced in `v0.10.rc6`

To make jobs unique Cloudtasker sets a lock key - a hash of class name + job arguments - in Redis. Unique crash situations may lead to lock keys not being cleaned up when jobs complete - e.g. Redis crash with rollback from last known state on disk. Situations like these may lead to having a unique job deadlock: jobs with the same class and arguments would stop being processed because they're unable to acquire a lock that will never be cleaned up.

In order to prevent deadlocks Cloudtasker configures lock keys to automatically expire in Redis after `job schedule time + lock_ttl (default: 10 minutes)`. This forced expiration ensures that deadlocks eventually get cleaned up shortly after the expected run time of a job.

The `lock_ttl (default: 10 minutes)` duration represent the expected max duration of the job. The default 10 minutes value was chosen because it's twice the default request timeout value in Cloud Run. This usually leaves enough room for queue lag (5 minutes) + job processing (5 minutes).

Queue lag is certainly the most unpredictable factor here. Job processing time is less of a factor. Jobs running for more than 5 minutes should be split into sub-jobs to limit invocation time over HTTP anyway. Cloudtasker [batch jobs](BATCH_JOBS.md) can help split big jobs into sub-jobs in an atomic way.

The default lock key expiration of `job schedule time + 10 minutes` may look aggressive but it is a better choice than having real-time jobs stuck for X hours after a crash recovery.

We **strongly recommend** adapting the `lock_ttl` option either globally or for each worker based on expected queue lag and job duration.

**Example 1**: Global configuration
```ruby
# config/initializers/cloudtasker.rb

# General Cloudtasker configuration
Cloudtasker.configure do |config|
  # ...
end

# Unique job extension configuration
Cloudtasker::UniqueJob.configure do |config|
  config.lock_ttl = 3 * 60 # 3 minutes
end
```

**Example 2**: Worker-level - fast
```ruby
# app/workers/realtime_worker_on_fast_queue.rb

class RealtimeWorkerOnFastQueue
  include Cloudtasker::Worker

  # Ensure lock is removed 30 seconds after schedule time
  cloudtasker_options lock: :until_executing, lock_ttl: 30

  def perform(arg1, arg2)
    # ...
  end
end
```

**Example 3**: Worker-level - slow
```ruby
# app/workers/non_critical_worker_on_slow_queue.rb

class NonCriticalWorkerOnSlowQueue
  include Cloudtasker::Worker

  # Ensure lock is removed 24 hours after schedule time
  cloudtasker_options lock: :until_executing, lock_ttl: 3600 * 24

  def perform(arg1, arg2)
    # ...
  end
end
```

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
