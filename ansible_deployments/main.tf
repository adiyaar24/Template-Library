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

resource "harness_platform_template" "this" {
  org_id        = data.harness_platform_organization.this.id
  project_id    = data.harness_platform_project.this.id
  identifier    = "ansible"
  name          = "ansible"
  version       = "0.0.1"
  is_stable     = true
  template_yaml = <<-EOT
template:
  name: ansible
  identifier: ansible
  versionLabel: 0.0.1
  type: CustomDeployment
  projectIdentifier: ${data.harness_platform_project.this.id}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  tags: {}
  spec:
    infrastructure:
      variables:
        - name: inventory_source
          type: String
          value: <+serviceVariables.inventory_source>
          description: ""
          required: false
        - name: inventory
          type: String
          value: <+serviceVariables.inventory>
          description: ""
          required: false
        # - name: target
        #   type: Connector
        #   value: <+input>
        #   description: ""
        #   required: false
      fetchInstancesScript:
        store:
          type: Inline
          spec:
            content: |+
              #
              # Script is expected to query Infrastructure and dump json
              # in $INSTANCE_OUTPUT_PATH file path
              #
              # Harness is expected to initialize $INSTANCE_OUTPUT_PATH
              # environment variable - a random unique file path on delegate,
              # so script execution can save the result.
              #

              cat <<'_EOF_' > $${INSTANCE_OUTPUT_PATH}
              {
                  "data": []
              }
              _EOF_

              if [[ "<+infra.variables.inventory_source>" == "filestore" ]]; then
                  cat <<'_EOF_' > $${INSTANCE_OUTPUT_PATH}
                  {"data": [
                    <+fileStore.getAsString("<+infra.variables.inventory>")>
                  ]}
              _EOF_
              fi

      instanceAttributes:
        - name: instancename
          jsonPath: server
          description: ""
        - name: app_id
          jsonPath: id
          description: ""
        - name: name
          jsonPath: name
          description: ""
      instancesListPath: data
    execution:
      stepTemplateRefs: []
EOT
}

resource "harness_platform_environment" "this" {
  org_id     = data.harness_platform_organization.this.id
  project_id = data.harness_platform_project.this.id
  identifier = "test"
  name       = "test"
  tags       = ["source:templateLibrary"]
  type       = "PreProduction"
  yaml       = <<-EOT
environment:
  name: test
  identifier: test
  type: PreProduction
  projectIdentifier: ${data.harness_platform_project.this.id}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  tags:
    source: templateLibrary
EOT
}

resource "harness_platform_infrastructure" "this" {
  org_id          = data.harness_platform_organization.this.id
  project_id      = data.harness_platform_project.this.id
  identifier      = "servers"
  name            = "servers"
  env_id          = harness_platform_environment.this.id
  type            = "CustomDeployment"
  deployment_type = "CustomDeployment"
  yaml            = <<-EOT
infrastructureDefinition:
  name: servers
  identifier: servers
  projectIdentifier: ${data.harness_platform_project.this.id}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  environmentRef: ${harness_platform_environment.this.id}
  deploymentType: CustomDeployment
  type: CustomDeployment
  spec:
    customDeploymentRef:
      templateRef: ${harness_platform_template.this.id}
      versionLabel: ${harness_platform_template.this.version}
    variables:
      - name: inventory_source
        type: String
        value: <+serviceVariables.inventory_source>
        description: ""
        required: false
      - name: inventory
        type: String
        value: <+serviceVariables.inventory>
        description: ""
        required: false
      # - name: target
      #   type: Connector
      #   value: <+input>
      #   description: ""
      #   required: false
  allowSimultaneousDeployments: false
EOT
}

resource "harness_platform_service" "this" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "ansible"
  name        = "ansible"
  description = "Example service for an ansible playbook"
  yaml        = <<-EOT
service:
  name: ansible
  identifier: ansible
  projectIdentifier: ${data.harness_platform_project.this.id}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  description: Example service for an ansible playbook
  serviceDefinition:
    spec:
      customDeploymentRef:
        templateRef: ${harness_platform_template.this.id}
        versionLabel: ${harness_platform_template.this.version}
      variables:
        - name: inventory_source
          type: String
          description: ""
          required: false
          value: filestore
        - name: inventory
          type: String
          description: ""
          required: false
          value: /<+env.name>/<+infra.name>
        - name: APP_ID
          type: String
          description: ""
          required: false
          value: A001
        - name: APP_NAME
          type: String
          description: ""
          required: false
          value: commercial
        - name: playbook
          type: String
          description: ""
          required: false
          value: <+input>
      artifacts:
        primary: {}
    type: CustomDeployment
EOT
}

# resource "harness_platform_connector_pdc" "this" {
#   org_id      = data.harness_platform_organization.this.id
#   project_id  = data.harness_platform_project.this.id
#   identifier  = "ansible"
#   name        = "ansible"
#   description = "Example connector for datacenter machines"
#   tags        = ["source:templateLibrary"]
#   host {
#     hostname = "localhost"
#     attributes = {
#       location = "us"
#     }
#   }
# }

resource "harness_platform_file_store_folder" "this" {
  org_id            = data.harness_platform_organization.this.id
  project_id        = data.harness_platform_project.this.id
  identifier        = "test"
  name              = "test"
  parent_identifier = "Root"
}

resource "harness_platform_file_store_file" "this" {
  org_id            = data.harness_platform_organization.this.id
  project_id        = data.harness_platform_project.this.id
  identifier        = "servers"
  name              = "servers"
  parent_identifier = harness_platform_file_store_folder.this.id
  file_content_path = "servers"
  file_usage        = "CONFIG"
}

resource "harness_platform_pipeline" "this" {
  org_id     = data.harness_platform_organization.this.id
  project_id = data.harness_platform_project.this.id
  identifier = "ansible"
  name       = "ansible"
  tags       = ["source:templateLibrary"]
  yaml       = <<-EOT
pipeline:
  name: ansible
  identifier: ansible
  projectIdentifier: ${data.harness_platform_project.this.id}
  orgIdentifier: ${data.harness_platform_organization.this.id}
  tags: 
    source: templateLibrary
  stages:
    - stage:
        name: deploy
        identifier: deploy
        description: ""
        type: Deployment
        spec:
          deploymentType: CustomDeployment
          customDeploymentRef:
            templateRef: ${harness_platform_template.this.id}
            versionLabel: ${harness_platform_template.this.version}
          service:
            serviceRef: <+input>
            serviceInputs: <+input>
          execution:
            steps:
              - step:
                  name: Fetch Instances
                  identifier: fetchInstances
                  type: FetchInstanceScript
                  timeout: 10m
                  spec: {}
              - stepGroup:
                  name: run ansible
                  identifier: run_ansible
                  steps:
                    - step:
                        type: GitClone
                        name: GitClone
                        identifier: GitClone
                        spec:
                          connectorRef: <+input>
                          repoName: <+input>
                          build: <+input>
                    - step:
                        type: Run
                        name: Run
                        identifier: Run
                        spec:
                          connectorRef: <+input>
                          image: alpinelinux/ansible
                          shell: Sh
                          command: |-
                            ls -lart /tmp

                            mkdir -p /tmp/sammy
                            chmod -R 777 /tmp/sammy

                            cat <<_EOF_ > inventory.txt
                            [<+infra.name>]
                            <+instance.name> remote_user=admin ansible_become_pass=admin
                            _EOF_

                            ansible-playbook /harness/<+execution.steps.run_ansible.steps.GitClone.spec.repoName>/<+serviceVariables.playbook> -i inventory.txt | tee playbook.log

                            status=$(sed -n -e '/PLAY RECAP/,$p' playbook.log | sed 1d | sed -e 's/^localhost.*ok/ok/')

                            echo $status
                            eval $status

                            OK=$ok
                            CHANGED=$changed
                            FAILED=$failed
                            SKIPPED=$skipped
                          envVariables:
                            ANSIBLE_HOST_KEY_CHECKING: "False"
                          outputVariables:
                            - name: OK
                            - name: CHANGED
                            - name: FAILED
                            - name: SKIPPED
                        strategy:
                          repeat:
                            items: <+stage.output.hosts>
                            nodeName: app_<+repeat.item>
                  sharedPaths:
                    - /workspace
                  stepGroupInfra:
                    type: KubernetesDirect
                    spec:
                      connectorRef: <+input>
                      namespace: <+input>
                  when:
                    stageStatus: Success
            rollbackSteps: []
          environment:
            environmentRef: <+input>
            deployToAll: false
            environmentInputs: <+input>
            serviceOverrideInputs: <+input>
            infrastructureDefinitions: <+input>
        tags: {}
        failureStrategies:
          - onFailure:
              errors:
                - AllErrors
              action:
                type: StageRollback
EOT
}