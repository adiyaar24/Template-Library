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

resource "harness_platform_pipeline" "apply" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "apply"
  name        = "apply"
  description = "Provision infrastructure"
  tags        = ["source:templateLibrary"]
  yaml        = <<-EOT
pipeline:
  name: apply
  identifier: apply
  projectIdentifier: ${data.harness_platform_project.this.id}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  tags:
    source: templateLibrary
  stages:
    - stage:
        name: apply
        identifier: apply
        description: ""
        type: Custom
        spec:
          execution:
            steps:
              - step:
                  type: TerraformPlan
                  name: plan
                  identifier: plan
                  spec:
                    provisionerIdentifier: apply
                    configuration:
                      command: Apply
                      configFiles:
                        store:
                          spec:
                            connectorRef: <+input>
                            repoName: <+input>
                            gitFetchType: Branch
                            branch: <+input>
                            folderPath: <+input>
                          type: Github
                      secretManagerRef: harnessSecretManager
                  timeout: 10m
              - step:
                  type: HarnessApproval
                  name: approve
                  identifier: approve
                  spec:
                    approvalMessage: Please review the following information and approve the pipeline progression
                    includePipelineExecutionHistory: true
                    isAutoRejectEnabled: false
                    approvers:
                      userGroups:
                        - _project_all_users
                      minimumCount: 1
                      disallowPipelineExecutor: false
                    approverInputs: []
                  timeout: 1d
              - step:
                  type: TerraformApply
                  name: apply
                  identifier: apply
                  spec:
                    provisionerIdentifier: apply
                    configuration:
                      type: InheritFromPlan
                  timeout: 10m
              - step:
                  type: TerraformRollback
                  name: rollback
                  identifier: rollback
                  spec:
                    provisionerIdentifier: apply
                    skipRefreshCommand: false
                  timeout: 10m
                  when:
                    stageStatus: Failure
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
        type: Custom
        spec:
          execution:
            steps:
              - step:
                  type: TerraformPlan
                  name: plan
                  identifier: plan
                  spec:
                    provisionerIdentifier: destroy
                    configuration:
                      command: Destroy
                      configFiles:
                        store:
                          spec:
                            connectorRef: <+input>
                            repoName: <+input>
                            gitFetchType: Branch
                            branch: <+input>
                            folderPath: <+input>
                          type: Github
                      secretManagerRef: harnessSecretManager
                      skipRefreshCommand: false
                  timeout: 10m
              - step:
                  type: HarnessApproval
                  name: approve
                  identifier: approve
                  spec:
                    approvalMessage: Please review the following information and approve the pipeline progression
                    includePipelineExecutionHistory: true
                    isAutoRejectEnabled: false
                    approvers:
                      userGroups:
                        - _project_all_users
                      minimumCount: 1
                      disallowPipelineExecutor: false
                    approverInputs: []
                  timeout: 1d
              - step:
                  type: TerraformDestroy
                  name: destroy
                  identifier: destroy
                  spec:
                    provisionerIdentifier: destroy
                    configuration:
                      type: InheritFromPlan
                  timeout: 10m
        tags: {}
EOT
}
