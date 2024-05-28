terraform {
  required_providers {
    harness = {
      source = "harness/harness"
    }
  }
}

variable "org_id" {
  type    = string
  default = "default"
}

variable "project_id" {
  type    = string
  default = "default"
}

data "harness_platform_organization" "this" {
  identifier = var.org_id
}

data "harness_platform_project" "this" {
  org_id     = var.org_id
  identifier = var.project_id
}

resource "harness_platform_connector_aws" "this" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "ff_relay_proxy_ecs_aws"
  name        = "ff relay proxy ecs"
  description = "Connection to AWS for deploying ff relay proxy ecs"
  tags        = ["source:templateLibrary"]
  oidc_authentication {
    iam_role_arn       = "arn:aws:iam::759984737373:role/harness_oidc"
    region             = "us-east-1"
    delegate_selectors = []
  }
}

resource "harness_platform_secret_text" "this" {
  org_id                    = data.harness_platform_organization.this.id
  project_id                = data.harness_platform_project.this.id
  identifier                = "ff_relay_proxy_ecs_github"
  name                      = "ff relay proxy ecs github"
  description               = "GitHub PAT for resolving repos"
  tags                      = ["source:templateLibrary"]
  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = "foobar"
}

resource "harness_platform_connector_github" "this" {
  org_id              = data.harness_platform_organization.this.id
  project_id          = data.harness_platform_project.this.id
  identifier          = "ff_relay_proxy_ecs_github"
  name                = "ff relay proxy ecs"
  description         = "Connection to github for relay proxy"
  tags                = ["source:templateLibrary"]
  url                 = "https://github.com/harness-community/feature-flag-relay-proxy-ecs"
  connection_type     = "Repo"
  execute_on_delegate = false
  api_authentication {
    # token_ref = harness_platform_secret_text.this.id
    token_ref = "account.gh_pat"
  }
  credentials {
    http {
      username = "git"
      # token_ref = harness_platform_secret_text.this.id
      token_ref = "account.gh_pat"
    }
  }
}

resource "harness_platform_workspace" "this" {
  org_id                  = data.harness_platform_organization.this.id
  project_id              = data.harness_platform_project.this.id
  name                    = "ff relay proxy ecs"
  identifier              = "ff_relay_proxy_ecs"
  provisioner_type        = "terraform"
  provisioner_version     = "1.5.6"
  repository              = "https://github.com/harness-community/feature-flag-relay-proxy-ecs"
  repository_branch       = "main"
  repository_path         = ".harness/"
  cost_estimation_enabled = true
  provider_connector      = harness_platform_connector_aws.this.id
  repository_connector    = harness_platform_connector_github.this.id

  terraform_variable {
    key        = "name"
    value      = "ff-relay-proxy-ecs"
    value_type = "string"
  }

  terraform_variable {
    key        = "image"
    value      = "harness/ff-proxy:2.0.0-rc.24"
    value_type = "string"
  }

  terraform_variable {
    key        = "proxy_key_secret_arn"
    value      = "arn:aws:secretsmanager:us-west-2:759984737373:secret:riley/ff-proxy-key-EHPGoR"
    value_type = "string"
  }

  terraform_variable {
    key        = "vpc_id"
    value      = "vpc-0e2b5e811d1ce6767"
    value_type = "string"
  }

  terraform_variable {
    key        = "proxy_subnets"
    value      = "[\"subnet-0ee34605c385f4c65\"]"
    value_type = "string"
  }

  terraform_variable {
    key        = "alb_subnets"
    value      = "[\"subnet-0623eefc5d4ff9d0f\"]"
    value_type = "string"
  }
}