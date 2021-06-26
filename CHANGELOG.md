# Changelog

## Latest RC [v0.12.rc11](https://github.com/keypup-io/cloudtasker/tree/v0.12.rc11) (2021-06-26)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.11.0...v0.12.rc11)

**Improvements:**
- ActiveJob: do not double log errors (ActiveJob has its own error logging)
- Batch callbacks: Retry jobs when completion callback fails
- Batch state: use native Redis hashes to store batch state instead of a serialized hash in a string key
- Batch progress: restrict calculation to direct children by default. Allow depth to be specified. Calculating progress using all tree jobs created significant delays on large batches.
- Batch redis usage: cleanup batches as they get completed or become dead to avoid excessive redis usage with large batches.
- Batch expansion: Inject `parent_batch` in jobs. Can be used to expand the parent batch the job is in.
- Configuration: allow configuration of Cloud Tasks `dispatch deadline` at global and worker level
- Configuration: allow specifying global `on_error` and `on_dead` callbacks for error reporting
- Cron jobs: Use Redis Sets instead of key pattern matching for resource listing
- Error logging: Use worker logger so as to include context (job args etc.)
- Error logging: Do not log exception and stack trace separately, combine them instead.
- Local server: Use Redis Sets instead of key pattern matching for resource listing
- Local server: Guard against nil tasks to prevent job daemon failures
- Performance: remove use of redis locks and rely on atomic transactions instead for Batch and Unique Job.
- Worker: raise DeadWorkerError instead of MissingWorkerArgumentsError when arguments are missing. This is more consistent with what middlewares expect.
- Worker redis usage: delete redis payload storage once the job is successful or dead instead of expiring the key.

**Fixed bugs:**
- Retries: Enforce job retry limit on job processing. There was an edge case where jobs could be retried indefinitely on batch callback errors.

## [v0.11.0](https://github.com/keypup-io/cloudtasker/tree/v0.11.0) (2021-03-11)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.10.0...v0.11.0)

**Improvements:**
- Worker: drop job (return 205 response) when worker arguments are not available (e.g. arguments were stored in Redis and the latter was flushed)
- Rails: add ActiveJob adapter (thanks @vovimayhem)

## [v0.10.1](https://github.com/keypup-io/cloudtasker/tree/v0.10.1) (2020-10-05)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.10.0...v0.10.1)

**Fixed bugs:**
- Local server: delete dead task from local server queue
- Logging: fix log processing with `semantic_logger` `v4.7.2`. Accept any args on block passed to the logger.
- Worker: fix configuration of `max_retries` at worker level

## [v0.10.0](https://github.com/keypup-io/cloudtasker/tree/v0.10.0) (2020-09-02)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.9.3...v0.10.0)

**Improvements:**
- Logging: Add worker name in log messages
- Logging: Add job duration in log messages
- Logging: Add Cloud Cloud Task ID in log messages
- Unique Job: Support TTL for lock keys. This feature prevents queues from being dead-locked when a critical crash occurs while processing a unique job.
- Worker: support payload storage in Redis instead of sending the payload to Google Cloud Tasks. This is useful when job arguments are expected to exceed 100kb, which is the limit set by Google Cloud Tasks

**Fixed bugs:**
- Local processing error: improve error handling and retries around network interruptions
- Redis client: prevent deadlocks in high concurrency scenario by slowing down poll time and enforcing lock expiration
- Redis client: use connecion pool with Redis to prevent race conditions
- Google API: improve error handling on job creation
- Google API: use the `X-CloudTasks-TaskRetryCount` instead of `X-CloudTasks-TaskExecutionCount` to detect how many retries Google Cloud Tasks has performed. Using `X-CloudTasks-TaskRetryCount` is theoretically less accurate than using `X-CloudTasks-TaskExecutionCount` because it includes the number of "app unreachable" retries but `X-CloudTasks-TaskExecutionCount` is currently bugged and remains at zero all the time. See [this issue](https://github.com/keypup-io/cloudtasker/issues/6)

## [v0.9.4](https://github.com/keypup-io/cloudtasker/tree/v0.9.4) (2020-10-05)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.9.3...v0.9.4)

**Fixed bugs:**
- Logging: fix log processing with `semantic_logger` `v4.7.2`. Accept any args on block passed to the logger.

## [v0.9.3](https://github.com/keypup-io/cloudtasker/tree/v0.9.3) (2020-06-25)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.9.2...v0.9.3)

**Fixed bugs:**
- Google Cloud Tasks: lock version to `~> 1.0` (Google recently released a v2 which changes its bindings completely). An [issue](https://github.com/keypup-io/cloudtasker/issues/11) has been raised to upgrade Cloudtasker to `google-cloud-tasks` `v2`.

## [v0.9.2](https://github.com/keypup-io/cloudtasker/tree/v0.9.2) (2020-03-04)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.9.1...v0.9.2)

**Fixed bugs:**
- Cloud Task: ignore "not found" errors when trying to delete an already deleted task.

## [v0.9.1](https://github.com/keypup-io/cloudtasker/tree/v0.9.1) (2020-02-11)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.9.0...v0.9.1)

**Fixed bugs:**
- Cloud Task: raise `Cloudtasker::MaxTaskSizeExceededError` if job payload exceeds 100 KB. This is mainly to have production parity in development when running the local processing server.

## [v0.9.0](https://github.com/keypup-io/cloudtasker/tree/v0.9.0) (2020-01-23)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.8.2...v0.9.0)

**Fixed bugs:**
- Cloud Task: Base64 encode task body to support UTF-8 characters (e.g. emojis).
- Redis: Restrict to one connection (class level) to avoid too many DNS lookups

**Migration**
For Sinatra applications please update your Cloudtasker controller according to [this diff](https://github.com/keypup-io/cloudtasker/commit/311fa8f9beec91fbae012164a25b2ee6e261a2e4#diff-c2a0ea6c6e6c31c749d2e1acdc574f0f).

## [v0.8.2](https://github.com/keypup-io/cloudtasker/tree/v0.8.2) (2019-12-05)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.8.1...v0.8.2)

**Fixed bugs:**
- Config: do not add processor host to `Rails.application.config.hosts` if originally empty.

## [v0.8.1](https://github.com/keypup-io/cloudtasker/tree/v0.8.1) (2019-12-03)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.8.0...v0.8.1)

**Fixed bugs:**
- Local dev server: ensure job queue name is kept when taks is retried
- Rails/Controller: bypass Rails munge logic to preserve nil values inside job arguments.

## [v0.8.0](https://github.com/keypup-io/cloudtasker/tree/v0.8.0) (2019-11-27)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.7.0...v0.8.0)

## [v0.7.0](https://github.com/keypup-io/cloudtasker/tree/v0.7.0) (2019-11-25)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.6.0...v0.7.0)

## [v0.6.0](https://github.com/keypup-io/cloudtasker/tree/v0.6.0) (2019-11-25)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.5.0...v0.6.0)

## [v0.5.0](https://github.com/keypup-io/cloudtasker/tree/v0.5.0) (2019-11-25)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.4.0...v0.5.0)

## [v0.4.0](https://github.com/keypup-io/cloudtasker/tree/v0.4.0) (2019-11-25)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.3.0...v0.4.0)

## [v0.3.0](https://github.com/keypup-io/cloudtasker/tree/v0.3.0) (2019-11-25)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.2.0...v0.3.0)

## [v0.2.0](https://github.com/keypup-io/cloudtasker/tree/v0.2.0) (2019-11-18)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/v0.1.0...v0.2.0)

## [v0.1.0](https://github.com/keypup-io/cloudtasker/tree/v0.1.0) (2019-11-17)

[Full Changelog](https://github.com/keypup-io/cloudtasker/compare/c137feb1ceaaaa4e2fecac0d1f0b4c73151ae002...v0.1.0)
