-- =============================================================================
-- PurchaseHandler (Script)
-- Place this in: ServerScriptService > PurchaseHandler
--
-- Listens for PurchaseItem RemoteEvent requests from clients, validates the
-- purchase, deducts Cash from Leaderstats, and clones the item from
-- ServerStorage into the player's Inventory folder.
-- =============================================================================

-- ─── Services ────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage    = game:GetService("ServerStorage")

-- ─── Remote Event Setup ───────────────────────────────────────────────────────
-- Create the Remotes folder if it doesn't already exist
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
    or Instance.new("Folder", ReplicatedStorage)
Remotes.Name = "Remotes"

-- Create (or retrieve) the PurchaseItem RemoteEvent
local PurchaseItem = Remotes:FindFirstChild("PurchaseItem")
    or Instance.new("RemoteEvent", Remotes)
PurchaseItem.Name = "PurchaseItem"

-- ─── Item Catalog (SERVER-SIDE AUTHORITY) ─────────────────────────────────────
-- IMPORTANT: Always define prices on the server. Never trust client-sent prices.
-- This must stay in sync with the client-side catalog in ShopUI.lua.
--
-- Keys must match the names of models inside ServerStorage > ShopItems.
local ITEM_CATALOG = {
    -- Workers
    ["Miner"]      = { Cost = 50,  Type = "Worker"  },
    ["Sorter"]     = { Cost = 120, Type = "Worker"  },
    -- Machines
    ["Furnace"]    = { Cost = 100, Type = "Machine" },
    ["Crusher"]    = { Cost = 250, Type = "Machine" },
    ["Conveyor"]   = { Cost = 30,  Type = "Machine" },
    -- Tools
    ["Wrench"]     = { Cost = 75,  Type = "Tool"    },
    ["DeleteTool"] = { Cost = 0,   Type = "Tool"    },
}

-- Maximum items a player may own at once (anti-spam / performance guard)
local MAX_INVENTORY_SIZE = 100

-- ─── Debounce Table ──────────────────────────────────────────────────────────
-- Maps Player → timestamp of their last valid purchase request.
-- Prevents server-remote spam / rapid-fire exploiting.
local lastPurchaseTime = {}   -- [player] = tick()
local DEBOUNCE_SECONDS = 0.5  -- minimum seconds between purchases per player

-- ─── Helper: Get Leaderstats values ──────────────────────────────────────────

--- Safely retrieve the player's Cash IntValue from Leaderstats.
-- @param player Player
-- @return IntValue | nil
local function getCashValue(player)
    local ls = player:FindFirstChild("leaderstats")
    if not ls then return nil end
    return ls:FindFirstChild("Cash")
end

--- Get or create the player's Inventory folder under their player object.
-- @param player Player
-- @return Folder
local function getInventory(player)
    local inv = player:FindFirstChild("Inventory")
    if not inv then
        inv = Instance.new("Folder")
        inv.Name   = "Inventory"
        inv.Parent = player
    end
    return inv
end

-- ─── Helper: Sanity checks ────────────────────────────────────────────────────

--- Validate the incoming request before touching any game state.
-- Returns (true, nil) on success, or (false, reason) on failure.
-- @param player   Player
-- @param itemName any    Raw value from client (may be non-string)
-- @return boolean, string|nil
local function validateRequest(player, itemName)
    -- 1. Type safety – itemName must be a string
    if type(itemName) ~= "string" then
        return false, "invalid item name type"
    end

    -- 2. Item must exist in the authoritative server catalog
    local catalogEntry = ITEM_CATALOG[itemName]
    if not catalogEntry then
        return false, ("unknown item '%s'"):format(itemName)
    end

    -- 3. Debounce check
    local now  = tick()
    local last = lastPurchaseTime[player] or 0
    if (now - last) < DEBOUNCE_SECONDS then
        return false, "purchase too fast (debounce)"
    end

    -- 4. Player must have Leaderstats with a Cash value
    local cashValue = getCashValue(player)
    if not cashValue then
        return false, "leaderstats/Cash not found"
    end

    -- 5. Sufficient funds check
    if cashValue.Value < catalogEntry.Cost then
        return false, ("insufficient cash: has %d, needs %d"):format(
            cashValue.Value, catalogEntry.Cost)
    end

    -- 6. Inventory cap check
    local inventory = getInventory(player)
    local itemCount = #inventory:GetChildren()
    if itemCount >= MAX_INVENTORY_SIZE then
        return false, ("inventory full (%d/%d)"):format(itemCount, MAX_INVENTORY_SIZE)
    end

    -- 7. Item model must exist in ServerStorage > ShopItems
    local shopItems = ServerStorage:FindFirstChild("ShopItems")
    if not shopItems or not shopItems:FindFirstChild(itemName) then
        return false, ("server model '%s' not found in ServerStorage.ShopItems"):format(itemName)
    end

    return true, nil
end

-- ─── Purchase Handler ─────────────────────────────────────────────────────────

PurchaseItem.OnServerEvent:Connect(function(player, itemName)
    -- ── Validation ────────────────────────────────────────────────────────
    local ok, reason = validateRequest(player, itemName)
    if not ok then
        warn(("[PurchaseHandler] Rejected request from %s: %s"):format(
            player.Name, reason))
        return   -- silently reject – do NOT send error details to the client
    end

    -- ── Stamp debounce BEFORE touching game state ─────────────────────────
    -- This prevents a race condition where two near-simultaneous requests
    -- both pass the debounce check before either stamps the timestamp.
    lastPurchaseTime[player] = tick()

    -- ── Deduct cash ───────────────────────────────────────────────────────
    local catalogEntry = ITEM_CATALOG[itemName]
    local cashValue    = getCashValue(player)

    -- Re-check in case cash changed between validate and deduct
    if cashValue.Value < catalogEntry.Cost then
        warn(("[PurchaseHandler] Race-condition cash check failed for %s."):format(player.Name))
        return
    end

    cashValue.Value = cashValue.Value - catalogEntry.Cost

    -- ── Clone item into Inventory ──────────────────────────────────────────
    local shopItems   = ServerStorage.ShopItems
    local itemModel   = shopItems:FindFirstChild(itemName)
    local clonedItem  = itemModel:Clone()

    -- Tag the item with its owner and original cost (needed for the sell system)
    local ownerTag    = Instance.new("StringValue")
    ownerTag.Name     = "OwnerUserId"
    ownerTag.Value    = tostring(player.UserId)
    ownerTag.Parent   = clonedItem

    local costTag     = Instance.new("IntValue")
    costTag.Name      = "OriginalCost"
    costTag.Value     = catalogEntry.Cost
    costTag.Parent    = clonedItem

    local typeTag     = Instance.new("StringValue")
    typeTag.Name      = "ItemType"
    typeTag.Value     = catalogEntry.Type
    typeTag.Parent    = clonedItem

    -- Put into inventory folder (not yet in workspace – placement handles that)
    clonedItem.Parent = getInventory(player)

    print(("[PurchaseHandler] %s purchased '%s' for $%d (balance: $%d)"):format(
        player.Name, itemName, catalogEntry.Cost, cashValue.Value))
end)

-- ─── Cleanup on player leaving ────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
    lastPurchaseTime[player] = nil
end)

print("[PurchaseHandler] Server purchase handler ready.")
