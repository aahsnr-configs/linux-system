- [ ] I want to use app2unit to use in my hyprland keybindings for launcing applications. I am certain I can do that with app2unit -- app, but for keybindings related to nautalia shell do I use append app2unit -- to the commands. I have attached the keybindings configuration from my Hyprland config

- [ ] The $editor variable in my keybindings.conf belongs to emacs and emacs has its own systemd user unit. And this systemd unit is responsible for procuding emacsclient. So I need to append app2unit -- to `emacsclient -c -a 'emacs'` or `emacsclient -t -a 'emacs'`
