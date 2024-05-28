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

resource "harness_platform_connector_helm" "this" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "ff_relay_proxy_helm"
  name        = "ff relay proxy"
  description = "Helm chart for the v2 relay proxy"
  tags        = ["source:templateLibrary"]
  url         = "https://rssnyder.github.io/feature-flag-relay-proxy"
}

resource "harness_platform_connector_docker" "this" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "ff_relay_proxy_docker"
  name        = "ff relay proxy"
  description = "Connection to dockerhub for relay proxy"
  tags        = ["source:templateLibrary"]
  type        = "DockerHub"
  url         = "https://index.docker.io/v2/"
}

resource "harness_platform_connector_github" "test" {
  org_id          = data.harness_platform_organization.this.id
  project_id      = data.harness_platform_project.this.id
  identifier      = "ff_relay_proxy_github"
  name            = "ff relay proxy"
  description     = "Connection to github for relay proxy"
  tags            = ["source:templateLibrary"]
  url             = "https://github.com/rssnyder/feature-flag-relay-proxy"
  connection_type = "Repo"
  credentials {
    http {
      anonymous {}
    }
  }
}

resource "harness_platform_service" "this" {
  org_id      = data.harness_platform_organization.this.id
  project_id  = data.harness_platform_project.this.id
  identifier  = "ff_relay_proxy"
  name        = "ff relay proxy"
  description = "Deploying the v2 relay proxy via helm"

  yaml = <<-EOT
service:
  name: ff relay proxy
  identifier: ff_relay_proxy
  orgIdentifier: ${data.harness_platform_organization.this.id}
  projectIdentifier: ${data.harness_platform_project.this.id}
  serviceDefinition:
    type: Kubernetes
    spec:
      manifests:
        - manifest:
            identifier: chart
            type: HelmChart
            spec:
              store:
                type: Http
                spec:
                  connectorRef: ${harness_platform_connector_helm.this.id}
              chartName: ff-proxy
              chartVersion: <+input>
              subChartPath: ""
              helmVersion: V3
              skipResourceVersioning: false
              enableDeclarativeRollback: false
              fetchHelmChartMetadata: false
        - manifest:
            identifier: values
            type: Values
            spec:
              store:
                type: Github
                spec:
                  connectorRef: ${harness_platform_connector_github.test.id}
                  gitFetchType: Branch
                  paths:
                    - .harness/values.yaml
                  repoName: feature-flag-relay-proxy
                  branch: deploy-chart
      artifacts:
        primary:
          primaryArtifactRef: <+input>
          sources:
            - spec:
                connectorRef: ${harness_platform_connector_docker.this.id}
                imagePath: harness/ff-proxy
                tag: <+input>
                digest: ""
              identifier: main
              type: DockerRegistry
      variables:
        - name: proxyKey
          type: String
          description: "A relay proxy key"
          required: true
          value: <+input>
        - name: authSecret
          type: String
          description: "Used by the Proxy to sign JWT tokens, a random string"
          required: true
          value: <+input>
        - name: redisAddress
          type: String
          description: "The host and port of the redis server"
          required: true
          value: <+input>
EOT
}