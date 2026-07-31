#!/usr/bin/env bash

set -euo pipefail

exec cron -f
#!/bin/sh
#crond -f -d 8
tail -f /dev/null
