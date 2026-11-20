#!/usr/bin/env lua
-- Car pipeline entry point (run from the repo root).
--   lua art/rigs/cars/run.lua render [ids]   bpy venv check/setup, then every pose/paint render
--   lua art/rigs/cars/run.lua hero ID        clay/hint/depth/beauty passes for the paint flow
--   lua art/rigs/cars/run.lua keycard        garage key-card prop render
--   lua art/rigs/cars/run.lua assemble       atlases, manifest and contact sheet (Go, CPU)
--   lua art/rigs/cars/run.lua all            render + keycard + assemble
-- Renders go to $CANNONBALL_ART/cars/renders (default ~/.cache/tillandsias-project/
-- cannonball-art), never into the checkout. Only assemble writes assets/cars/.
local HOME = os.getenv("HOME")
local CACHE = os.getenv("CANNONBALL_ART") or (HOME .. "/.cache/tillandsias-project/cannonball-art")
local OUT = CACHE .. "/cars/renders"
local RIG = "art/rigs/cars/car_rig.py art/rigs/cars/cars.json art/rigs/cars/poses.json"

local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function sh(cmd)
  local ok = os.execute(cmd)
  if not (ok == true or ok == 0) then io.stderr:write("cars/run.lua: failed: " .. cmd .. "\n") os.exit(1) end
end
local function capture(cmd)
  local p = assert(io.popen(cmd)); local s = p:read("a"); local ok = p:close()
  if not ok then io.stderr:write("cars/run.lua: failed: " .. cmd .. "\n") os.exit(1) end
  return (s:gsub("%s+$", ""))
end
-- bpy prints a line per render tile; keep errors and our own summaries
local FILTER = " 2>&1 | grep -vE '^(Fra:|[0-9:.]+ +(render|gpu|blend))|DeprecationWarning|use_nodes'"

local function rig(extra)
  local py = capture("lua art/rigs/setup_bpy.lua")
  -- --threads 8: forge memory and CPU are shared; never more than 8 render threads
  sh(q(py) .. " -I " .. RIG .. " " .. q(OUT) .. " --threads 8 --samples 12 " .. extra .. FILTER)
end

local verb = arg[1]
if verb == "render" then
  rig(arg[2] and ("--ids " .. q(arg[2])) or "")
elseif verb == "hero" then
  rig("--ids " .. q(arg[2]) .. " --sheets body --passes clay,hint,depth")
elseif verb == "keycard" then
  rig("--prop keycard")
elseif verb == "assemble" then
  sh("go run -C tool/rigs ./cars assemble " .. q(OUT) .. " " .. q(capture("pwd")))
elseif verb == "all" then
  rig("--passes clay,hint,depth")
  rig("--prop keycard")
  sh("go run -C tool/rigs ./cars assemble " .. q(OUT) .. " " .. q(capture("pwd")))
else
  io.stderr:write("usage: lua art/rigs/cars/run.lua render [ids]|hero ID|keycard|assemble|all\n")
  os.exit(2)
end
