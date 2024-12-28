local function fail(s, ...)
  ya.notify {
    title = "Replace",
    content = string.format(s, ...),
    timeout = 5,
    level = "error"
  }
end

-- Get the currently hovered file in sync context
local get_hovered_file = ya.sync(function()
  local hovered = cx.active.current.hovered
  if not hovered then
    return nil, "No file hovered"
  end
  return tostring(hovered.url)
end)

-- Get yanked file information in sync context
local get_yanked_info = ya.sync(function()
  -- Check if there's any yanked file
  if #cx.yanked == 0 then
    return nil, nil, "No file in clipboard"
  end

  -- Calculate yanked file count and get the first file
  local count = 0
  local first_url = nil
  for _, url in pairs(cx.yanked) do
    count = count + 1
    if count == 1 then
      first_url = tostring(url)
    end
  end

  -- Return error if more than one file
  if count > 1 then
    return nil, nil, "Multiple files in clipboard. Please yank only one file"
  end

  return first_url, cx.yanked.is_cut
end)

-- Check if file types are compatible
local function check_files_compatibility(source_cha, target_cha)
  if source_cha.is_dir ~= target_cha.is_dir then
    if source_cha.is_dir then
      return false, "Cannot replace a file with a directory"
    else
      return false, "Cannot replace a directory with a file"
    end
  end
  return true
end

local function entry()
  -- Get the hovered file
  local target, get_target_err = get_hovered_file()
  if not target then
    return fail(get_target_err)
  end

  ya.dbg("target: ", target)

  -- Get the yanked file
  local source, is_cut, get_source_err = get_yanked_info()
  if not source then
    return fail(get_source_err)
  end

  ya.dbg("source: ", source, " is_cut: ", is_cut)

  -- Convert to Url objects
  local target_url = Url(target)
  local source_url = Url(source)

  -- Ensure both source and target files exist and are readable
  local source_cha, source_err = fs.cha(source_url)
  if not source_cha then
    return fail("Source file does not exist or not accessible: %s", source_err or "unknown error")
  end

  local target_cha, target_err = fs.cha(target_url)
  if not target_cha then
    return fail("Target file does not exist or not accessible: %s", target_err or "unknown error")
  end

  -- Check file type compatibility
  local compatible, err = check_files_compatibility(source_cha, target_cha)
  if not compatible then
    return fail(err)
  end

  -- Prepare confirmation message
  local type_str = source_cha.is_dir and "dir" or "file"
  local op_str = is_cut and "mv" or "cp"

  -- Confirm before replacement
  local confirm = ya.which {
    cands = {
      { on = "y", desc = string.format("%s %s '%s' to replace '%s'",
        op_str:sub(1,1):upper() .. op_str:sub(2),
        type_str,
        source_url:name() or "source",
        target_url:name() or "target") },
      { on = "n", desc = "Cancel" },
    },
  }

  -- Return if user cancels or chooses no
  if not confirm or confirm == 2 then
    ya.dbg("user canceled")
    return
  end

  ya.dbg("user confirmed")

  -- Prepare command based on operation type and file type
  local shell_cmd
  if source_cha.is_dir then
    -- For directories, remove target directory first, then copy/move
    if is_cut then
      shell_cmd = string.format("rm -rf %s && mv -f %s %s",
        ya.quote(tostring(target_url)),
        ya.quote(tostring(source_url)),
        ya.quote(tostring(target_url)))
    else
      shell_cmd = string.format("rm -rf %s && cp -r %s %s",
        ya.quote(tostring(target_url)),
        ya.quote(tostring(source_url)),
        ya.quote(tostring(target_url)))
    end
  else
    -- For regular files, keep original logic
    local cmd = is_cut and "mv -f" or "cp -f"
    shell_cmd = string.format("%s %s %s",
      cmd,
      ya.quote(tostring(source_url)),
      ya.quote(tostring(target_url)))
  end

  ya.dbg("shell_cmd: ", shell_cmd)

  -- Execute replacement operation
  local ok, err = Command("sh")
    :args({ "-c", shell_cmd })
    :stderr(Command.PIPED)
    :status()

  if not ok then
    return fail("Failed to %s and replace %s: %s", op_str, type_str, err or "unknown error")
  end

  ya.dbg("replace success")

  -- Refresh current directory
  ya.manager_emit("reload", { "current" })

  ya.dbg("reload current")

  -- Show success message
  ya.notify {
    title = "Replace",
    content = string.format("Successfully %s and replaced %s '%s' with '%s'",
      op_str,
      type_str,
      target_url:name() or "target",
      source_url:name() or "source"),
    timeout = 5
  }
end

return { entry = entry }
