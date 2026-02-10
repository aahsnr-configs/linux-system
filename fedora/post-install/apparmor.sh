#!/bin/bash
echo 'write-cache' | sudo tee -a /etc/apparmor/parser.conf
echo 'cache-loc /etc/apparmor/earlypolicy/' | sudo tee -a /etc/apparmor/parser.conf
echo 'Optimize=compress-fast' | sudo tee -a /etc/apparmor/parser.conf

sudo mkdir -p /etc/apparmor.d/tunables/xdg-user-dirs.d/apparmor.d.d
