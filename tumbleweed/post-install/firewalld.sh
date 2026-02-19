#!/bin/bash
sudo systemctl enable --now firewalld
sudo firewall-cmd --add-port=47/tcp --permanent
sudo firewall-cmd --remove-service=ssh --permanent
sudo firewall-cmd --reload
sudo systemctl reload sshd
