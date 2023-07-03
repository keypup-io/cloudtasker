# Example usage with Cloud Run & Private invocations

All the steps below require the [gcloud CLI](https://cloud.google.com/sdk/docs/install-sdk).

## Deploying to Cloud Run
The following steps will deploy a minimal app called `cloudtasker-demo` to your Cloud Run account.

First, set your GCP project ID
```
export PROJECT_ID=my-gcp-project
```

Check the initial Cloudtasker configuration in `config/initializers/cloudtasker.rb`. Make sure the `gcp_project_id` and `gcp_location_id` are correct

Make sure the default queue exists for the demo application in Google Cloud Tasks:
```
bundle exec rake cloudtasker:setup_queue
```

Create a service account for your application and attach the **Cloud Tasks Enqueuer** roles to it so it is allowed to enqueue tasks. In a production context, you can restrict this permission to specific Cloud Task queues using [--condition](https://cloud.google.com/sdk/gcloud/reference/projects/add-iam-policy-binding#--condition):
```
# Create service account
gcloud iam service-accounts create cloudtasker-demo --display-name="cloudtasker-demo" --project=$PROJECT_ID

# Add Task Runner role
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:cloudtasker-demo@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/cloudtasks.enqueuer"
```

Build and deploy the app to Cloud Run:
```
# Build
gcloud builds submit --project=$PROJECT_ID --tag gcr.io/$PROJECT_ID/cloudrun/cloudtasker-demo

# Deploy
gcloud run deploy cloudtasker-demo --project=$PROJECT_ID --region us-central1 --platform managed --image gcr.io/$PROJECT_ID/cloudrun/cloudtasker-demo --service-account="cloudtasker-demo@$PROJECT_ID.iam.gserviceaccount.com" --allow-unauthenticated
```

Once you have your service URL, update the `processor_host` in `config/initializers/cloudtasker.rb`. Also make sure that your Cloud Run service account has the "Cloud Tasks Enqueuer" IAM role. You can then re-build and redeploy your service:
```
gcloud builds submit --project=$PROJECT_ID --tag gcr.io/$PROJECT_ID/cloudrun/cloudtasker-demo
gcloud run deploy cloudtasker-demo --project=$PROJECT_ID --region us-central1 --image gcr.io/$PROJECT_ID/cloudrun/cloudtasker-demo
```

Once deployed, you can enqueue dummy jobs by visiting `https://<your-service>.run.app/enqueue/dummy`. This URL will enqueue a `DummyWorker` on Cloud Tasks.

The job progress can be followed in your Cloud Run service logs.

## Making your service private using OpenID Connect (OIDC)
If you do not want your app to be publicly accessible on the internet, you may configure it to use private invocations on Cloud Run.

For Cloud Tasks to work with a Cloud Run service in private mode, a service account must be specified on the tasks that has access to the Cloud Run service. This is the purpose of the `config.oidc` parameter in Cloudtasker.

The steps below explain how to configure your application and service account to work with private invocations.

### Switching the app to private mode
Uncomment the `oidc` section in `config/initializers/cloudtasker.rb` and specify the `service_account_email` to:
```
echo cloudtasker-demo@$PROJECT_ID.iam.gserviceaccount.com
```

Add the **Cloud Run Invoker** role to the service account. Since tasks will be enqueued under the service account created previously, they need to be able to invoke the Cloud Run app. In a production context, you can restrict this permission to this Cloud Run app only using [--condition](https://cloud.google.com/sdk/gcloud/reference/projects/add-iam-policy-binding#--condition):
```
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:cloudtasker-demo@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/run.invoker"
```

The service account also needs to be able to act as itself to enqueue tasks on its behalf. To do so, we need to attach the "Service Acccount User" to our service account:
```
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:cloudtasker-demo@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/iam.serviceAccountUser"
```

Re-build and deploy your service in private authentication mode:
```
# Build
gcloud builds submit --project=$PROJECT_ID --tag gcr.io/$PROJECT_ID/cloudrun/cloudtasker-demo

# Deploy in authenticated mode
gcloud run deploy cloudtasker-demo --project=$PROJECT_ID --region us-central1 --image gcr.io/$PROJECT_ID/cloudrun/cloudtasker-demo --no-allow-unauthenticated
```

### Enqueuing jobs using private invocations
Unless you are an admin on your GCP account, you should give yourself the "Cloud Run Invoker" role, otherwise, you won't be able to access your Cloud Run service via HTTP.

Now you should be able to enqueue jobs on your private service by running the following authenticated request (visiting the URL via a browser will not work anymore):
```
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" https://<your-service>.run.app/enqueue/dummy
```

You may need to check your Cloud Run service logs for errors and adapt the permissions of your Cloud Tasks and Cloud Run service users.