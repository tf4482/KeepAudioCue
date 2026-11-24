-- KeepAudioCue: hide Blizzard's cooldown viewers visually while their sound alerts keep playing

local _, ns = ...

-- Blizzard plays alerts only while a viewer is shown, so this addon never hides one:
-- it sets the alpha to 0 and turns off tooltips, both visual-only and taint-free

-- cooldown viewers by setting key, in display order
local VIEWERS = {
  { key = "essential", frame = "EssentialCooldownViewer", label = "Essential Cooldowns" },
  { key = "utility", frame = "UtilityCooldownViewer", label = "Utility Cooldowns" },
  { key = "buffs", frame = "BuffIconCooldownViewer", label = "Tracked Buffs" },
  { key = "bars", frame = "BuffBarCooldownViewer", label = "Tracked Bars" },
}

-- viewers hidden by this addon, for a clean undo
local hidden = {}
-- hooks installed once the viewers exist
local setup = false
-- pending login or layout warning
local warnTimer

-- mouse tooltips on or off for all items of a viewer
local function SetTooltips(viewer, shown)
  -- Blizzard internal, may be missing
  if not viewer.itemFramePool then
    return
  end
  for item in viewer.itemFramePool:EnumerateActive() do
    item:SetMouseMotionEnabled(shown)
  end
end

-- hide or restore one viewer; Edit Mode always shows it for positioning
local function Apply(v)
  local viewer = v.viewer
  if ns.Get(v.key) and not (viewer.IsEditing and viewer:IsEditing()) then
    if not hidden[v] then
      hidden[v] = true
      v.alpha = viewer:GetAlpha()
    end
    viewer:SetAlpha(0)
    SetTooltips(viewer, false)
  elseif hidden[v] then
    hidden[v] = nil
    viewer:SetAlpha(v.alpha)
    SetTooltips(viewer, viewer.tooltipsShown ~= false)
  end
end

-- apply all viewers
local function Refresh()
  if not setup then
    return
  end
  for _, v in ipairs(VIEWERS) do
    Apply(v)
  end
end

-- reason why Blizzard keeps this viewer's alerts silent, or nil
local function Problem(v)
  if not C_CVar.GetCVarBool("cooldownViewerEnabled") then
    return "Cooldown Manager is disabled in the game options"
  end
  local visible = v.viewer.visibleSetting
  -- Blizzard internals, may be missing
  if visible == nil or not Enum.CooldownViewerVisibleSetting then
    return
  end
  if visible == Enum.CooldownViewerVisibleSetting.Hidden then
    return "Edit Mode visibility is Hidden"
  elseif visible == Enum.CooldownViewerVisibleSetting.InCombat then
    return "Edit Mode visibility is In Combat, silent out of combat"
  end
end

-- one status line for a viewer, with a hint when its alerts stay silent
local function Line(v)
  local state = ns.Get(v.key) and ns.Color("success", "hidden") or ns.Color("muted", "shown")
  local hint = ""
  if not v.viewer then
    hint = ns.Color("warning", " (viewer not found)")
  else
    local problem = Problem(v)
    if problem then
      hint = ns.Color("warning", " (alerts silent: " .. problem .. ")")
    end
  end
  ns.Print(v.label .. ": " .. state .. hint)
end

-- status of all viewers
local function Status()
  for _, v in ipairs(VIEWERS) do
    Line(v)
  end
end

-- warn about viewers the user hides here whose alerts Blizzard still silences
local function Warn()
  for _, v in ipairs(VIEWERS) do
    local problem = ns.Get(v.key) and v.viewer and Problem(v)
    if problem then
      ns.Warn(v.label .. ": alerts silent - " .. problem)
      ns.Detail("set Edit Mode visibility to " .. ns.Color("value", "Always")
        .. " and enable the Cooldown Manager; this addon hides the window")
    end
  end
end

-- one warning shortly after login or layout changes, merging bursts
local function WarnSoon()
  if warnTimer then
    warnTimer:Cancel()
  end
  warnTimer = C_Timer.NewTimer(1, Warn)
end

-- hook a viewer method only if this client has it
local function HookMethod(viewer, name, fn)
  if type(viewer[name]) == "function" then
    hooksecurefunc(viewer, name, fn)
  end
end

-- hook one viewer so Blizzard updates keep it hidden
local function Hook(v)
  local viewer = v.viewer
  -- Edit Mode entered or left
  HookMethod(viewer, "SetIsEditing", function()
    Apply(v)
  end)
  -- Edit Mode opacity reapplied: remember it, stay invisible
  HookMethod(viewer, "UpdateSystemSettingOpacity", function()
    if hidden[v] then
      v.alpha = viewer:GetAlpha()
      viewer:SetAlpha(0)
    end
  end)
  -- new item frames on layout refresh
  HookMethod(viewer, "OnAcquireItemFrame", function(_, item)
    if hidden[v] then
      item:SetMouseMotionEnabled(false)
    end
  end)
  -- Edit Mode tooltip setting reapplied
  HookMethod(viewer, "SetTooltipsShown", function()
    if hidden[v] then
      SetTooltips(viewer, false)
    end
  end)
end

-- find and hook the viewers once they and the saved state exist
local function Setup()
  if setup or ns.db == nil or not EssentialCooldownViewer then
    return
  end
  -- safe to mark early: every hook and access is guarded, nothing can fail halfway
  setup = true
  for _, v in ipairs(VIEWERS) do
    v.viewer = _G[v.frame]
    if v.viewer then
      Hook(v)
    end
  end
  Refresh()
end

-- event handlers by event name
local events = {}

-- Blizzard cooldown viewer loaded after this addon
function events.ADDON_LOADED(name)
  if name == "Blizzard_CooldownViewer" then
    Setup()
  end
end

-- layouts loaded or saved: check visibility settings
function events.EDIT_MODE_LAYOUTS_UPDATED()
  if setup then
    WarnSoon()
  end
end

-- one frame dispatching all events above
local frame = CreateFrame("Frame")
for event in pairs(events) do
  frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
  events[event](...)
end)

-- saved state; settings page and setup once loaded
local defaults = {}
for _, v in ipairs(VIEWERS) do
  defaults[v.key] = false
end
ns.Store("KeepAudioCueDB", defaults, function()
  ns.Settings()
  for _, v in ipairs(VIEWERS) do
    ns.Checkbox(v.key, "Hide " .. v.label,
      "Hide this Cooldown Manager window; its sound alerts keep playing", Refresh)
  end
  Setup()
end)

-- chat commands, one per viewer
for _, v in ipairs(VIEWERS) do
  ns.Command({
    name = v.key,
    help = "hide or show " .. v.label .. "; alerts keep playing",
    args = { { name = "state", choices = { "hide", "show" } } },
    run = function(args)
      ns.Set(v.key, args.state == "hide")
      Line(v)
    end,
  })
end
ns.Command({ name = "config", help = "open the settings page", run = ns.OpenSettings })
ns.Slash({ "/kac", "/keepaudiocue" }, Status)
