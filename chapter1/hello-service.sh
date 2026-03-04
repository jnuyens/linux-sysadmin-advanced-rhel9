#!/bin/bash
# hello-service.sh - Simple service script for systemd exercise
# Place this file in /usr/local/bin/ and make executable

while true; do
    echo "$(date): Hello from custom service" >> /tmp/hello-service.log
    sleep 10
done
