-- ============================================================================
-- 1. ENVIRONMENT INITIALIZATION & FALLBACK PROTECTION
-- ============================================================================
getgenv().Parvus = getgenv().Parvus or { 
    Utilities = { 
        UI = {},
        Drawing = {
            SetupCursor = function() end, SetupCrosshair = function() end, SetupFOV = function() end,
            AddObject = function() end, RemoveObject = function() end, AddESP = function() end, RemoveESP = function() end
        }
    }, 
    Game = { Name = "Those Who Remain" } 
}

if not Parvus.Utilities.UI.Window then
    Parvus.Utilities.UI.Window = function() 
        return { 
            Tab = function() return { Section = function() return { Toggle = function(s) return { Keybind = function() end, Tooltip = function() end } end, Slider = function() end, Dropdown = function() end, Divider = function() end } end end,
            Flags = {}
        } 
    end
end

-- ============================================================================
-- 2. SAFE CORE SERVICE INITIALIZATION
-- ============================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Camera = Workspace.CurrentCamera
local LocalPlayer = PlayerService.LocalPlayer
local SilentAim, Aimbot, Trigger = nil, false, false

-- Force-release stuck custom mouse states immediately
UserInputService.MouseBehavior = Enum.MouseBehavior.Default

-- ============================================================================
-- 3. CRITICAL ENGINE CORRECTIONS (GAME-PATH PATCHES)
-- ============================================================================
local World = Workspace:FindFirstChild("World") or Workspace
local Objectives = World:FindFirstChild("Objectives") or Instance.new("Folder")
local Entities = Workspace:FindFirstChild("Entities") or Workspace
local NPCFolder = Entities:FindFirstChild("Infected") or Workspace:FindFirstChild("NPCs") or Instance.new("Folder")
local Ignore = Workspace:FindFirstChild("Ignore") or Workspace
local Items = Ignore:FindFirstChild("Items") or Instance.new("Folder")

-- Safe module retrieval with timeouts to stop scripts from stalling out
local RayModule = ReplicatedStorage:WaitForChild("SharedModules", 5):WaitForChild("Utilities", 5):WaitForChild("Ray", 5) or { Cast = function() end }
local Bullet = LocalPlayer:WaitForChild("PlayerScripts", 5):WaitForChild("Modules", 5):WaitForChild("Other", 5):WaitForChild("Bullet", 5) or { Update = function() end }
local Interact = LocalPlayer:WaitForChild("PlayerScripts", 5):WaitForChild("Client", 5):WaitForChild("Interact", 5) or { Update = function() end }

-- ============================================================================
-- 4. CONFIGURATION DATABASE TABLES
-- ============================================================================
local ItemPickups = {
    {"50 Cal", false}, {"Ammo", false}, {"Bandages", false}, {"Barbed Wire", false},
    {"Body Armor", false}, {"Clap Bomb", false}, {"Energy Drink", false}, {"Frag", false},
    {"Gas Mask", false}, {"Jack", false}, {"Medkit", false}, {"Molotov", false}, {"Nerve Gas", false}
}

local KnownBodyParts = {
    {"Head", true}, {"HumanoidRootPart", true}, {"Torso", false},
    {"Right Arm", false}, {"Left Arm", false}, {"Right Leg", false}, {"Left Leg", false}
}

-- ============================================================================
-- 5. INTERFACE COMPOSER (TABS & SECTIONS)
-- ============================================================================
local Window = Parvus.Utilities.UI:Window({
    Name = ("Parvus Hub %s %s"):format(utf8.char(8212), Parvus.Game.Name),
    Position = UDim2.new(0.5, -248 * 3, 0.5, -248)
})

if not Window.Flags then Window.Flags = {} end

local CombatTab = Window:Tab({Name = "Combat"})
local AimbotSection = CombatTab:Section({Name = "Aimbot", Side = "Left"})
AimbotSection:Toggle({Name = "Enabled", Flag = "Aimbot/Enabled", Value = false})
    :Keybind({Flag = "Aimbot/Keybind", Value = "MouseButton2", Mouse = true, DisableToggle = true, Callback = function(Key, KeyDown) 
        Aimbot = Window.Flags["Aimbot/Enabled"] and KeyDown 
    end})
AimbotSection:Toggle({Name = "Always Enabled", Flag = "Aimbot/AlwaysEnabled", Value = false})
AimbotSection:Toggle({Name = "Distance Check", Flag = "Aimbot/DistanceCheck", Value = false})
AimbotSection:Toggle({Name = "Visibility Check", Flag = "Aimbot/VisibilityCheck", Value = false})
AimbotSection:Slider({Name = "Sensitivity", Flag = "Aimbot/Sensitivity", Min = 0, Max = 100, Value = 20, Unit = "%"})
AimbotSection:Slider({Name = "Field Of View", Flag = "Aimbot/FOV/Radius", Min = 0, Max = 500, Value = 100, Unit = "r"})
AimbotSection:Slider({Name = "Distance Limit", Flag = "Aimbot/DistanceLimit", Min = 25, Max = 1000, Value = 250, Unit = "studs"})

local PriorityList, BodyPartsList = {{Name = "Closest", Mode = "Button", Value = true}}, {}
for _, Value in pairs(KnownBodyParts) do
    PriorityList[#PriorityList + 1] = {Name = Value[1], Mode = "Button", Value = false}
    BodyPartsList[#BodyPartsList + 1] = {Name = Value[1], Mode = "Toggle", Value = Value[2]}
end
AimbotSection:Dropdown({Name = "Priority", Flag = "Aimbot/Priority", List = PriorityList})
AimbotSection:Dropdown({Name = "Body Parts", Flag = "Aimbot/BodyParts", List = BodyPartsList})

local AFOVSection = CombatTab:Section({Name = "Aimbot FOV Circle", Side = "Left"})
AFOVSection:Toggle({Name = "Enabled", Flag = "Aimbot/FOV/Enabled", Value = true})
AFOVSection:Toggle({Name = "Filled", Flag = "Aimbot/FOV/Filled", Value = false})
AFOVSection:Colorpicker({Name = "Color", Flag = "Aimbot/FOV/Color", Value = {1, 0.66666662693024, 1, 0.25, false}})
AFOVSection:Slider({Name = "NumSides", Flag = "Aimbot/FOV/NumSides", Min = 3, Max = 100, Value = 14})
AFOVSection:Slider({Name = "Thickness", Flag = "Aimbot/FOV/Thickness", Min = 1, Max = 10, Value = 2})

local SilentAimSection = CombatTab:Section({Name = "Silent Aim", Side = "Left"})
SilentAimSection:Toggle({Name = "Enabled", Flag = "SilentAim/Enabled", Value = false}):Keybind({Mouse = true, Flag = "SilentAim/Keybind"})
SilentAimSection:Toggle({Name = "Distance Check", Flag = "SilentAim/DistanceCheck", Value = false})
SilentAimSection:Toggle({Name = "Visibility Check", Flag = "SilentAim/VisibilityCheck", Value = false})
SilentAimSection:Slider({Name = "Hit Chance", Flag = "SilentAim/HitChance", Min = 0, Max = 100, Value = 100, Unit = "%"})
SilentAimSection:Slider({Name = "Field Of View", Flag = "SilentAim/FOV/Radius", Min = 0, Max = 500, Value = 100, Unit = "r"})
SilentAimSection:Slider({Name = "Distance Limit", Flag = "SilentAim/DistanceLimit", Min = 25, Max = 1000, Value = 250, Unit = "studs"})
SilentAimSection:Dropdown({Name = "Priority", Flag = "SilentAim/Priority", List = PriorityList})
SilentAimSection:Dropdown({Name = "Body Parts", Flag = "SilentAim/BodyParts", List = BodyPartsList})

local SAFOVSection = CombatTab:Section({Name = "Silent Aim FOV Circle", Side = "Right"})
SAFOVSection:Toggle({Name = "Enabled", Flag = "SilentAim/FOV/Enabled", Value = true})
SAFOVSection:Toggle({Name = "Filled", Flag = "SilentAim/FOV/Filled", Value = false})
SAFOVSection:Colorpicker({Name = "Color", Flag = "SilentAim/FOV/Color", Value = {0.6666666865348816, 0.6666666269302368, 1, 0.25, false}})
SAFOVSection:Slider({Name = "NumSides", Flag = "SilentAim/FOV/NumSides", Min = 3, Max = 100, Value = 14})
SAFOVSection:Slider({Name = "Thickness", Flag = "SilentAim/FOV/Thickness", Min = 1, Max = 10, Value = 2})

local TriggerSection = CombatTab:Section({Name = "Trigger", Side = "Right"})
TriggerSection:Toggle({Name = "Enabled", Flag = "Trigger/Enabled", Value = false})
    :Keybind({Flag = "Trigger/Keybind", Value = "MouseButton2", Mouse = true, DisableToggle = true, Callback = function(Key, KeyDown) 
        Trigger = Window.Flags["Trigger/Enabled"] and KeyDown 
    end})
TriggerSection:Toggle({Name = "Always Enabled", Flag = "Trigger/AlwaysEnabled", Value = false})
TriggerSection:Toggle({Name = "Hold Mouse Button", Flag = "Trigger/HoldMouseButton", Value = false})
TriggerSection:Toggle({Name = "Distance Check", Flag = "Trigger/DistanceCheck", Value = false})
TriggerSection:Toggle({Name = "Visibility Check", Flag = "Trigger/VisibilityCheck", Value = false})
TriggerSection:Slider({Name = "Click Delay", Flag = "Trigger/Delay", Min = 0, Max = 1, Precise = 2, Value = 0.15, Unit = "sec"})
TriggerSection:Slider({Name = "Distance Limit", Flag = "Trigger/DistanceLimit", Min = 25, Max = 1000, Value = 250, Unit = "studs"})
TriggerSection:Slider({Name = "Field Of View", Flag = "Trigger/FOV/Radius", Min = 0, Max = 500, Value = 25, Unit = "r"})
TriggerSection:Dropdown({Name = "Priority", Flag = "Trigger/Priority", List = PriorityList})
TriggerSection:Dropdown({Name = "Body Parts", Flag = "Trigger/BodyParts", List = BodyPartsList})

local TFOVSection = CombatTab:Section({Name = "Trigger FOV Circle", Side = "Right"})
TFOVSection:Toggle({Name = "Enabled", Flag = "Trigger/FOV/Enabled", Value = true})
TFOVSection:Toggle({Name = "Filled", Flag = "Trigger/FOV/Filled", Value = false})
TFOVSection:Colorpicker({Name = "Color", Flag = "Trigger/FOV/Color", Value = {0.0833333358168602, 0.6666666269302368, 1, 0.25, false}})
TFOVSection:Slider({Name = "NumSides", Flag = "Trigger/FOV/NumSides", Min = 3, Max = 100, Value = 14})
TFOVSection:Slider({Name = "Thickness", Flag = "Trigger/FOV/Thickness", Min = 1, Max = 10, Value = 2})

-- Safe handling for Visual elements drawing functions
