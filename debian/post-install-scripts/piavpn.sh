#!/bin/bash
PIA_INSTALLER=$(mktemp --suffix=.run)
trap "rm -f '$PIA_INSTALLER'" EXIT
wget -O "$PIA_INSTALLER" https://installers.privateinternetaccess.com/download/pia-linux-3.6.2-08398.run
chmod +x "$PIA_INSTALLER"
bash "$PIA_INSTALLER"
