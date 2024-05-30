| Key          | Value                   |
|--------------|-------------------------|
| Category     | CD                 |
| Name         | Custom Deployment Template for Ansible         |
| ShortDescription | TRun ansible using CD using a custom deployment template and pipeline |


## Overview
This Terraform configuration sets up a custom deployment on the Harness Platform using an Ansible playbook. It includes the creation of an organization, project, template, environment, infrastructure, service, file store, and a pipeline to orchestrate the deployment.

## Resources

| Resource Type                    | Description                            | Identifier  | Name     | Additional Info     |
|----------------------------------|----------------------------------------|-------------|----------|---------------------|
| Harness Platform Template        | Creates a custom deployment template for Ansible | ansible     | ansible  | Version: 0.0.1      |
| Harness Platform Environment     | Creates a pre-production environment   | test        | test     | Type: PreProduction |
| Harness Platform Infrastructure  | Defines the infrastructure for custom deployment | servers     | servers  | Type: CustomDeployment |
| Harness Platform Service         | Creates a service definition for the Ansible playbook | ansible     | ansible  |                     |
| Harness Platform File Store      | Creates a folder and file in the file store | test        | servers  | File Content Path: servers |

