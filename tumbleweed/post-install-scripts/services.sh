#!/bin/bash
systemctl --user daemon-reload
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service
