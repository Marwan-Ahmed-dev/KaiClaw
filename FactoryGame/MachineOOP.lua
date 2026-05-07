-- =============================================================================
-- MachineOOP (ModuleScript)
-- Place this in: ServerScriptService > Modules > MachineOOP
--
-- USAGE (from a Script / ServerScript):
--   local MachineOOP = require(game.ServerScriptService.Modules.MachineOOP)
--
--   -- Create a Furnace instance
--   local myFurnace = MachineOOP.Furnace.new(furnaceModel, player, 1.5)
--   myFurnace:Activate()   -- start listening for .Touched events
--   myFurnace:Deactivate() -- stop listening
--
--   -- Create a Conveyor instance
--   local myConveyor = MachineOOP.Conveyor.new(conveyorModel, Vector3.new(0, 0, -20))
--   myConveyor:Activate()
-- =============================================================================

local MachineOOP = {}

-- ─── Services ────────────────────────────────────────────────────────────────
local Players = game:GetService("Players")

-- ─── Utility ─────────────────────────────────────────────────────────────────

--- Safely get the player who owns a model by checking
-- the model's parent chain for a player's character.
-- @param part BasePart  A part from the suspect model
-- @return     Player | nil
local function getOwnerOfPart(part)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and part:IsDescendantOf(player.Character) then
            return player
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- BASE CLASS: Machine
-- All machine types inherit from this class.
-- ─────────────────────────────────────────────────────────────────────────────

local Machine = {}
Machine.__index = Machine

--- Constructor for the base Machine class.
-- @param model      Model   The Roblox model for this machine (already in workspace)
-- @param owner      Player  The player who placed/owns this machine
-- @param name       string  Display name (e.g. "Furnace", "Crusher")
-- @param multiplier number  Output multiplier applied to incoming part values
-- @param level      number  Starting level (used for upgrade systems)
-- @return           Machine
function Machine.new(model, owner, name, multiplier, level)
    local self = setmetatable({}, Machine)

    -- ── Core properties ───────────────────────────────────────────────────
    self.Model       = model       -- The workspace model
    self.Owner       = owner       -- Owning Player object
    self.Name        = name        -- Human-readable machine name
    self.Multiplier  = multiplier or 1   -- Default: no bonus
    self.Level       = level or 1        -- Default: level 1

    -- Internal state
    self._active     = false       -- Is the machine currently running?
    self._connections = {}         -- Table of RBXScriptConnections to clean up

    return self
end

--- Store a connection so it can be disconnected when the machine is destroyed.
-- @param connection RBXScriptConnection
function Machine:_trackConnection(connection)
    table.insert(self._connections, connection)
end

--- Activate the machine (begin processing).
-- Subclasses override this to attach their specific logic.
function Machine:Activate()
    self._active = true
    print(("[Machine] %s activated for player %s"):format(self.Name, self.Owner and self.Owner.Name or "Unknown"))
end

--- Deactivate the machine (stop processing, but keep it in world).
function Machine:Deactivate()
    self._active = false
    -- Disconnect all tracked event connections
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    self._connections = {}
    print(("[Machine] %s deactivated."):format(self.Name))
end

--- Destroy the machine completely – deactivates, then removes the model.
function Machine:Destroy()
    self:Deactivate()
    if self.Model and self.Model.Parent then
        self.Model:Destroy()
    end
    self.Model = nil
    print(("[Machine] %s destroyed."):format(self.Name))
end

--- Upgrade the machine by one level, increasing the multiplier.
-- @param multiplierBonus number  Extra multiplier added per level (default 0.25)
function Machine:Upgrade(multiplierBonus)
    multiplierBonus = multiplierBonus or 0.25
    self.Level      = self.Level + 1
    self.Multiplier = self.Multiplier + multiplierBonus
    print(("[Machine] %s upgraded to Level %d (Multiplier: %.2f)"):format(
        self.Name, self.Level, self.Multiplier))
end

--- Return a summary string – useful for debugging.
-- @return string
function Machine:__tostring()
    return ("[Machine] Name=%s | Level=%d | Multiplier=%.2f | Active=%s"):format(
        self.Name, self.Level, self.Multiplier, tostring(self._active))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SUBCLASS: Furnace (extends Machine)
-- Listens for .Touched events on its input part.
-- When a sand part touches it, the part is destroyed and the sand's value
-- (multiplied by self.Multiplier) is credited to the owner's temp cash pool.
-- ─────────────────────────────────────────────────────────────────────────────

local Furnace = setmetatable({}, { __index = Machine })
Furnace.__index = Furnace

--- Constructor for the Furnace subclass.
-- @param model      Model   The furnace model in workspace
-- @param owner      Player  Owning player
-- @param multiplier number  Cash multiplier (default 1)
-- @return           Furnace
function Furnace.new(model, owner, multiplier)
    -- Call the base constructor
    local self = Machine.new(model, owner, "Furnace", multiplier, 1)
    setmetatable(self, Furnace)

    -- Debounce table: prevents the same part triggering twice
    -- before it has been destroyed (can happen in the same physics step)
    self._debounce = {}

    return self
end

--- Credit the owner's Leaderstats with processed cash.
-- Uses a "TempCash" IntValue inside the player's leaderstats folder.
-- @param amount number  Raw cash amount to add (before multiplier is applied)
local function creditCash(owner, amount)
    if not owner then return end

    -- Look for Leaderstats > TempCash (IntValue or NumberValue)
    local leaderstats = owner:FindFirstChild("leaderstats")
    if not leaderstats then return end

    local tempCash = leaderstats:FindFirstChild("TempCash")
    if tempCash then
        tempCash.Value = tempCash.Value + math.floor(amount)
    end
end

--- Activate the furnace – attach the Touched listener to the input part.
-- The model must contain a BasePart named "InputBelt" or "Input" for the
-- touch detection. Adjust the name to match your model.
function Furnace:Activate()
    Machine.Activate(self)   -- call base implementation

    -- Find the input detector part inside the furnace model
    local inputPart = self.Model:FindFirstChild("Input") or
                      self.Model:FindFirstChild("InputBelt") or
                      self.Model.PrimaryPart

    if not inputPart then
        warn("[Furnace] No 'Input' part found in model – Touched listener not attached.")
        return
    end

    -- Connect the Touched event
    local conn = inputPart.Touched:Connect(function(hit)
        -- Only process if the machine is active
        if not self._active then return end

        -- We only care about parts tagged as "Sand"
        -- (Using a BoolValue named "IsSand" inside the part, or CollectionService tag)
        local isSand = hit:FindFirstChild("IsSand") or
                       (game:GetService("CollectionService"):HasTag(hit, "Sand"))

        if not isSand then return end

        -- Debounce: ignore if we're already processing this part
        if self._debounce[hit] then return end
        self._debounce[hit] = true

        -- Read the sand's monetary value (NumberValue named "Value" inside the part)
        local sandValueObj = hit:FindFirstChild("Value")
        local sandValue    = sandValueObj and sandValueObj.Value or 1

        -- Apply the multiplier
        local earned = sandValue * self.Multiplier

        -- Destroy the sand part (it's been "smelted")
        hit:Destroy()

        -- Clear the debounce entry (part is gone, so this is just tidying up)
        self._debounce[hit] = nil

        -- Credit the owner
        creditCash(self.Owner, earned)

        print(("[Furnace] Processed sand worth %d → credited %d to %s"):format(
            sandValue, math.floor(earned), self.Owner and self.Owner.Name or "?"))
    end)

    self:_trackConnection(conn)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SUBCLASS: Conveyor (extends Machine)
-- Uses AssemblyLinearVelocity (physics-based) to push unanchored parts
-- across its surface. No CFrame loops – fully physics-driven.
-- ─────────────────────────────────────────────────────────────────────────────

local Conveyor = setmetatable({}, { __index = Machine })
Conveyor.__index = Conveyor

--- Constructor for the Conveyor subclass.
-- @param model     Model    The conveyor model in workspace
-- @param owner     Player   Owning player (can be nil for world conveyors)
-- @param velocity  Vector3  World-space velocity to apply to parts on the belt
--                           Example: Vector3.new(0, 0, -20) = 20 studs/s forward
-- @return          Conveyor
function Conveyor.new(model, owner, velocity)
    local self = Machine.new(model, owner, "Conveyor", 1, 1)
    setmetatable(self, Conveyor)

    -- The velocity applied to any part resting on this conveyor
    self.BeltVelocity = velocity or Vector3.new(0, 0, -20)

    -- Track which parts are currently on the belt so we stop applying
    -- velocity once they leave
    self._partsOnBelt = {}

    return self
end

--- Activate the conveyor – attach Touched / TouchEnded listeners.
-- The physics approach: when a part lands on the belt, we set its
-- AssemblyLinearVelocity every heartbeat until it leaves.
function Conveyor:Activate()
    Machine.Activate(self)

    -- Get the surface part of the conveyor (PrimaryPart, or a part named "Belt")
    local beltPart = self.Model:FindFirstChild("Belt") or self.Model.PrimaryPart
    if not beltPart then
        warn("[Conveyor] No 'Belt' part found in model.")
        return
    end

    -- ── Track parts landing on / leaving the belt ─────────────────────────
    local touchedConn = beltPart.Touched:Connect(function(hit)
        if not self._active then return end
        -- Ignore anchored parts, the character, and other machines
        if hit.Anchored then return end
        if hit.Parent and Players:GetPlayerFromCharacter(hit.Parent) then return end

        -- Only move parts tagged as factory items (optional guard)
        -- Remove the next two lines if you want ALL unanchored parts to move
        -- local isItem = game:GetService("CollectionService"):HasTag(hit, "FactoryItem")
        -- if not isItem then return end

        self._partsOnBelt[hit] = true
    end)
    self:_trackConnection(touchedConn)

    local touchEndedConn = beltPart.TouchEnded:Connect(function(hit)
        self._partsOnBelt[hit] = nil
    end)
    self:_trackConnection(touchEndedConn)

    -- ── Heartbeat loop: apply velocity to every part currently on the belt ─
    -- Using Heartbeat (server-side physics step) is the correct approach.
    local heartbeatConn = game:GetService("RunService").Heartbeat:Connect(function()
        if not self._active then return end
        for part, _ in pairs(self._partsOnBelt) do
            -- Guard against parts that may have been destroyed
            if part and part.Parent then
                -- AssemblyLinearVelocity sets the velocity of the entire
                -- assembly (handles welds/constraints correctly)
                part.AssemblyLinearVelocity = self.BeltVelocity
            else
                -- Clean up stale references
                self._partsOnBelt[part] = nil
            end
        end
    end)
    self:_trackConnection(heartbeatConn)
end

--- Change the belt direction/speed at runtime.
-- @param newVelocity Vector3
function Conveyor:SetVelocity(newVelocity)
    self.BeltVelocity = newVelocity
end

-- ─────────────────────────────────────────────────────────────────────────────
-- MODULE EXPORTS
-- ─────────────────────────────────────────────────────────────────────────────

MachineOOP.Machine  = Machine
MachineOOP.Furnace  = Furnace
MachineOOP.Conveyor = Conveyor

return MachineOOP
