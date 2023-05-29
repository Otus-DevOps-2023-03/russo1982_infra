#!/bin/bash
set -e
sleep 60
sudo sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf
sleep 3
sudo systemctl restart mongod
sudo apt-get install -y python
