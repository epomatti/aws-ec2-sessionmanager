#!/usr/bin/env bash
su ec2-user

sudo yum makecache
sudo yum update
sudo yum -y install postgresql-jdbc
