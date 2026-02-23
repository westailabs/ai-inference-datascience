# variables.tf

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy to"
  type        = string
  default     = "us-central1"
}

variable "container_image" {
  description = "The inference container image (default: hello-world for bootstrap)"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}