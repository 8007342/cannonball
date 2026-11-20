#!/usr/bin/env lua
-- Idempotent preflight for headless Blender (bpy pip wheel), CPU only.
-- Creates or verifies a uv-managed Python 3.13 venv with bpy at
-- ~/.cache/tillandsias-project/bpy-venv (override with BPY_VENV). The cache
-- volume can be wiped by a host reset, so every pipeline run calls this first.
-- About 1 min / ~430 MB from PyPI when missing; ~1 s when present.
--
--   lua art/rigs/setup_bpy.lua          # prints the venv python path
--   lua art/rigs/setup_bpy.lua --check  # exit 1 if bpy is not importable
local BPY = os.getenv("BPY_VERSION") or "5.3.0"
local venv = os.getenv("BPY_VENV") or (os.getenv("HOME") .. "/.cache/tillandsias-project/bpy-venv")
local py = venv .. "/bin/python"

local function sh(cmd)
  io.stderr:write("+ " .. cmd .. "\n")
  local ok = os.execute(cmd)
  return ok == true or ok == 0
end

local function bpy_ok()
  local p = io.popen(py .. " -I -c 'import bpy; print(bpy.app.version_string)' 2>/dev/null")
  if not p then return false end
  local v = (p:read("*a") or ""):gsub("%s+$", "")
  p:close()
  return v:sub(1, #BPY) == BPY, v
end

local ok, have = bpy_ok()
if ok then print(py) os.exit(0) end
if arg[1] == "--check" then
  io.stderr:write("bpy " .. BPY .. " not importable from " .. py .. " (found '" .. (have or "") .. "')\n")
  os.exit(1)
end
if not (sh("uv python install 3.13")
    and sh("uv venv --allow-existing --python 3.13 '" .. venv .. "'")
    and sh("VIRTUAL_ENV='" .. venv .. "' uv pip install bpy==" .. BPY .. " pillow numpy")) then
  io.stderr:write("setup_bpy: install failed\n")
  os.exit(1)
end
ok, have = bpy_ok()
if not ok then
  io.stderr:write("setup_bpy: bpy still not importable (found '" .. (have or "") .. "')\n")
  os.exit(1)
end
print(py)
