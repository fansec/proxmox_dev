#!/bin/bash

# Start the Kestra server in the background
/app/kestra server standalone -c /app/config.yaml &

# Wait for the server to start, then run the curl commands
sleep 5

# First curl command
curl -X POST http://localhost:8080/api/v1/flows/import \
  -H "Content-Type: multipart/form-data" \
  -F fileUpload=@/app/workflows/packer_all.yaml

# Second curl command
curl -X POST http://localhost:8080/api/v1/flows/import \
  -H "Content-Type: multipart/form-data" \
  -F fileUpload=@/app/workflows/ansible_ssh_delete.yaml

# Third curl command
curl -X POST http://localhost:8080/api/v1/flows/import \
  -H "Content-Type: multipart/form-data" \
  -F fileUpload=@/app/workflows/ansible_ssh_deploy.yaml

# Keep the server running in the foreground
wait

