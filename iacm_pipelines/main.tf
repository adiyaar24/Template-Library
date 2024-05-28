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

resource "harness_platform_pipeline" "provision" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "provision"
  name        = "provision"
  description = "Provision infrastructure"
  tags        = ["source:templateLibrary"]
  yaml        = <<-EOT
pipeline:
  name: provision
  identifier: provision
  projectIdentifier: ${data.harness_platform_project.this.id}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  tags:
    source: templateLibrary
  stages:
    - stage:
        name: provision
        identifier: provision
        description: ""
        type: IACM
        spec:
          platform:
            os: Linux
            arch: Amd64
          runtime:
            type: Cloud
            spec: {}
          workspace: <+input>
          execution:
            steps:
              - step:
                  type: IACMTerraformPlugin
                  name: init
                  identifier: init
                  timeout: 10m
                  spec:
                    command: init
              - step:
                  type: IACMTerraformPlugin
                  name: plan
                  identifier: plan
                  timeout: 10m
                  spec:
                    command: plan
              - step:
                  type: IACMApproval
                  name: approve
                  identifier: approve
                  spec:
                    autoApprove: false
                  timeout: 1h
              - step:
                  type: IACMTerraformPlugin
                  name: apply
                  identifier: apply
                  timeout: 10m
                  spec:
                    command: apply
        tags: {}
EOT
}

resource "harness_platform_pipeline" "pull_request" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "pull_request"
  name        = "pull request"
  description = "Test pull request changes"
  tags        = ["source:templateLibrary"]
  yaml        = <<-EOT
pipeline:
  name: pull request
  identifier: pull_request
  projectIdentifier: ${data.harness_platform_project.this.id}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  tags: 
    source: templateLibrary
  stages:
    - stage:
        name: pull request
        identifier: pull_request
        description: ""
        type: IACM
        spec:
          platform:
            os: Linux
            arch: Amd64
          runtime:
            type: Cloud
            spec: {}
          workspace: <+input>
          execution:
            steps:
              - step:
                  type: IACMTerraformPlugin
                  name: init
                  identifier: init
                  timeout: 10m
                  spec:
                    command: init
              - step:
                  type: IACMTerraformPlugin
                  name: plan
                  identifier: plan
                  timeout: 10m
                  spec:
                    command: plan
        tags: {}
EOT
}

resource "harness_platform_pipeline" "destroy" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "destroy"
  name        = "destroy"
  description = "Destroy infrastructure"
  tags        = ["source:templateLibrary"]
  yaml        = <<-EOT
pipeline:
  name: destroy
  identifier: destroy
  projectIdentifier: ${data.harness_platform_project.this.id}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  tags: 
    source: templateLibrary
  stages:
    - stage:
        name: destroy
        identifier: destroy
        description: ""
        type: IACM
        spec:
          platform:
            os: Linux
            arch: Amd64
          runtime:
            type: Cloud
            spec: {}
          workspace: <+input>
          execution:
            steps:
              - step:
                  type: IACMTerraformPlugin
                  name: init
                  identifier: init
                  timeout: 10m
                  spec:
                    command: init
              - step:
                  type: IACMTerraformPlugin
                  name: planDestroy
                  identifier: planDestroy
                  timeout: 10m
                  spec:
                    command: plan-destroy
              - step:
                  type: IACMApproval
                  name: approve
                  identifier: approve
                  spec:
                    autoApprove: false
                  timeout: 1h
              - step:
                  type: IACMTerraformPlugin
                  name: destroy
                  identifier: destroy
                  timeout: 10m
                  spec:
                    command: destroy
        tags: {}
EOT
}

resource "harness_platform_pipeline" "detect_drift" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "detect_drift"
  name        = "detect drift"
  description = "Detect changes in infrastructure"
  tags        = ["source:templateLibrary"]
  yaml        = <<-EOT
pipeline:
  name: detect drift
  identifier: detect_drift
  projectIdentifier: ${data.harness_platform_project.this.id}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  tags: 
    source: templateLibrary
  stages:
    - stage:
        name: sadf
        identifier: sadf
        description: ""
        type: IACM
        spec:
          platform:
            os: Linux
            arch: Amd64
          runtime:
            type: Cloud
            spec: {}
          workspace: <+input>
          execution:
            steps:
              - step:
                  type: IACMTerraformPlugin
                  name: init
                  identifier: init
                  timeout: 10m
                  spec:
                    command: init
              - step:
                  type: IACMTerraformPlugin
                  name: detectDrift
                  identifier: detectDrift
                  timeout: 10m
                  spec:
                    command: detect-drift
        tags: {}
EOT
}