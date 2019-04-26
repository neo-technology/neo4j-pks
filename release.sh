#!/bin/bash
#
# Create a Pivnet release
#
# Docs: https://drive.google.com/drive/u/0/folders/1sQ3bcck_UXRG7oy9QaK0z84jKgAWUkcp
#
curl --silent https://network.pivotal.io/api/v2/authentication/access_tokens \
      -d "{\"refresh_token\":\"$PIVNET_REFRESH_TOKEN\"}" | jq -r '.access_token'