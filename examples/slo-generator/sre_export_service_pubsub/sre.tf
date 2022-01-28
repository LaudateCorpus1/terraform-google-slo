locals {
    config_export = yamldecode(file("${path.module}/configs/config_export.yaml"))
}

module "slo-generator-export" {
  source                = "../../../modules/slo-generator"
  service_name          = "slo-generator-export"
  mode                  = "export"
  project_id            = var.project_id
  region                = var.region
  config                = local.config_export
  slo_generator_version = var.slo_generator_version
  gcr_project_id        = var.gcr_project_id
  secrets               = {
    SRE_PROJECT_ID = var.project_id
  }
}

#----------#
# EventArc #
#----------#

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_pubsub_topic" "topic" {
  name    = "slo-reports-topic"
  project = var.project_id
}

resource "google_eventarc_trigger" "primary" {
  name            = "slo-reports-eventarc"
  project         = var.project_id
  location        = var.region
  service_account = module.slo-generator.service_account_email
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }
  destination {
    cloud_run_service {
      service = module.slo-generator-export.service_name
      region  = var.region
    }
  }
  transport {
    pubsub {
      topic = google_pubsub_topic.topic.id
    }
  }
}

resource "google_project_iam_member" "pubsub-sa-token-creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  depends_on = [
    google_eventarc_trigger.primary
  ]
}
