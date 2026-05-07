-- =============================================================================
-- GridPlacementSystem (ModuleScript)
-- Place this in: ReplicatedStorage > Modules > GridPlacementSystem
--
-- USAGE (from a LocalScript):
--   local GridPlacement = require(game.ReplicatedStorage.Modules.GridPlacementSystem)
--   GridPlacement.Init(player, camera, mouse)
--   GridPlacement.StartPlacement(itemModel)
--   GridPlacement.StopPlacement()
-- =============================================================================

local GridPlacementSystem = {}

-- ─── Services ────────────────────────────────────────────────────────────────
local RunService    = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- ─── Constants ───────────────────────────────────────────────────────────────
local GRID_SIZE     = 3          -- 3×3 stud grid
local ROTATION_STEP = 90         -- degrees per R-key press
local PLACEMENT_Y_OFFSET = 0     -- studs above the grid surface (tweak per model)

-- Colours used to tint the preview ghost model
local VALID_COLOR   = Color3.fromRGB(0, 200, 0)    -- green  = placement OK
local INVALID_COLOR = Color3.fromRGB(200, 0, 0)    -- red    = placement blocked
local GHOST_ALPHA   = 0.5                           -- transparency of the ghost

-- ─── Module State ─────────────────────────────────────────────────────────────
local isPlacing       = false    -- are we currently in placement mode?
local ghostModel      = nil      -- the translucent preview model
local currentRotation = 0        -- accumulated Y-rotation in degrees
local isValidPlacement = false   -- cached result of the latest bounds check

-- References set via GridPlacement.Init()
local _player  = nil
local _camera  = nil
local _mouse   = nil

-- The RenderStepped connection handle (so we can disconnect later)
local _renderConnection = nil
-- The input connection handle
local _inputConnection  = nil

-- ─── Private Helpers ─────────────────────────────────────────────────────────

--- Snap a world-space Vector3 to the nearest GRID_SIZE boundary.
-- @param position Vector3  Raw world position
-- @return         Vector3  Grid-snapped position
local function snapToGrid(position)
    local snappedX = math.round(position.X / GRID_SIZE) * GRID_SIZE
    local snappedZ = math.round(position.Z / GRID_SIZE) * GRID_SIZE
    -- Y is determined by the surface hit, not snapped independently
    return Vector3.new(snappedX, position.Y, snappedZ)
end

--- Build a CFrame for placing a model at a grid-snapped position with the
-- current Y-axis rotation applied.
-- @param snappedPos Vector3
-- @return           CFrame
local function buildPlacementCFrame(snappedPos)
    -- Start at the snapped position
    local cf = CFrame.new(snappedPos)
    -- Apply accumulated Y-rotation (CFrame.Angles takes radians)
    cf = cf * CFrame.Angles(0, math.rad(currentRotation), 0)
    return cf
end

--- Make every BasePart inside a model semi-transparent and set its colour.
-- We also disable CanCollide on the ghost so it doesn't interfere with
-- the overlap / bounds checks.
-- @param model  Model   The ghost model to tint
-- @param colour Color3
local function applyGhostAppearance(model, colour)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Color        = colour
            part.Transparency = GHOST_ALPHA
            part.CanCollide   = false   -- ghost never collides
            part.Anchored     = true    -- keep it in place while previewing
        end
    end
end

--- Get the player's designated Plot model.
-- Expects the plot to be a Model named "Plot" inside a folder
-- structure like Workspace.Plots.<player.UserId>.
-- Adjust the path to match your game's actual hierarchy.
-- @return Model | nil
local function getPlayerPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    return plots:FindFirstChild(tostring(_player.UserId))
end

--- Check whether an AABB (bounding box) is fully contained within the
-- XZ extents of the player's plot AND does not overlap any existing
-- BasePart that is NOT the ghost model.
--
-- @param targetCFrame CFrame   Proposed CFrame for the model
-- @param model        Model    The original (server) model for size reference
-- @return             boolean  true = placement is legal
local function isPlacementValid(targetCFrame, model)
    -- ── 1. Compute the model's bounding box size ──────────────────────────
    local _, size = model:GetBoundingBox()
    local halfSize = size / 2

    -- ── 2. Plot bounds check ──────────────────────────────────────────────
    local plot = getPlayerPlot()
    if plot then
        local plotPart = plot:FindFirstChildWhichIsA("BasePart")
        if plotPart then
            -- Convert the proposed centre into the plot's local space
            local localPos = plotPart.CFrame:PointToObjectSpace(targetCFrame.Position)
            local plotHalf = plotPart.Size / 2

            -- The bounding box corners must all be inside the plot (XZ only)
            if math.abs(localPos.X) + halfSize.X > plotHalf.X or
               math.abs(localPos.Z) + halfSize.Z > plotHalf.Z then
                return false  -- model sticks out of the plot
            end
        end
    end

    -- ── 3. Overlap check (spatial query) ─────────────────────────────────
    -- Build the overlap parameters: a box at the proposed CFrame
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude

    -- Exclude the ghost model itself and the character from collision checks
    local excludeList = { _player.Character }
    if ghostModel then
        table.insert(excludeList, ghostModel)
    end
    overlapParams.FilterDescendantsInstances = excludeList

    local touching = workspace:GetPartBoundsInBox(targetCFrame, size, overlapParams)

    -- If anything is returned the spot is occupied
    if #touching > 0 then
        return false
    end

    return true
end

--- Create (or recreate) a ghost/preview copy of the given model.
-- @param sourceModel Model
-- @return            Model  The ghost clone
local function createGhost(sourceModel)
    -- Clean up any old ghost first
    if ghostModel then
        ghostModel:Destroy()
        ghostModel = nil
    end

    -- Deep-clone the model so we have a full structural copy
    local ghost = sourceModel:Clone()
    ghost.Name  = "PlacementGhost"

    -- Apply semi-transparent green tint to start
    applyGhostAppearance(ghost, VALID_COLOR)

    ghost.Parent = workspace
    return ghost
end

--- Move the ghost model to a new CFrame and update its colour
-- based on placement validity.
-- @param cf    CFrame
-- @param valid boolean
local function updateGhost(cf, valid)
    if not ghostModel then return end

    -- Reposition via PivotTo (respects the model's PrimaryPart or pivot)
    ghostModel:PivotTo(cf)

    -- Recolour to communicate validity
    local colour = valid and VALID_COLOR or INVALID_COLOR
    applyGhostAppearance(ghostModel, colour)
end

-- ─── Raycast ──────────────────────────────────────────────────────────────────

--- Cast a ray from the camera through the mouse position and return the
-- hit CFrame (snapped to grid) or nil if nothing was hit.
--
-- @param sourceModel Model   Needed for Y-offset calculation
-- @return CFrame | nil, boolean  (placement CFrame, isValid)
local function getPlacementCFrame(sourceModel)
    -- Build raycast parameters that ignore the ghost and the character
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {
        _player.Character,
        ghostModel,
    }

    -- Direction: from camera, through mouse, 500 studs deep
    local unitRay = _camera:ScreenPointToRay(_mouse.X, _mouse.Y)
    local result  = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, rayParams)

    if not result then
        return nil, false
    end

    -- Snap the hit position to the grid
    local hitPos    = result.Position
    local snapped   = snapToGrid(hitPos)

    -- Raise the Y by the model's half-height so the base sits on the surface
    local _, size   = sourceModel:GetBoundingBox()
    local finalPos  = Vector3.new(snapped.X, hitPos.Y + (size.Y / 2) + PLACEMENT_Y_OFFSET, snapped.Z)

    local placementCF = buildPlacementCFrame(finalPos)
    local valid       = isPlacementValid(placementCF, sourceModel)

    return placementCF, valid
end

-- ─── Public API ───────────────────────────────────────────────────────────────

--- Initialise the module with the required Roblox objects.
-- Call this once from your LocalScript before any placement.
-- @param player Player
-- @param camera Camera
-- @param mouse  UserInputService mouse (game:GetService("Players").LocalPlayer:GetMouse())
function GridPlacementSystem.Init(player, camera, mouse)
    _player = player
    _camera = camera
    _mouse  = mouse
end

--- Begin placement mode for a given item model.
-- The model should be the "template" stored in ReplicatedStorage or ServerStorage.
-- @param itemModel Model   The model to place (will be cloned as a ghost)
-- @param onConfirm function(CFrame)  Called with the final CFrame when placed
-- @param onCancel  function()        Called if placement is cancelled (RMB / Escape)
function GridPlacementSystem.StartPlacement(itemModel, onConfirm, onCancel)
    if isPlacing then
        GridPlacementSystem.StopPlacement()
    end

    isPlacing       = true
    currentRotation = 0   -- reset rotation each time

    -- Create the semi-transparent ghost preview
    ghostModel = createGhost(itemModel)

    -- ── RenderStepped: update ghost position every frame ──────────────────
    _renderConnection = RunService.RenderStepped:Connect(function()
        if not isPlacing then return end

        local cf, valid = getPlacementCFrame(itemModel)
        if cf then
            isValidPlacement = valid
            updateGhost(cf, valid)
        end
    end)

    -- ── Input: handle rotation (R), confirm (LMB), cancel (RMB / Escape) ──
    _inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end  -- ignore if UI consumed the input

        -- Rotate 90° on R key press
        if input.KeyCode == Enum.KeyCode.R then
            currentRotation = (currentRotation + ROTATION_STEP) % 360

        -- Left mouse button = confirm placement
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            if isValidPlacement then
                local cf, valid = getPlacementCFrame(itemModel)
                if cf and valid then
                    GridPlacementSystem.StopPlacement()
                    if onConfirm then
                        onConfirm(cf)   -- caller handles firing RemoteEvent
                    end
                end
            end

        -- Right mouse button or Escape = cancel
        elseif input.UserInputType == Enum.UserInputType.MouseButton2
            or input.KeyCode == Enum.KeyCode.Escape then
            GridPlacementSystem.StopPlacement()
            if onCancel then
                onCancel()
            end
        end
    end)
end

--- Stop placement mode immediately, cleaning up the ghost and connections.
function GridPlacementSystem.StopPlacement()
    isPlacing = false

    -- Disconnect render loop
    if _renderConnection then
        _renderConnection:Disconnect()
        _renderConnection = nil
    end

    -- Disconnect input handler
    if _inputConnection then
        _inputConnection:Disconnect()
        _inputConnection = nil
    end

    -- Remove the ghost model from the workspace
    if ghostModel then
        ghostModel:Destroy()
        ghostModel = nil
    end
end

--- Returns true if a placement session is currently active.
-- @return boolean
function GridPlacementSystem.IsPlacing()
    return isPlacing
end

--- Returns the current rotation (degrees) of the placement preview.
-- @return number
function GridPlacementSystem.GetCurrentRotation()
    return currentRotation
end

return GridPlacementSystem
