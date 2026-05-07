-- =============================================================================
-- SellMode_Server (Script)
-- Place this in: ServerScriptService > SellMode_Server
--
-- Listens for SellMachine RemoteEvent from clients.
-- Validates ownership, destroys the machine, and refunds 50% of the
-- original purchase cost to the player's Leaderstats Cash.
-- =============================================================================

-- ─── Services ────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ─── Remote Event Setup ───────────────────────────────────────────────────────
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 5)
local SellMachine = Remotes and Remotes:FindFirstChild("SellMachine")

-- Create the SellMachine RemoteEvent if it doesn't already exist
if not SellMachine then
    SellMachine      = Instance.new("RemoteEvent")
    SellMachine.Name = "SellMachine"
    SellMachine.Parent = Remotes or ReplicatedStorage
end

-- ─── Constants ────────────────────────────────────────────────────────────────
local REFUND_PERCENT = 0.5    -- players get 50% of original cost back

-- ─── Debounce ─────────────────────────────────────────────────────────────────
-- Prevents the same player from spamming the sell remote
local sellDebounce     = {}   -- [player] = tick()
local DEBOUNCE_SECONDS = 0.5

-- ─── Helper: leaderstats ─────────────────────────────────────────────────────

--- Get the Cash IntValue from a player's leaderstats.
-- @param player Player
-- @return IntValue | nil
local function getCashValue(player)
    local ls = player:FindFirstChild("leaderstats")
    if not ls then return nil end
    return ls:FindFirstChild("Cash")
end

-- ─── Validation ───────────────────────────────────────────────────────────────

--- Perform all security checks before processing a sell request.
-- @param player  Player
-- @param model   any    Raw value from the client (may be spoofed)
-- @return boolean, string|nil  (ok, reason)
local function validateSellRequest(player, model)
    -- 1. Debounce check
    local now  = tick()
    local last = sellDebounce[player] or 0
    if (now - last) < DEBOUNCE_SECONDS then
        return false, "sell request too fast (debounce)"
    end

    -- 2. Model must be a real Instance
    if typeof(model) ~= "Instance" then
        return false, "model argument is not an Instance"
    end

    -- 3. Model must still exist in the workspace (not already destroyed)
    if not model.Parent then
        return false, "model has no parent (already destroyed?)"
    end

    -- 4. Ownership verification via the OwnerUserId tag (set at purchase time)
    local ownerTag = model:FindFirstChild("OwnerUserId")
    if not ownerTag then
        return false, "model has no OwnerUserId tag"
    end
    if ownerTag.Value ~= tostring(player.UserId) then
        return false, ("ownership mismatch: tag=%s, player=%d"):format(
            ownerTag.Value, player.UserId)
    end

    -- 5. Model must have an OriginalCost tag
    local costTag = model:FindFirstChild("OriginalCost")
    if not costTag then
        return false, "model has no OriginalCost tag"
    end

    -- 6. Player must have leaderstats/Cash
    if not getCashValue(player) then
        return false, "player has no leaderstats/Cash"
    end

    return true, nil
end

-- ─── Sell Handler ─────────────────────────────────────────────────────────────

SellMachine.OnServerEvent:Connect(function(player, model)
    -- ── Validate ──────────────────────────────────────────────────────────
    local ok, reason = validateSellRequest(player, model)
    if not ok then
        warn(("[SellMode_Server] Rejected sell from %s: %s"):format(
            player.Name, reason))
        return
    end

    -- ── Stamp debounce ────────────────────────────────────────────────────
    sellDebounce[player] = tick()

    -- ── Calculate refund ─────────────────────────────────────────────────
    local costTag    = model:FindFirstChild("OriginalCost")
    local refund     = math.floor(costTag.Value * REFUND_PERCENT)

    local itemName   = model.Name   -- used for logging

    -- ── Destroy the model ─────────────────────────────────────────────────
    -- Must happen BEFORE crediting to prevent any exploit that might
    -- disconnect the client after the credit but before the destroy.
    model:Destroy()

    -- ── Credit the refund ─────────────────────────────────────────────────
    local cashValue = getCashValue(player)
    if cashValue then
        cashValue.Value = cashValue.Value + refund
        print(("[SellMode_Server] %s sold '%s' and received $%d refund (balance: $%d)"):format(
            player.Name, itemName, refund, cashValue.Value))
    else
        warn(("[SellMode_Server] Could not credit %s – leaderstats/Cash missing after sell."):format(
            player.Name))
    end
end)

-- ─── Cleanup on player leaving ────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
    sellDebounce[player] = nil
end)

print("[SellMode_Server] Server sell handler ready.")
