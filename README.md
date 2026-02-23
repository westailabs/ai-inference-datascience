# AI Inference for Data Science (Batch / Event-Driven)

This project provides an auto-scaling, event-driven infrastructure specifically tailored for Data Science teams running sporadic or batch AI inference workloads.

## The Use Case
Data Science teams often need substantial compute power (CPU/RAM) to run inference across massive datasets. However, these batch jobs are sporadic. Running a static GKE cluster or a fleet of VMs 24/7 is a massive waste of capital.

## The Architecture
This Terraform code deploys a "Scale-to-Zero" event-driven pipeline:
1. **Google Cloud Storage (GCS):** The landing zone where data scientists upload their datasets.
2. **Pub/Sub Topic:** An event bus. When a new batch job needs to run, a message is published here.
3. **Cloud Run (Serverless Compute):** The inference engine. It listens to the Pub/Sub topic via a Push Subscription. 
   - **Scale to Zero:** When the queue is empty, instances scale down to 0, costing the business nothing.
   - **Burst Scaling:** When a massive batch job is triggered, GCP auto-scales out to as many as 50 parallel containers to crunch the data simultaneously.
4. **Least Privilege IAM:** The Cloud Run service account is strictly scoped. It can only read from the specific GCS bucket and process messages from the specific Pub/Sub subscription. It cannot be accessed via the public internet (`INGRESS_TRAFFIC_INTERNAL_ONLY`).

## Deployment
1. Ensure you have authenticated with GCP (`gcloud auth application-default login`).
2. Run `terraform init` to download the Google provider.
3. Run `terraform apply -var="project_id=YOUR_PROJECT_ID"`.

*This infrastructure is designed to be fully automated and ephemeral, allowing Data Science teams to focus on models rather than managing servers.*