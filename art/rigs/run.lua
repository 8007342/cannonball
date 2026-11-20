#!/usr/bin/env lua
-- Structure pipeline entry point (run from the repo root).
--   lua art/rigs/run.lua render [ids]        bpy venv check/setup, then clay/hint/shade/depth passes
--   lua art/rigs/run.lua check  [ids]        grammar check only (no renders)
--   lua art/rigs/run.lua plan   [ids]        stage paint inputs, print studio.queue_workflow jobs
--   lua art/rigs/run.lua collect ID /work/tmp/imagegen/studio/<job>   keep outputs + review sheet
--   lua art/rigs/run.lua ingest ID PAINT.png "pick reason"
--   lua art/rigs/run.lua sheet               art/contact/structures.png from the picks
-- ids: comma list, prefix* allowed. Renders go to $CANNONBALL_ART/rigs (default
-- ~/.cache/tillandsias-project/cannonball-art), never into the checkout.
local HOME = os.getenv("HOME")
local CACHE = os.getenv("CANNONBALL_ART") or (HOME .. "/.cache/tillandsias-project/cannonball-art")
local BIN = CACHE .. "/bin/rigfinish"
local SPEC = "art/rigs/structures-rigs.json"

local function q(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function sh(cmd)
  local ok = os.execute(cmd)
  if not (ok == true or ok == 0) then io.stderr:write("run.lua: failed: " .. cmd .. "\n") os.exit(1) end
end
local function capture(cmd)
  local p = assert(io.popen(cmd)); local s = p:read("a"); local ok = p:close()
  if not ok then io.stderr:write("run.lua: failed: " .. cmd .. "\n") os.exit(1) end
  return (s:gsub("%s+$", ""))
end
local function bin()
  -- rebuild when any Go source is newer than the binary
  local lfs = require("lfs")
  local bt = lfs.attributes(BIN, "modification") or 0
  for f in lfs.dir("tool/rigs") do
    if f:match("%.go$") and (lfs.attributes("tool/rigs/" .. f, "modification") or 0) > bt then
      sh("mkdir -p " .. q(CACHE .. "/bin") .. " && cd tool/rigs && go build -o " .. q(BIN) .. " .")
      break
    end
  end
  return BIN
end

local verb = arg[1]
if verb == "render" or verb == "check" then
  local py = capture("lua art/rigs/setup_bpy.lua")
  local ids = arg[2] and (" --ids " .. q(arg[2])) or ""
  local extra = verb == "check" and " --check" or ""
  -- -t 8: forge memory and CPU are shared; never more than 8 render threads
  sh(q(py) .. " -I art/rigs/rig.py " .. SPEC .. " " .. q(CACHE .. "/rigs") .. ids .. extra ..
     " --threads 8 2>&1 | grep -vE '^(Fra:|[0-9:.]+ +(render|gpu|blend))'")
elseif verb == "collect" then
  -- copy a finished studio job's outputs (ephemeral) to $CACHE/paints/ID/<seed>.png + provenance
  local id, job = arg[2], arg[3]
  local dst = CACHE .. "/paints/" .. id
  sh("mkdir -p " .. q(dst))
  local list = {}
  for pf in io.popen("ls " .. q(job) .. "/*.png.provenance.json"):lines() do
    local pv = io.open(pf):read("a")
    local seed = pv:match('"seed": (%d+)')
    local png = pf:gsub("%.provenance%.json$", "")
    sh("cp " .. q(png) .. " " .. q(dst .. "/" .. seed .. ".png") .. " && cp " .. q(pf) .. " " .. q(dst .. "/" .. seed .. ".png.provenance.json"))
    list[#list + 1] = q(dst .. "/" .. seed .. ".png")
    print(dst .. "/" .. seed .. ".png")
  end
  sh(bin() .. " sheet -cell 512 -cols 2 " .. q(dst .. "/review.png") .. " " .. table.concat(list, " ") .. " >/dev/null")
  print(dst .. "/review.png")
elseif verb == "plan" then
  sh(bin() .. " plan" .. (arg[2] and (" -ids " .. q(arg[2])) or "") .. (arg[3] and (" -seed-offset " .. arg[3]) or ""))
elseif verb == "ingest" then
  sh(bin() .. " ingest -id " .. q(arg[2]) .. " -paint " .. q(arg[3]) .. " -pick " .. q(arg[4] or ""))
elseif verb == "sheet" then
  -- labelled sheet from tool/assets (shared look with the other families); fallback: unlabelled
  if not os.execute("go run -C tool/assets . contact structures") then sh(bin() .. " pack-sheet") end
else
  io.stderr:write("usage: lua art/rigs/run.lua render|check|plan|ingest|sheet ...\n") os.exit(2)
end
