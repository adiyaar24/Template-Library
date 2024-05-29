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

resource "harness_platform_secret_file" "this" {
  org_id                    = data.harness_platform_organization.this.id
  project_id                = data.harness_platform_project.this.id
  identifier                = "github_app_pem"
  name                      = "github app pem"
  description               = "PEM file for a github app"
  tags                      = ["source:templateLibrary"]
  file_path                 = "readme.md"
  secret_manager_identifier = "harnessSecretManager"
}

resource "harness_platform_template" "this" {
  org_id        = data.harness_platform_organization.this.id
  project_id    = data.harness_platform_project.this.id
  identifier    = "gitHub_app_pat_dispenser"
  name          = "gitHub app pat dispenser"
  version       = "0.0.1"
  is_stable     = true
  template_yaml = <<-EOT
template:
  name: gitHub app pat dispenser
  identifier: gitHub_app_pat_dispenser
  orgIdentifier: ${data.harness_platform_organization.this.id}
  projectIdentifier: ${data.harness_platform_project.this.id}
  versionLabel: 0.0.1
  type: SecretManager
  tags: {}
  spec:
    shell: Bash
    delegateSelectors: []
    source:
      type: Inline
      spec:
        script: |-
          set -o pipefail
          app_id=<+secretManager.environmentVariables.app_id>
          pem="
          <+secretManager.environmentVariables.github_app_private_key>
          "
          now=$(date +%s)
          iat=$(($${now} - 60)) # Issues 60 seconds in the past
          exp=$(($${now} + 600)) # Expires 10 minutes in the future
          b64enc() { openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }
          header_json='{
              "typ":"JWT",
              "alg":"RS256"
          }'
          # Header encode
          header=$( echo -n "$${header_json}" | b64enc )
          payload_json='{
              "iat":'"$${iat}"',
              "exp":'"$${exp}"',
              "iss":'"$${app_id}"'
          }'
          # Payload encode
          payload=$( echo -n "$${payload_json}" | b64enc )
          # Signature
          header_payload="$${header}"."$${payload}"
          signature=$(
              openssl dgst -sha256 -sign <(echo -n "$${pem}") \
              <(echo -n "$${header_payload}") | b64enc
          )
          # Create JWT
          JWT="$${header_payload}"."$${signature}"
          export PAT=$(curl --request POST \
          --url "https://api.github.com/app/installations/<+secretManager.environmentVariables.installation_id>/access_tokens" \
          --header "Accept: application/vnd.github+json" \
          --header "Authorization: Bearer $JWT" \
          --header "X-GitHub-Api-Version: 2022-11-28"|grep token|cut -d'"' -f4)
          # Export PAT as secret
          secret="$PAT"
    environmentVariables:
      - name: installation_id
        type: String
        value: <+input>
      - name: app_id
        type: String
        value: <+input>
      - name: github_app_private_key
        type: String
        value: <+input>
    outputVariables: []
    outputAlias:
      key: PAT
      scope: Pipeline
    onDelegate: true
  EOT
}

resource "harness_platform_connector_custom_secret_manager" "this" {
  org_id        = data.harness_platform_organization.this.id
  project_id    = data.harness_platform_project.this.id
  name          = "github app"
  identifier    = "github_app"
  type          = "CustomSecretManager"
  on_delegate   = true
  timeout       = 20
  template_ref  = harness_platform_template.this.identifier
  version_label = harness_platform_template.this.version

  template_inputs {
    environment_variable {
      name  = "installation_id"
      value = "00000000"
      type  = "String"
    }

    environment_variable {
      name  = "app_id"
      value = "000000"
      type  = "String"
    }

    environment_variable {
      name  = "github_app_private_key"
      value = "<+secrets.getValue(\"${harness_platform_secret_file.this.id}\")>"
      type  = "String"
    }
  }
}