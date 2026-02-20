- [ ] Keep the asus-performance.sh as system-level systemd service as it needs to be run as root but make sure to test that it is working after restart. Basically it needs to work after graphical target.

I am configuring my emacs configuration. Let's say I have a configuration like below:

```el
(use-package something
  :config
  setq some-config-option1
       some-config-option2)
```

But now I need to put the above configuration in the form

```
(with-eval-after-load 'something

  )

```

Search the web and find out how I can achieve this. Think longer for this task.
