-- =============================================================================
-- SellMode_Client (LocalScript)
-- Place this in: StarterGui > ShopGui > SellMode_Client  (LocalScript)
--                  OR StarterPlayerScripts > SellMode_Client
--
-- HOW IT WORKS:
--   1. A "Sell Mode" toggle button in the GUI activates / deactivates sell mode.
--   2. While active, hovering over player-owned machines highlights them red.
--   3. Left-clicking a valid machine fires the SellMachine RemoteEvent with the
--      model's name and location so the server can verify ownership and process
--      the refund.
-- =============================================================================

-- ─── Services ────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

-- ─── Remote Event ────────────────────────────────────────────────────────────
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 10)
local SellMachine = Remotes and Remotes:WaitForChild("SellMachine", 10)

if not SellMachine then
    warn("[SellMode] RemoteEvent 'SellMachine' not found.")
end

-- ─── Player & Camera ─────────────────────────────────────────────────────────
local player    = Players.LocalPlayer
local mouse     = player:GetMouse()
local camera    = workspace.CurrentCamera

-- ─── GUI References ──────────────────────────────────────────────────────────
local playerGui    = player:WaitForChild("PlayerGui")
local shopGui      = playerGui:WaitForChild("ShopGui")
local mainFrame    = shopGui:WaitForChild("MainFrame")
-- Expects a TextButton named "SellModeToggle" somewhere in MainFrame
local toggleButton = mainFrame:FindFirstChild("SellModeToggle", true)

-- ─── Visual Constants ────────────────────────────────────────────────────────
local HIGHLIGHT_COLOR     = Color3.fromRGB(255, 60,  60)   -- red hover highlight
local HIGHLIGHT_ALPHA     = 0.4                             -- transparency when hovered
local SELL_MODE_ON_COLOR  = Color3.fromRGB(200, 40,  40)
local SELL_MODE_OFF_COLOR = Color3.fromRGB(40,  40,  40)

-- ─── State ────────────────────────────────────────────────────────────────────
local sellModeActive      = false     -- is sell mode currently on?
local highlightedModel    = nil       -- the model currently highlighted
local originalPartData    = {}        -- stores {Color, Transparency} before highlighting
local clickDebounce       = false     -- prevents double-firing

-- ─── Highlight helpers ────────────────────────────────────────────────────────

--- Save original appearance of every BasePart in a model, then tint it.
-- @param model Model
local function highlightModel(model)
    if highlightedModel == model then return end  -- already highlighted

    -- Restore previous highlight first
    if highlightedModel then
        -- restoreHighlight() inline to avoid forward-reference issues
        for part, data in pairs(originalPartData) do
            if part and part.Parent then
                part.Color        = data.Color
                part.Transparency = data.Transparency
            end
        end
        originalPartData = {}
        highlightedModel = nil
    end

    -- Apply new highlight
    originalPartData = {}
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            originalPartData[part] = {
                Color        = part.Color,
                Transparency = part.Transparency,
            }
            part.Color        = HIGHLIGHT_COLOR
            part.Transparency = HIGHLIGHT_ALPHA
        end
    end
    highlightedModel = model
end

--- Remove the current highlight, restoring original colours.
local function clearHighlight()
    if not highlightedModel then return end
    for part, data in pairs(originalPartData) do
        if part and part.Parent then
            part.Color        = data.Color
            part.Transparency = data.Transparency
        end
    end
    originalPartData = {}
    highlightedModel = nil
end

-- ─── Raycast helper ───────────────────────────────────────────────────────────

--- Raycast from camera through the mouse cursor.
-- Returns the topmost Model ancestor of the hit part, or nil.
-- @return Model | nil, BasePart | nil  (model, hitPart)
local function getHoveredMachine()
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { player.Character }

    local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local result  = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, rayParams)

    if not result then return nil, nil end

    local hitPart  = result.Instance
    -- Walk up the hierarchy to find the root Model
    local hitModel = hitPart
    while hitModel and not hitModel:IsA("Model") do
        hitModel = hitModel.Parent
    end

    return hitModel, hitPart
end

--- Check whether a model belongs to this player.
-- Looks for an "OwnerUserId" StringValue tagged by the purchase system.
-- @param model Model
-- @return      boolean
local function isOwnedByLocalPlayer(model)
    local ownerTag = model:FindFirstChild("OwnerUserId")
    if not ownerTag then return false end
    return ownerTag.Value == tostring(player.UserId)
end

-- ─── Sell Mode Logic ──────────────────────────────────────────────────────────

--- Turn sell mode on or off.
-- @param state boolean
local function setSellMode(state)
    sellModeActive = state

    -- Update toggle button appearance
    if toggleButton then
        toggleButton.BackgroundColor3 = state and SELL_MODE_ON_COLOR or SELL_MODE_OFF_COLOR
        toggleButton.Text             = state and "Sell Mode: ON" or "Sell Mode: OFF"
    end

    -- Clear any lingering highlight when disabling
    if not state then
        clearHighlight()
    end

    print(("[SellMode] Sell mode is now %s."):format(state and "ON" or "OFF"))
end

-- ── RenderStepped: hover highlighting ────────────────────────────────────────
RunService.RenderStepped:Connect(function()
    if not sellModeActive then return end

    local model, _ = getHoveredMachine()

    if model and isOwnedByLocalPlayer(model) then
        highlightModel(model)
    else
        clearHighlight()
    end
end)

-- ── Mouse click: initiate sell ────────────────────────────────────────────────
mouse.Button1Down:Connect(function()
    if not sellModeActive then return end
    if clickDebounce then return end

    local model, _ = getHoveredMachine()

    if not model then return end
    if not isOwnedByLocalPlayer(model) then return end

    -- Debounce to prevent rapid double-clicks
    clickDebounce = true
    task.delay(0.5, function() clickDebounce = false end)

    -- Clear the highlight immediately for snappy feedback
    clearHighlight()

    -- Fire the server with the model's unique identifier
    -- We send the model itself as a reference; the server will verify ownership
    if SellMachine then
        SellMachine:FireServer(model)
    end
end)

-- ── Toggle button ─────────────────────────────────────────────────────────────
if toggleButton then
    toggleButton.MouseButton1Click:Connect(function()
        setSellMode(not sellModeActive)
    end)
else
    warn("[SellMode] 'SellModeToggle' button not found in MainFrame.")
end

-- Initialise with sell mode off
setSellMode(false)

print("[SellMode] Client sell mode script loaded.")
