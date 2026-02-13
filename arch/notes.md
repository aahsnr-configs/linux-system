- use unencrypted 32 swap partition during cachyos
- reduce limine to 2G
- add the subvolumes from my manual setup

- tuigreet --cmd start-hyprland
- resume from unencrypted swap

resume=UUID=9e46e3e4-5b32-461d-960a-488c9c96ed80

disabling nvidia-powerd seemed to increase to cpu clock speeds
sudo systemctl mask nvidia-powerd.service
