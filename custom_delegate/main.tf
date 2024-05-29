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

resource "harness_platform_pipeline" "this" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "custom_delegate"
  name        = "custom delegate"
  description = "Build and push a delegate image into a local repo"
  tags        = ["source:templateLibrary"]
  yaml        = <<-EOT
pipeline:
  name: custom delegate
  identifier: custom_delegate
  projectIdentifier: ${data.harness_platform_project.this.id}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  tags:
    source: templateLibrary
  stages:
    - stage:
        name: Get Latest Delegate Version
        identifier: Get_Latest_Delegate_Version
        description: ""
        type: Custom
        spec:
          execution:
            steps:
              - step:
                  type: Http
                  name: Delegate Version
                  identifier: Delegate_Version
                  spec:
                    url: https://app.harness.io/gateway/ng/api/delegate-setup/latest-supported-version?accountIdentifier=<+account.identifier>
                    method: GET
                    headers:
                      - key: X-API-KEY
                        value: <+stage.variables.HARNESS_PLATFORM_API_KEY>
                    inputVariables: []
                    outputVariables:
                      - name: LATEST_VERSION
                        value: <+json.select("resource.latestSupportedVersion", httpResponseBody)>
                        type: String
                      - name: LATEST_MINIMAL
                        value: <+json.select("resource.latestSupportedMinimalVersion", httpResponseBody)>
                        type: String
                  timeout: 30s
        tags: {}
        when:
          pipelineStatus: Success
          condition: <+<+pipeline.variables.delegate_base_version>!=""?false:true>
        variables:
          - name: HARNESS_PLATFORM_API_KEY
            type: Secret
            description: Enter the Harness Platform API Key for your account
            required: true
            value: <+input>
    - stage:
        name: Build Harness Delegate
        identifier: Build_Harness_Delegate
        type: CI
        spec:
          cloneCodebase: false
          execution:
            steps:
              - step:
                  type: Run
                  name: Create Dockerfile
                  identifier: Create_Dockerfile
                  spec:
                    shell: Sh
                    command: |-
                      echo '
                      ARG TAG
                      FROM harness/delegate:$TAG
                      ' > Dockerfile
              - step:
                  type: BuildAndPushDockerRegistry
                  name: Build and Push Docker Image
                  identifier: Build_and_Push_Docker_Image
                  spec:
                    connectorRef: <+input>
                    repo: <+stage.variables.registry_name>/harness-delegate
                    tags:
                      - latest
                      - <+stage.variables.DELEGATE_VERSION>
                    buildArgs:
                      TAG: <+stage.variables.DELEGATE_VERSION>
                    remoteCacheRepo: <+stage.variables.registry_name>/harness-delegate-cache
                    resources:
                      limits:
                        memory: 4Gi
                  when:
                    stageStatus: Success
              - step:
                  type: AquaTrivy
                  name: Aqua Scan
                  identifier: Aqua_Scan
                  spec:
                    mode: orchestration
                    config: default
                    target:
                      type: container
                      detection: auto
                    advanced:
                      log:
                        level: info
                    privileged: true
                    image:
                      type: docker_v2
                      name: <+execution.steps.Build_and_Push_Docker_Image.artifact_Build_and_Push_Docker_Image.stepArtifacts.publishedImageArtifacts[0].imageName>
                      tag: <+execution.steps.Build_and_Push_Docker_Image.artifact_Build_and_Push_Docker_Image.stepArtifacts.publishedImageArtifacts[0].tag>
          sharedPaths:
            - /var/run
            - /var/lib/docker
          caching:
            enabled: false
            paths: []
          slsa_provenance:
            enabled: false
          platform:
            os: Linux
            arch: Amd64
          runtime:
            type: Cloud
            spec: {}
        when:
          pipelineStatus: Success
        variables:
          - name: registry_name
            type: String
            description: ""
            required: true
            value: <+input>
          - name: DELEGATE_VERSION
            type: String
            description: ""
            required: true
            value: <+<+pipeline.variables.delegate_base_version>!=""?<+pipeline.variables.delegate_base_version>:<+pipeline.stages.Get_Latest_Delegate_Version.spec.execution.steps.Delegate_Version.output.outputVariables.LATEST_MINIMAL>>
        description: ""
  variables:
    - name: delegate_base_version
      type: String
      description: "Optional: Provide a specific official Harness Delegate tag to build. This overrides the use of the platform specified default value"
      required: false
      value: <+input>
EOT
}
