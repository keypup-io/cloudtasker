# Example usage with Cloud Run & Private invocations

All the steps below require the [gcloud CLI](https://cloud.google.com/sdk/docs/install-sdk).

## Deploying to Cloud Run
The following steps will deploy a minimal app called `cloudtasker-demo` to your Cloud Run account.

First, build the app via Cloud Build. This step uses the local `Dockerfile` under the hood.
```
gcloud builds submit --tag gcr.io/$PROJECT_ID/cloudrun/cloudtasker-demo
```

Then deploy the app to Cloud Run:
```
gcloud run deploy cloudtasker-demo --region us-central1 --platform managed --image gcr.io/$PROJECT_ID/cloudrun/cloudtasker-demo --allow-unauthenticated
```

Once you have your service URL, update the `processor_host` in `config/initializers/cloudtasker.rb`. Also make sure that your Cloud Run service account has the "Cloud Tasks Enqueuer" IAM role. You can then re-build and redeploy your service:
```
gcloud builds submit --tag gcr.io/$PROJECT_ID/cloudrun/cloudtasker-demo
gcloud run deploy cloudtasker-demo --region us-central1 --image gcr.io/$PROJECT_ID/cloudrun/cloudtasker-demo
```

Once deployed, you can enqueue dummy jobs by visiting `https://<your-service>.run.app/enqueue/dummy`. This URL will enqueue a `DummyWorker` on Cloud Tasks.

The job progress can be followed in your Cloud Run service logs.

## Making your service private
First deploy your service, as explained in the previous section.

Make your service private:
```
gcloud run deploy cloudtasker-demo --region us-central1 --image gcr.io/$PROJECT_ID/cloudrun/cloudtasker-demo --no-allow-unauthenticated
```

Now we need to tell Cloudtasker to use a specific service account when enqueuing jobs, otherwise your jobs will be denied by your now private service.

Go to GCP IAM and create a new service account for Cloud Tasks with the following configuration:
- The Cloud Run service account must have principal access to this account with the "Service Account User" role. This will ensure that the Cloud Run can "act as" the Cloud Task service account when enqueuing jobs. Even if you use the same account for Cloud Run and Cloud Tasks, the service account must have "Service Account User" access to itself.
- Add the "Cloud Tasks Task Runner" role to the service account

Unless you are an admin on your GCP account, you should also give yourself the "Cloud Run Invoker" role, otherwise, you won't be able to access your Cloud Run service via HTTP.

Once done with permission, you should re-deploy your Cloud Run service to ensure that they are properly applied:
```
gcloud run deploy cloudtasker-demo --region us-central1 --image gcr.io/$PROJECT_ID/cloudrun/cloudtasker-demo
```

Now you should be able to enqueue jobs on your private service by running the following authenticated request:
```
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" https://<your-service>.run.app/enqueue/dummy
```

You may need to check your Cloud Run service logs for errors and adapt the permissions of your Cloud Tasks and Cloud Run service users.