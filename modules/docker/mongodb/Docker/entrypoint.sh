#!/bin/sh

set -eu

# Data is persistent. Initialization belongs in an explicit provisioning step;
# startup must never erase /data/db or leave initialization code unreachable.
exec mongod --bind_ip_all
