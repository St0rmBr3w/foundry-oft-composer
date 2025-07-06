#!/bin/bash

# Download LayerZero deployment artifacts
curl -o layerzero-deployments.json https://metadata.layerzero-api.com/v1/metadata/deployments
echo "Downloaded LayerZero deployments to layerzero-deployments.json"

# Download LayerZero DVN metadata
curl -o layerzero-dvns.json https://metadata.layerzero-api.com/v1/metadata/dvns
echo "Downloaded LayerZero DVN metadata to layerzero-dvns.json" 