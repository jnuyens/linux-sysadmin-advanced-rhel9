#!/bin/bash
# hello-sysadmin.sh - Simple script to package as RPM
# This is the source file for the RPM building exercise

echo "Hello from the Advanced Sysadmin course!"
echo "Hostname: $(hostname)"
echo "Date: $(date)"
echo "Kernel: $(uname -r)"
echo "RHEL version: $(cat /etc/redhat-release 2>/dev/null || echo 'Not RHEL')"
