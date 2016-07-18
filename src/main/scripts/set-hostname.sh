#!/bin/bash
echo 'Removing old mesos registries in /etc/hosts'
sed -i '' '/mesos-/d' /etc/hosts
echo 'Add updated mesos registries in /etc/hosts'
gcloud compute instances list | grep 'mesos\-' | awk '{ print $5 "   " $1 }' >> /etc/hosts