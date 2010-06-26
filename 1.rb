#!/usr/bin/ruby

require 'yaml'

dump = `python dump-po.py /home/sasha/messages/kdebase/plasma_runner_recentdocuments.po`
print dump
#p YAML::load(dump)

