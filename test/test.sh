#!/usr/bin/env bash
cd test

bundle exec vagrant up --provider=onecloud
bundle exec vagrant up
bundle exec vagrant provision
bundle exec vagrant halt
bundle exec vagrant destroy

cd ..