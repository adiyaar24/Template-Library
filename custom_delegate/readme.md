| Key          | Value                   |
|--------------|-------------------------|
| Category     | Platform                 |
| Name         | Custom Delegate          |
| ShortDescription | Create a custom delegate image stored in your internal container registry |


## Overview
This Terraform configuration sets up a pipeline on the Harness Platform to build and push a custom delegate image into a local repository. The pipeline includes stages to fetch the latest delegate version, build the delegate image, and perform a security scan.

## Pipeline Stages

1. **Get Latest Delegate Version**
   - Fetches the latest supported version of the Harness Delegate using an HTTP step.

2. **Build Harness Delegate**
   - **Create Dockerfile**: Generates a Dockerfile with the specified delegate version.
   - **Build and Push Docker Image**: Builds and pushes the Docker image to the specified registry.
   - **Aqua Scan**: Performs a security scan on the built Docker image.

