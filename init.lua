local function fail(s, ...)
  ya.notify {
    title = "Replace",
    content = string.format(s, ...),
    timeout = 5,
    level = "error"
  }
end

-- 在同步上下文中获取当前悬停的文件
local get_hovered_file = ya.sync(function()
  local hovered = cx.active.current.hovered
  if not hovered then
    return nil, "No file hovered"
  end
  return tostring(hovered.url)
end)

-- 在同步上下文中获取yanked文件信息
local get_yanked_info = ya.sync(function()
  -- 检查是否有yanked文件
  if #cx.yanked == 0 then
    return nil, nil, "No file in clipboard"
  end

  -- 计算yanked文件数量并获取第一个文件
  local count = 0
  local first_url = nil
  for _, url in pairs(cx.yanked) do
    count = count + 1
    if count == 1 then
      first_url = tostring(url)
    end
  end

  -- 如果超过一个文件，返回错误
  if count > 1 then
    return nil, nil, "Multiple files in clipboard. Please yank only one file"
  end

  return first_url, cx.yanked.is_cut
end)

-- 检查文件类型是否匹配
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
  -- 获取悬停的文件
  local target, get_target_err = get_hovered_file()
  if not target then
    return fail(get_target_err)
  end

  ya.dbg("target: ", target)

  -- 获取yanked的文件
  local source, is_cut, get_source_err = get_yanked_info()
  if not source then
    return fail(get_source_err)
  end

  ya.dbg("source: ", source, " is_cut: ", is_cut)

  -- 转换为Url对象
  local target_url = Url(target)
  local source_url = Url(source)

  -- 确保源文件和目标文件都存在且可读
  local source_cha, source_err = fs.cha(source_url)
  if not source_cha then
    return fail("Source file does not exist or not accessible: %s", source_err or "unknown error")
  end

  local target_cha, target_err = fs.cha(target_url)
  if not target_cha then
    return fail("Target file does not exist or not accessible: %s", target_err or "unknown error")
  end

  -- 检查文件类型兼容性
  local compatible, err = check_files_compatibility(source_cha, target_cha)
  if not compatible then
    return fail(err)
  end

  -- 准备确认信息
  local type_str = source_cha.is_dir and "directory" or "file"
  local op_str = is_cut and "move" or "copy"

  -- 在替换前确认
  local confirm = ya.which {
    cands = {
      { on = "y", desc = string.format("%s and replace %s '%s' with '%s'",
        op_str:sub(1,1):upper() .. op_str:sub(2),
        type_str,
        target_url:name() or "target",
        source_url:name() or "source") },
      { on = "n", desc = "Cancel" },
    },
  }

  -- 如果用户取消或选择否，则返回
  if not confirm or confirm == 2 then
    ya.dbg("user canceled")
    return
  end

  ya.dbg("user confirmed")

  -- 根据操作类型和文件类型准备命令
  local shell_cmd
  if source_cha.is_dir then
    -- 对于目录，先删除目标目录，然后再复制/移动
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
    -- 对于普通文件，保持原来的逻辑
    local cmd = is_cut and "mv -f" or "cp -f"
    shell_cmd = string.format("%s %s %s",
      cmd,
      ya.quote(tostring(source_url)),
      ya.quote(tostring(target_url)))
  end

  ya.dbg("shell_cmd: ", shell_cmd)

  -- 执行替换操作
  local ok, err = Command("sh")
    :args({ "-c", shell_cmd })
    :stderr(Command.PIPED)
    :status()

  if not ok then
    return fail("Failed to %s and replace %s: %s", op_str, type_str, err or "unknown error")
  end

  ya.dbg("replace success")

  -- 刷新当前目录
  ya.manager_emit("reload", { "current" })

  ya.dbg("reload current")

  -- 显示成功消息
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
