#!/bin/bash

yc compute instance create \
    --name test-reddit \
    --hostname test-redditfull \
    --memory=4 \
    --create-boot-disk image-id=fd8l19,size=10GB \
    --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
    --metadata serial-port-enable=1 \
    --metadata-from-file user-data=/home/std/git/russo1982_infra/packer/scripts/startup-ycli.yaml
