# replace.yazi

A Yazi plugin that allows you to replace the currently hovered file/folder with previously yanked items.

## Demo

https://github.com/user-attachments/assets/e696650d-2f02-4a8d-8a75-95bf30f2b362

## Features

- Replace a file/folder with previously yanked (copied/cut) items
- Works with both files and directories
- Preserves the original name of the target (hovered) item
- Supports both copy and cut operations:
  - When yanked item is copied: Creates a replacement while keeping the source
  - When yanked item is cut: Moves the item to replace the target

## Install

```sh
git clone https://github.com/shuizhongyueming/replace.yazi.git ~/.config/yazi/plugins/replace.yazi
```

## Usage

1. First, yank (copy/cut) a file or folder using Yazi's default commands (`y`/`x`)
2. Hover over the file/folder you want to replace
3. Press the configured key (default `R`) to replace the hovered item with the yanked one

### Configuration

Edit `$XDG_CONFIG_HOME/yazi/keymap.toml`:

```toml
[manager]
prepend_keymap = [
    { on = [ "R" ], run = "plugin replace.lua", desc = "replace current hovered file with yanked file" },
]
```

## Notes

- If you haven't yanked any items before using the replace command, nothing will happen
- The operation preserves the name of the target (hovered) file/folder
- Source and target must be of the same type:
  - File can only replace file
  - Directory can only replace directory
  - Any mismatch between source and target types will result in an error
- The operation requires proper permissions for both source and target locations
