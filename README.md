# replace.yazi

A yazi plugin to copy yanked file to replace the hovered file

## Install

```sh
git clone https://github.com/shuizhongyueming/replace.yazi.git ~/.config/yazi/plugins/replace.yazi
```

## Usage

Edit `$XDG_CONFIG_HOME/yazi/keymap.toml`:

```toml
[manager]
prepend_keymap = [
	{ on = [ "R" ], run = "plugin replace.lua", desc = "replace current hovered file with yanked file" },
]
```
