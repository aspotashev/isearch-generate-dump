#!/usr/bin/ruby

require 'yaml'

dump = `python dump-po.py /home/sasha/messages/kdebase/dolphin.po`
p YAML::load(dump)

