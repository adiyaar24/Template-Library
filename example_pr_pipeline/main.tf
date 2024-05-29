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

resource "harness_platform_template" "pr_pipeline" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "Example_PR_Pipeline_Template"
  name        = "Example PR Pipeline Template"
  version       = "1"
  is_stable     = true
  tags        = ["source:templateLibrary"]
  template_yaml        = <<-EOT
template:
  name: Example PR Pipeline Template
  identifier: Example_PR_Pipeline_Template
  versionLabel: 1
  type: Pipeline
  tags: {}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  projectIdentifier: ${data.harness_platform_project.this.id}
  spec:
    properties:
      ci:
        codebase:
          connectorRef: <+input>
          repoName: <+input>
          build: <+input>
    stages:
      - stage:
          name: Build Image
          identifier: Build_Image
          type: CI
          spec:
            cloneCodebase: true
            infrastructure:
              type: KubernetesDirect
              spec:
                connectorRef: <+input>
                namespace: default
                automountServiceAccountToken: true
                nodeSelector: {}
                os: Linux
            execution:
              steps:
                - step:
                    type: BuildAndPushDockerRegistry
                    name: Build Image
                    identifier: Build_Image
                    spec:
                      connectorRef: <+input>
                      repo: <+input>
                      tags:
                        - pr-<+codebase.commitSha>
                      optimize: true
                      remoteCacheRepo: <+input>
                      resources:
                        limits:
                          memory: 2Gi
                          cpu: "1"
          description: ""
      - stage:
          name: Deploy Image
          identifier: Deploy_Image
          description: ""
          type: Deployment
          spec:
            deploymentType: Kubernetes
            service:
              serviceRef: <+input>
              serviceInputs: <+input>
            environment:
              environmentRef: <+input>
              deployToAll: false
              environmentInputs: <+input>
              serviceOverrideInputs: <+input>
              infrastructureDefinitions: <+input>
            execution:
              steps:
                - step:
                    name: Rolling Deployment
                    identifier: rollingDeployment
                    type: K8sRollingDeploy
                    timeout: 10m
                    spec:
                      skipDryRun: false
              rollbackSteps:
                - step:
                    name: Canary Delete
                    identifier: rollbackCanaryDelete
                    type: K8sCanaryDelete
                    timeout: 10m
                    spec: {}
                - step:
                    name: Rolling Rollback
                    identifier: rollingRollback
                    type: K8sRollingRollback
                    timeout: 10m
                    spec: {}
          tags: {}
          failureStrategies:
            - onFailure:
                errors:
                  - AllErrors
                action:
                  type: StageRollback
EOT
}
