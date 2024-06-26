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

resource "harness_platform_template" "release_pipeline" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "Example_Release_Pipeline_Template"
  name        = "Example Release Pipeline Template"
  version       = "1"
  is_stable     = true
  tags        = ["source:templateLibrary"]
  template_yaml        = <<-EOT
template:
  name: Example Release Pipeline Template
  identifier: Example_Release_Pipeline_Template
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
          name: Preprocessing
          identifier: Preprocessing
          description: ""
          type: Custom
          spec:
            execution:
              steps:
                - step:
                    type: ShellScript
                    name: Prepare Variables
                    identifier: Prepare_Variables
                    spec:
                      shell: Bash
                      onDelegate: true
                      source:
                        type: Inline
                        spec:
                          script: |-
                            export DOCKER_REGISTRY=$(echo <+pipeline.variables.docker_image> | cut -d'/' -f1)
                            export DOCKER_REPOSITORY=$(echo <+pipeline.variables.docker_image> | cut -d'/' -f2-)
                      environmentVariables: []
                      outputVariables:
                        - name: docker_registry
                          type: String
                          value: DOCKER_REGISTRY
                        - name: docker_repository
                          type: String
                          value: DOCKER_REPOSITORY
                    timeout: 10m
          tags: {}
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
                namespace: <+input>
                automountServiceAccountToken: true
                nodeSelector: {}
                os: Linux
            execution:
              steps:
                - step:
                    type: Background
                    name: Dind
                    identifier: Dind
                    spec:
                      connectorRef: account.harnessImage
                      image: docker:dind
                      shell: Sh
                      privileged: true
                - step:
                    type: BuildAndPushDockerRegistry
                    name: Build Image
                    identifier: Build_Image
                    spec:
                      connectorRef: <+input>
                      repo: <+pipeline.variables.docker_image>
                      tags:
                        - <+pipeline.variables.docker_tag>
                      optimize: true
                      remoteCacheRepo: <+pipeline.variables.docker_image>
                      resources:
                        limits:
                          memory: 2Gi
                          cpu: "1"
                - step:
                    type: Grype
                    name: Scan Image with Grype
                    identifier: Scan_Image_with_Grype
                    spec:
                      mode: orchestration
                      config: default
                      target:
                        name: <+pipeline.variables.docker_image>
                        type: container
                        variant: <+pipeline.variables.docker_tag>
                      advanced:
                        log:
                          level: info
                      privileged: true
                      image:
                        type: docker_v2
                        name: <+pipeline.stages.Preprocessing.spec.execution.steps.Prepare_Variables.output.outputVariables.docker_repository>
                        domain: <+pipeline.stages.Preprocessing.spec.execution.steps.Prepare_Variables.output.outputVariables.docker_registry>
                        tag: <+pipeline.variables.docker_tag>
            sharedPaths:
              - /var/run
            caching:
              enabled: false
              paths: []
          description: ""
      - stage:
          name: Deploy to Test
          identifier: Deploy_to_Test
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
      - stage:
          name: Deploy to Prod
          identifier: Deploy_to_Prod
          description: ""
          type: Deployment
          spec:
            deploymentType: Kubernetes
            service:
              useFromStage:
                stage: Deploy_to_Test
            environment:
              environmentRef: <+input>
              deployToAll: false
              environmentInputs: <+input>
              serviceOverrideInputs: <+input>
              infrastructureDefinitions: <+input>
            execution:
              steps:
                - stepGroup:
                    name: Canary Deployment
                    identifier: canaryDepoyment
                    steps:
                      - step:
                          name: Canary Deployment
                          identifier: canaryDeployment
                          type: K8sCanaryDeploy
                          timeout: 10m
                          spec:
                            instanceSelection:
                              type: Count
                              spec:
                                count: 1
                            skipDryRun: false
                      - step:
                          type: Verify
                          name: Verify
                          identifier: Verify
                          timeout: 2h
                          spec:
                            isMultiServicesOrEnvs: false
                            type: Canary
                            monitoredService:
                              type: Default
                              spec: {}
                            spec:
                              sensitivity: MEDIUM
                              duration: 15m
                              deploymentTag: <+artifacts.primary.tag>
                          failureStrategies:
                            - onFailure:
                                errors:
                                  - Verification
                                action:
                                  type: ManualIntervention
                                  spec:
                                    timeout: 2h
                                    onTimeout:
                                      action:
                                        type: StageRollback
                            - onFailure:
                                errors:
                                  - Unknown
                                action:
                                  type: ManualIntervention
                                  spec:
                                    timeout: 2h
                                    onTimeout:
                                      action:
                                        type: Ignore
                      - step:
                          name: Canary Delete
                          identifier: canaryDelete
                          type: K8sCanaryDelete
                          timeout: 10m
                          spec: {}
                - stepGroup:
                    name: Primary Deployment
                    identifier: primaryDepoyment
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
    variables:
      - name: docker_image
        type: String
        description: "The image name where the image being built will be pushed to"
        required: false
        value: <+input>
      - name: docker_tag
        type: String
        description: This is the tag to apply to the image being built
        required: false
        value: <+input>.default(harness-<+codebase.commitSha>)
EOT
}
