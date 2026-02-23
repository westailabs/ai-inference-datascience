# main.tf

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ==============================================================================
# DATA STORAGE (Google Cloud Storage)
# ==============================================================================
resource "google_storage_bucket" "dataset_bucket" {
  name          = "${var.project_id}-datasets"
  location      = var.region
  force_destroy = true # For lab purposes

  uniform_bucket_level_access = true
}

# ==============================================================================
# EVENTING (Pub/Sub)
# ==============================================================================
resource "google_pubsub_topic" "inference_trigger" {
  name = "inference-trigger-topic"
}

# The Service Account that Pub/Sub will use to push messages to Cloud Run
resource "google_service_account" "pubsub_invoker_sa" {
  account_id   = "pubsub-invoker-sa"
  display_name = "Pub/Sub Invoker Service Account"
}

# ==============================================================================
# COMPUTE (Cloud Run - Auto-Scaling from Zero)
# ==============================================================================
# The Service Account the container will run as
resource "google_service_account" "inference_worker_sa" {
  account_id   = "inference-worker-sa"
  display_name = "Data Science Inference Worker SA"
}

# Grant the worker SA read access to the dataset bucket
resource "google_storage_bucket_iam_member" "worker_storage_access" {
  bucket = google_storage_bucket.dataset_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.inference_worker_sa.email}"
}

resource "google_cloud_run_v2_service" "inference_service" {
  name     = "ds-inference-worker"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY" # Do not expose to public internet

  template {
    service_account = google_service_account.inference_worker_sa.email
    
    scaling {
      # This is the magic for the Data Science use case.
      # When no messages are in the queue, we scale to exactly 0 instances, paying nothing.
      # When a massive batch job is triggered, GCP scales out to up to 50 concurrent containers.
      min_instance_count = 0
      max_instance_count = 50
    }

    containers {
      image = var.container_image
      
      resources {
        limits = {
          cpu    = "2000m"  # 2 vCPUs for heavier inference logic
          memory = "2048Mi" # 2 GB RAM
        }
      }
    }
  }
}

# Allow the Pub/Sub invoker SA to trigger the Cloud Run service
resource "google_cloud_run_service_iam_member" "invoker_access" {
  location = google_cloud_run_v2_service.inference_service.location
  project  = google_cloud_run_v2_service.inference_service.project
  service  = google_cloud_run_v2_service.inference_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.pubsub_invoker_sa.email}"
}

# ==============================================================================
# THE BRIDGE (Pub/Sub Push Subscription)
# ==============================================================================
resource "google_pubsub_subscription" "inference_subscription" {
  name  = "inference-push-subscription"
  topic = google_pubsub_topic.inference_trigger.name

  push_config {
    push_endpoint = google_cloud_run_v2_service.inference_service.uri
    
    # Authenticate the push request using our dedicated invoker SA
    oidc_token {
      service_account_email = google_service_account.pubsub_invoker_sa.email
    }
  }

  # Tuning: give the container up to 60 seconds to process the batch before retrying
  ack_deadline_seconds = 60 
}