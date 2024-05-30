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

resource "harness_platform_pipeline" "build_and_deploy_to_cloudrun_with_canary" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "Build_and_Deploy_to_CloudRun_with_Canary"
  name        = "Build and Deploy to CloudRun with Canary"
  yaml        = <<-EOT
pipeline:
  name: Build and Deploy to CloudRun with Canary
  identifier: Build_and_Deploy_to_CloudRun_with_Canary
  tags: {}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  projectIdentifier: ${data.harness_platform_project.this.id}
  template:
    templateRef: ${harness_platform_template.build_scan_and_deploy_cloudrun_with_canary.id}
    versionLabel: "1"
    gitBranch: master
    templateInputs:
      stages:
        - stage:
            identifier: Build_and_Scan
            template:
              templateInputs:
                type: CI
                spec:
                  execution:
                    steps:
                      - step:
                          identifier: gcpoidc
                          type: Plugin
                          spec:
                            connectorRef: <+input>
                      - step:
                          identifier: BuildAndPushGAR_1
                          type: BuildAndPushGAR
                          spec:
                            connectorRef: <+input>
                variables:
                  - name: serviceAccountEmailId
                    type: String
                    value: <+input>
                  - name: poolId
                    type: String
                    value: <+input>
                  - name: providerId
                    type: String
                    value: <+input>
                  - name: projectNumber
                    type: String
                    value: <+input>
        - stage:
            identifier: Deploy_to_Test
            template:
              templateInputs:
                type: Deployment
                spec:
                  environment:
                    environmentRef: <+input>
                    environmentInputs: <+input>
                    serviceOverrideInputs: <+input>
                    infrastructureDefinitions: <+input>
                  service:
                    serviceRef: <+input>
                    serviceInputs: <+input>
        - stage:
            identifier: Approval
            type: Approval
            spec:
              execution:
                steps:
                  - step:
                      identifier: Approval
                      type: HarnessApproval
                      spec:
                        approvers:
                          userGroups: <+input>
        - stage:
            identifier: Deploy_to_Prod
            template:
              templateInputs:
                type: Deployment
                spec:
                  environment:
                    environmentRef: <+input>
                    environmentInputs: <+input>
                    serviceOverrideInputs: <+input>
                    infrastructureDefinitions: <+input>
      properties:
        ci:
          codebase:
            build: <+input>
      variables:
        - name: docker_image
          type: String
          value: <+input>
        - name: docker_tag
          type: String
          value: <+input>

EOT
}

resource "harness_platform_template" "build_and_scan_hosted_gcp" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "Build_and_Scan_Hosted_GCP"
  name        = "Build and Scan Hosted GCP"
  version       = "1"
  is_stable     = true
  tags        = ["source:templateLibrary"]
  template_yaml = <<-EOT
template:
  name: Build and Scan Hosted GCP
  type: Stage
  spec:
    type: CI
    spec:
      cloneCodebase: true
      platform:
        os: Linux
        arch: Amd64
      runtime:
        type: Cloud
        spec: {}
      execution:
        steps:
          - step:
              type: Plugin
              name: GCP_OIDC
              identifier: gcpoidc
              spec:
                connectorRef: <+input>
                image: harnesscommunitytest/drone-gcp-oidc:linux-amd64
                settings:
                  service_account_email_id: <+stage.variables.serviceAccountEmailId>
                  project_Id: <+stage.variables.projectNumber>
                  pool_Id: <+stage.variables.poolId>
                  provider_Id: <+stage.variables.providerId>
                imagePullPolicy: Always
          - step:
              type: BuildAndPushGAR
              name: BuildAndPushGAR_1
              identifier: BuildAndPushGAR_1
              spec:
                connectorRef: <+input>
                host: <+stage.variables.host>
                projectID: <+stage.variables.project>
                imageName: <+stage.variables.imageRepo>
                tags:
                  - <+stage.variables.imageTag>
          - step:
              type: Grype
              name: Scan Image with Grype
              identifier: Scan_Image_with_Grype
              spec:
                mode: orchestration
                config: default
                target:
                  type: container
                  name: <+stage.variables.host>/<+stage.variables.project>/<+stage.variables.imageRepo>
                  variant: <+stage.variables.imageTag>
                advanced:
                  log:
                    level: info
                privileged: true
                image:
                  type: docker_v2
                  name: <+stage.variables.project>/<+stage.variables.imageRepo>
                  domain: <+stage.variables.host>
                  access_id: oauth2accesstoken
                  access_token: <+stage.spec.execution.steps.gcpoidc.output.outputVariables.GCLOUD_ACCESS_TOKEN>
                  tag: <+stage.variables.imageTag>
      caching:
        enabled: true
        paths: []
    variables:
      - name: host
        type: String
        description: GAR host containing the docker image being built
        required: false
        value: <+input>
      - name: project
        type: String
        description: GCP Project ID used for GAR docker repository
        required: false
        value: <+input>
      - name: imageRepo
        type: String
        description: Repository name in GAR where the docker image will be pushed
        required: false
        value: <+input>
      - name: serviceAccountEmailId
        type: String
        description: Email ID of the service account used for OIDC login
        required: false
        value: <+input>
      - name: poolId
        type: String
        description: Workload Pool ID used for OIDC login
        required: false
        value: <+input>
      - name: providerId
        type: String
        description: Workload Provider ID used by OIDC login
        required: false
        value: <+input>
      - name: projectNumber
        type: String
        description: GCP Project Number (not ID) used for OIDC login
        required: false
        value: <+input>
      - name: imageTag
        type: String
        description: Docker image tag to build and push
        required: false
        value: <+input>
  identifier: Build_and_Scan_Hosted_GCP
  orgIdentifier: ${data.harness_platform_organization.this.id}
  projectIdentifier: ${data.harness_platform_project.this.id}
  versionLabel: "1"
EOT
}

resource "harness_platform_template" "build_scan_and_deploy_cloudrun_with_canary" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "Build_Scan_and_Deploy_CloudRun_with_Canary"
  name        = "Build Scan and Deploy CloudRun with Canary"
  version       = "1"
  is_stable     = true
  tags        = ["source:templateLibrary"]
  template_yaml = <<-EOT
template:
  name: Build Scan and Deploy CloudRun with Canary
  type: Pipeline
  spec:
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
                      executionTarget: {}
                      source:
                        type: Inline
                        spec:
                          script: |-
                            export GAR_HOST=$(echo <+pipeline.variables.docker_image> | cut -d'/' -f1)
                            export GAR_PROJECT=$(echo <+pipeline.variables.docker_image> | cut -d'/' -f2)
                            export GAR_REPOSITORY=$(echo <+pipeline.variables.docker_image> | cut -d'/' -f3-)
                      environmentVariables: []
                      outputVariables:
                        - name: garHost
                          type: String
                          value: GAR_HOST
                        - name: garProject
                          type: String
                          value: GAR_PROJECT
                        - name: garRepository
                          type: String
                          value: GAR_REPOSITORY
                    timeout: 10m
          tags: {}
      - stage:
          name: Build and Scan
          identifier: Build_and_Scan
          template:
            templateRef: ${harness_platform_template.build_and_scan_hosted_gcp.id}
            versionLabel: "1"
            gitBranch: master
            templateInputs:
              type: CI
              spec:
                execution:
                  steps:
                    - step:
                        identifier: gcpoidc
                        type: Plugin
                        spec:
                          connectorRef: <+input>
                    - step:
                        identifier: BuildAndPushGAR_1
                        type: BuildAndPushGAR
                        spec:
                          connectorRef: <+input>
              variables:
                - name: host
                  type: String
                  value: <+pipeline.stages.Preprocessing.spec.execution.steps.Prepare_Variables.output.outputVariables.garHost>
                - name: project
                  type: String
                  value: <+pipeline.stages.Preprocessing.spec.execution.steps.Prepare_Variables.output.outputVariables.garProject>
                - name: imageRepo
                  type: String
                  value: <+pipeline.stages.Preprocessing.spec.execution.steps.Prepare_Variables.output.outputVariables.garRepository>
                - name: serviceAccountEmailId
                  type: String
                  value: <+input>
                - name: poolId
                  type: String
                  value: <+input>
                - name: providerId
                  type: String
                  value: <+input>
                - name: projectNumber
                  type: String
                  value: <+input>
                - name: imageTag
                  type: String
                  value: <+pipeline.variables.docker_tag>
      - stage:
          name: Deploy to Test
          identifier: Deploy_to_Test
          tags: {}
          template:
            templateRef: ${harness_platform_template.deploy_cloudrun_canary.id}
            versionLabel: "1"
            gitBranch: master
            templateInputs:
              type: Deployment
              spec:
                environment:
                  environmentRef: <+input>
                  environmentInputs: <+input>
                  serviceOverrideInputs: <+input>
                  infrastructureDefinitions: <+input>
                service:
                  serviceRef: <+input>
                  serviceInputs: <+input>
      - stage:
          name: Approval
          identifier: Approval
          description: ""
          type: Approval
          spec:
            execution:
              steps:
                - step:
                    name: Approval
                    identifier: Approval
                    type: HarnessApproval
                    timeout: 1d
                    spec:
                      approvalMessage: |-
                        Please review the following information
                        and approve the pipeline progression
                      includePipelineExecutionHistory: true
                      approvers:
                        minimumCount: 1
                        disallowPipelineExecutor: false
                        userGroups: <+input>
                      isAutoRejectEnabled: false
                      approverInputs: []
          tags: {}
      - stage:
          name: Deploy to Prod
          identifier: Deploy_to_Prod
          tags: {}
          template:
            templateRef: ${harness_platform_template.deploy_cloudrun_canary.id}
            versionLabel: "1"
            templateInputs:
              type: Deployment
              spec:
                environment:
                  environmentRef: <+input>
                  environmentInputs: <+input>
                  serviceOverrideInputs: <+input>
                  infrastructureDefinitions: <+input>
                service:
                  useFromStage:
                    stage: Deploy_to_Test
    properties:
      ci:
        codebase:
          connectorRef: <+input>
          repoName: <+input>
          build: <+input>
    variables:
      - name: docker_image
        type: String
        description: Full image name of the GAR image to build and deploy
        required: false
        value: <+input>
      - name: docker_tag
        type: String
        description: Docker image tag to build and deploy
        required: false
        value: <+input>
  identifier: Build_Scan_and_Deploy_CloudRun_with_Canary
  orgIdentifier: ${data.harness_platform_organization.this.id}
  projectIdentifier: ${data.harness_platform_project.this.id}
  versionLabel: "1"
EOT
}

resource "harness_platform_template" "cloudrun_shift_traffic" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "CloudRun_Shift_Traffic"
  name        = "CloudRun Shift Traffic"
  version       = "1"
  is_stable     = true
  tags        = ["source:templateLibrary"]
  template_yaml = <<-EOT
template:
  name: CloudRun Shift Traffic
  type: Step
  spec:
    type: ShellScript
    spec:
      shell: Bash
      executionTarget: {}
      source:
        type: Inline
        spec:
          script: |-
            source ~/.bashrc

            gcloud run services update-traffic --to-revisions=LATEST=$trafficPercentage <+infra.variables.serviceName> --region=<+infra.variables.region>
      environmentVariables:
        - name: trafficPercentage
          type: String
          value: <+input>
      outputVariables: []
      delegateSelectors:
        - <+infra.variables.deployDelegate>
    timeout: 10m
  identifier: CloudRun_Shift_Traffic
  versionLabel: "1"
  orgIdentifier: ${data.harness_platform_organization.this.id}
  projectIdentifier: ${data.harness_platform_project.this.id}
  description: This step shifts traffic to the latest revision to the amount set in the trafficPercentage input

EOT
}

resource "harness_platform_template" "deploy_cloudrun_canary" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "Deploy_CloudRun_Canary"
  name        = "Deploy CloudRun Canary"
  version       = "1"
  is_stable     = true
  tags        = ["source:templateLibrary"]
  template_yaml = <<-EOT
template:
  name: Deploy CloudRun Canary
  type: Step
  spec:
    type: ShellScript
    spec:
      shell: Bash
      executionTarget: {}
      source:
        type: Inline
        spec:
          script: |-
            source ~/.bashrc

            # Clone manifest
            workdir=$(mktemp -d)
            cd $workdir
            repo=$(echo <+infra.variables.serviceYamlRepo>|sed 's#https://##')
            git clone https://<+infra.variables.serviceYamlGitHubPAT>@$repo
            cd *

            # Get current CloudRun Revision
            current_revision=$(gcloud run revisions list --service=<+infra.variables.serviceName> --region=<+infra.variables.region> --limit=1|grep -v REVISION|awk '{print $2}')

            # Generate values.yaml with values in service YAML to override
            cat >values.yaml <<- EOF
            imageName: $artifactVersion
            lastRevision: $current_revision
            serviceName: <+infra.variables.serviceName>
            EOF

            # Render service YAML
            go-template -t <+infra.variables.serviceYamlPath> -f values.yaml > rendered-service-def.yaml
            cat rendered-service-def.yaml

            gcloud run services replace --region=<+infra.variables.region> rendered-service-def.yaml
      environmentVariables:
        - name: artifactVersion
          type: String
          value: <+input>.default(<+artifacts.primary.image>)
      outputVariables: []
      delegateSelectors:
        - <+infra.variables.deployDelegate>
    timeout: 10m
  identifier: Deploy_CloudRun_Canary
  orgIdentifier: ${data.harness_platform_organization.this.id}
  projectIdentifier: ${data.harness_platform_project.this.id}
  versionLabel: "1"
EOT
}

resource "harness_platform_template" "deploy_cloudrun_with_canary" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "Deploy_CloudRun_with_Canary"
  name        = "Deploy CloudRun with Canary"
  version       = "1"
  is_stable     = true
  tags        = ["source:templateLibrary"]
  template_yaml = <<-EOT
template:
  name: Deploy CloudRun with Canary
  identifier: Deploy_CloudRun_with_Canary
  versionLabel: "1"
  type: Stage
  tags: {}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  projectIdentifier: ${data.harness_platform_project.this.id}
  spec:
    type: Deployment
    spec:
      deploymentType: CustomDeployment
      customDeploymentRef:
        templateRef: ${harness_platform_template.google_cloud_run.id}
        versionLabel: "1"
      execution:
        steps:
          - step:
              name: Fetch Instances
              identifier: fetchInstances
              type: FetchInstanceScript
              timeout: 10m
              spec: {}
          - step:
              name: Deploy Canary
              identifier: Deploy_Canary
              template:
                templateRef: ${harness_platform_template.deploy_cloudrun_canary.id}
                versionLabel: "1"
                templateInputs:
                  type: ShellScript
                  spec:
                    environmentVariables:
                      - name: artifactVersion
                        type: String
                        value: <+artifacts.primary.image>
          - step:
              name: Shift Canary Traffic to 25 Percent
              identifier: Shift_Canary_Traffic_to_25_Percent
              template:
                templateRef: ${harness_platform_template.cloudrun_shift_traffic.id}
                versionLabel: "1"
                templateInputs:
                  type: ShellScript
                  spec:
                    environmentVariables:
                      - name: trafficPercentage
                        type: String
                        value: "25"
          - step:
              type: Verify
              name: Verify
              identifier: Verify
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
              timeout: 2h
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
              name: Rollout Canary
              identifier: Rollout_Canary
              template:
                templateRef: ${harness_platform_template.cloudrun_shift_traffic.id}
                versionLabel: "1"
                templateInputs:
                  type: ShellScript
                  spec:
                    environmentVariables:
                      - name: trafficPercentage
                        type: String
                        value: "100"
        rollbackSteps:
          - step:
              name: Deploy Revision
              identifier: Deploy_Revision
              template:
                templateRef: ${harness_platform_template.deploy_cloudrun_canary.id}
                versionLabel: "1"
                templateInputs:
                  type: ShellScript
                  spec:
                    environmentVariables:
                      - name: artifactVersion
                        type: String
                        value: <+rollbackArtifact.image>
          - step:
              name: Shift traffic to 100
              identifier: Shift_traffic_to_100
              template:
                templateRef: ${harness_platform_template.cloudrun_shift_traffic.id}
                versionLabel: "1"
                templateInputs:
                  type: ShellScript
                  spec:
                    environmentVariables:
                      - name: trafficPercentage
                        type: String
                        value: "100"
      environment:
        environmentRef: <+input>
        deployToAll: false
        environmentInputs: <+input>
        serviceOverrideInputs: <+input>
        infrastructureDefinitions: <+input>
      service:
        serviceRef: <+input>
        serviceInputs: <+input>
    failureStrategies:
      - onFailure:
          errors:
            - AllErrors
          action:
            type: StageRollback
EOT
}

resource "harness_platform_template" "google_cloud_run" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "Google_Cloud_Run"
  name        = "Google Cloud Run"
  version       = "1"
  is_stable     = true
  tags        = ["source:templateLibrary"]
  template_yaml = <<-EOT
template:
  name: Google Cloud Run
  identifier: Google_Cloud_Run
  type: CustomDeployment
  tags: {}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  projectIdentifier: ${data.harness_platform_project.this.id}
  spec:
    infrastructure:
      variables:
        - name: projectID
          type: String
          value: <+input>
          description: GCP Project ID
        - name: region
          type: String
          value: <+input>
          description: GCP Region
        - name: serviceName
          type: String
          value: <+service.name>
          description: The name of the Google Cloud Run service to deploy
          required: false
        - name: serviceYamlRepo
          type: String
          value: <+input>
          description: URL of the Repo that contains the service spec for this environment
          required: false
        - name: serviceYamlPath
          type: String
          value: <+input>
          description: Relative path to the service's YAML definition file from the base of the repository
          required: false
        - name: serviceYamlGitHubPAT
          type: String
          value: <+input>
          description: Secret reference to a secret containing a PAT that can clone the service's YAML definition
          required: false
        - name: deployDelegate
          type: String
          value: <+input>
          description: Delegate Selector for the delegate with the correct GCP IAM role to deploy to this environment
          required: false
      fetchInstancesScript:
        store:
          type: Inline
          spec:
            content: |
              #
              # Script is expected to query Infrastructure and dump json
              # in $INSTANCE_OUTPUT_PATH file path
              #
              # Harness is expected to initialize $${INSTANCE_OUTPUT_PATH}
              # environment variable - a random unique file path on delegate,
              # so script execution can save the result.
              #

              cat > $INSTANCE_OUTPUT_PATH << _EOF_
              {
                "data": [
                  {
                    "name": "<+service.name>-<+env.name>-<+infra.name>"
                  }
                ]
              } 
              _EOF_
      instanceAttributes:
        - name: instancename
          jsonPath: name
          description: ""
        - name: hostname
          jsonPath: name
          description: ""
      instancesListPath: data
    execution:
      stepTemplateRefs:
        - ${harness_platform_template.cloudrun_shift_traffic.id}
        - ${harness_platform_template.deploy_cloudrun_canary.id}
  versionLabel: "1"
EOT
}
