# outputs.tf

output "gcs_bucket_name" {
  description = "The name of the dataset storage bucket"
  value       = google_storage_bucket.dataset_bucket.name
}

output "pubsub_topic_id" {
  description = "The ID of the Pub/Sub topic to publish batch jobs to"
  value       = google_pubsub_topic.inference_trigger.id
}

output "cloud_run_service_url" {
  description = "The URL of the serverless inference engine"
  value       = google_cloud_run_v2_service.inference_service.uri
}