# Cloudtasker Batch Jobs

**Note**: this extension requires redis

The Cloudtasker batch job extension allows to add sub-jobs to regular jobs. This adds the ability to enqueue a list of jobs and track their overall progression as a group of jobs (a "batch"). This extension allows jobs to define callbacks in their worker to track completion of the batch and take actions based on that.

## Configuration

You can enable batch jobs by adding the following to your cloudtasker initializer:
```ruby
# The batch job extension is optional and must be explicitly required
require 'cloudtasker/batch'

Cloudtasker.configure do |config|
  # Specify your redis url.
  # Defaults to `redis://localhost:6379/0` if unspecified
  config.redis = { url: 'redis://some-host:6379/0' }
end
```

## Example

The following example defines a worker that adds itself to the batch with different arguments then monitors the success of the batch.

```ruby
class BatchWorker
  include Cloudtasker::Worker

  def perform(level, instance)
    3.times { |n| batch.add(self.class, level + 1, n) } if level < 2
  end

  # Invoked when any descendant (e.g. sub-sub job) is complete
  def on_batch_node_complete(child)
    logger.info("Direct or Indirect child complete: #{child.job_id}")
  end

  # Invoked when a direct descendant is complete
  def on_child_complete(child)
    logger.info("Direct child complete: #{child.job_id}")
  end

  # Invoked when all chidren have finished
  def on_batch_complete
    Rails.logger.info("Batch complete")
  end
end
```

## Available callbacks

The following callbacks are available on your workers to track the progress of the batch:

| Callback | Argument | Description |
|------|-------------|-----------|
| `on_batch_node_complete` | `The child job` | Invoked when any descendant (e.g. sub-sub job) successfully completes   |
| `on_child_complete` | `The child job` | Invoked when a direct descendant successfully completes   |
| `on_child_error` | `The child job` | Invoked when a child fails |
| `on_child_dead` | `The child job` | Invoked when a child has exhausted all of its retries |s
| `on_batch_complete` | none | Invoked when all chidren have finished or died  |

## Queue management

Jobs added to a batch inherit the queue of the parent. It is possible to specify a different queue when adding a job to a batch using `add_to_queue` batch method.

E.g.

```ruby
def perform
  batch.add_to_queue(:critical, SubWorker, arg1, arg2, arg3)
end
```

## Batch completion

Batches complete when all children have successfully completed or died (all retries exhausted).

Jobs that fail in a batch will be retried based on the `max_retries` setting configured globally or on the worker itself. The batch will be considered `pending` while workers retry. Therefore it may be a good idea to reduce the number of retries on your workers using `cloudtasker_options max_retries: 5` to ensure your batches don't hang for too long.

## Batch progress tracking

You can access progression statistics in callback using `batch.progress`. See the [BatchProgress](../lib/cloudtasker/batch/batch_progress.rb) class for more details.

E.g.
```ruby
def on_batch_node_complete(_child_job)
  progress = batch.progress
  logger.info("Total: #{progress.total}")
  logger.info("Completed: #{progress.completed}")
  logger.info("Progress: #{progress.percent.to_i}%")
end
```

**Since:** `v0.12.rc5`  
By default the `progress` method only considers the direct child jobs to evaluate the batch progress. You can pass `depth: somenumber` to the `progress` method to calculate the actual batch progress in a more granular way. Be careful however that this method recursively calculates progress on the sub-batches and is therefore expensive.

E.g.
```ruby
def on_batch_node_complete(_child_job)
  # Considers the children for batch progress calculation
  progress_0 = batch.progress # same as batch.progress(depth: 0)

  # Considers the children and grand-children for batch progress calculation
  progress_1 = batch.progress(depth: 1)

  # Considers the children, grand-children and grand-grand-children for batch progress calculation
  progress_2 = batch.progress(depth: 3)

  logger.info("Progress: #{progress_1.percent.to_i}%")
  logger.info("Progress: #{progress_2.percent.to_i}%")
end
```
