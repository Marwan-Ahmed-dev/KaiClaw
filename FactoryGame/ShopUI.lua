-- =============================================================================
-- ShopUI (LocalScript)
-- Place this in: StarterGui > ShopGui > ShopUI  (as a LocalScript)
--
-- Expected UI hierarchy (create in Studio):
--   ScreenGui  "ShopGui"
--   └─ Frame   "MainFrame"
--      ├─ Frame "TabBar"
--      │   ├─ TextButton "WorkersTab"
--      │   ├─ TextButton "MachinesTab"
--      │   └─ TextButton "ToolsTab"
--      ├─ Frame "WorkersFrame"   (ScrollingFrame inside named "List")
--      ├─ Frame "MachinesFrame"  (ScrollingFrame inside named "List")
--      └─ Frame "ToolsFrame"     (ScrollingFrame inside named "List")
--
-- Each ScrollingFrame ("List") should contain a single template button:
--   TextButton  "ItemTemplate"  (set Visible = false)
--     └─ TextLabel "NameLabel"
--     └─ TextLabel "CostLabel"
--     └─ TextButton "BuyButton"
-- =============================================================================

-- ─── Services ────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ─── Remote Events ───────────────────────────────────────────────────────────
-- Expects a RemoteEvent named "PurchaseItem" inside ReplicatedStorage > Remotes
local Remotes      = ReplicatedStorage:WaitForChild("Remotes", 10)
local PurchaseItem = Remotes and Remotes:WaitForChild("PurchaseItem", 10)

if not PurchaseItem then
    warn("[ShopUI] RemoteEvent 'PurchaseItem' not found – purchases will not work.")
end

-- ─── Player & GUI refs ────────────────────────────────────────────────────────
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local shopGui   = playerGui:WaitForChild("ShopGui")
local mainFrame = shopGui:WaitForChild("MainFrame")

-- ── Tab buttons ──────────────────────────────────────────────────────────────
local tabBar      = mainFrame:WaitForChild("TabBar")
local workersTab  = tabBar:WaitForChild("WorkersTab")
local machinesTab = tabBar:WaitForChild("MachinesTab")
local toolsTab    = tabBar:WaitForChild("ToolsTab")

-- ── Content frames ────────────────────────────────────────────────────────────
local workersFrame  = mainFrame:WaitForChild("WorkersFrame")
local machinesFrame = mainFrame:WaitForChild("MachinesFrame")
local toolsFrame    = mainFrame:WaitForChild("ToolsFrame")

-- ─── Item Catalog ─────────────────────────────────────────────────────────────
-- This dictionary drives the entire shop UI.
-- Add / remove entries here to update the shop without touching UI code.
--
-- Structure:
--   [itemName] = {
--       Cost      = number,   -- purchase price in Cash
--       Type      = string,   -- "Worker" | "Machine" | "Tool"
--       Desc      = string,   -- short description shown in the button (optional)
--   }
local ITEM_CATALOG = {
    -- ── Workers ──────────────────────────────────────────────────────────
    ["Miner"]      = { Cost = 50,   Type = "Worker", Desc = "Mines sand automatically." },
    ["Sorter"]     = { Cost = 120,  Type = "Worker", Desc = "Sorts items on the belt."  },

    -- ── Machines ─────────────────────────────────────────────────────────
    ["Furnace"]    = { Cost = 100,  Type = "Machine", Desc = "Smelts sand into cash."   },
    ["Crusher"]    = { Cost = 250,  Type = "Machine", Desc = "Doubles sand output."     },
    ["Conveyor"]   = { Cost = 30,   Type = "Machine", Desc = "Moves items along belt."  },

    -- ── Tools ────────────────────────────────────────────────────────────
    ["Wrench"]     = { Cost = 75,   Type = "Tool",    Desc = "Upgrades machines."       },
    ["DeleteTool"] = { Cost = 0,    Type = "Tool",    Desc = "Sell / remove machines."  },
}

-- Map category type strings → their content Frame
local CATEGORY_FRAMES = {
    Worker  = workersFrame,
    Machine = machinesFrame,
    Tool    = toolsFrame,
}

-- ─── Tab Visuals ─────────────────────────────────────────────────────────────
-- Colors used to highlight the active / inactive tab
local ACTIVE_TAB_COLOR   = Color3.fromRGB(60, 120, 200)
local INACTIVE_TAB_COLOR = Color3.fromRGB(40,  40,  40)
local ACTIVE_TEXT_COLOR  = Color3.fromRGB(255, 255, 255)
local INACTIVE_TEXT_COLOR = Color3.fromRGB(180, 180, 180)

-- ─── Private Functions ────────────────────────────────────────────────────────

--- Hide all content frames and show only the requested one.
-- @param targetFrame Frame  The frame to make visible
local function switchTab(targetFrame)
    local allFrames = { workersFrame, machinesFrame, toolsFrame }
    for _, frame in ipairs(allFrames) do
        frame.Visible = (frame == targetFrame)
    end
end

--- Update the visual state (colour) of all tab buttons.
-- @param activeButton TextButton  The button that was just clicked
local function highlightActiveTab(activeButton)
    local allTabs = { workersTab, machinesTab, toolsTab }
    for _, btn in ipairs(allTabs) do
        local isActive = (btn == activeButton)
        btn.BackgroundColor3 = isActive and ACTIVE_TAB_COLOR   or INACTIVE_TAB_COLOR
        btn.TextColor3       = isActive and ACTIVE_TEXT_COLOR  or INACTIVE_TEXT_COLOR
        -- Optional: bold text for active tab
        btn.TextStrokeTransparency = isActive and 0.5 or 1
    end
end

--- Dynamically create a shop button inside a ScrollingFrame for one item.
-- Uses the "ItemTemplate" button as a structural template (Visible = false).
--
-- @param list      ScrollingFrame  The scrolling list to add the button to
-- @param itemName  string          The catalog key (e.g. "Furnace")
-- @param data      table           The catalog entry { Cost, Type, Desc }
local function createItemButton(list, itemName, data)
    -- Locate the invisible template inside this list
    local template = list:FindFirstChild("ItemTemplate")
    if not template then
        warn(("[ShopUI] 'ItemTemplate' not found in %s"):format(list:GetFullName()))
        return
    end

    -- Clone the template and make it visible
    local btn       = template:Clone()
    btn.Name        = itemName
    btn.Visible     = true
    btn.Parent      = list

    -- Populate the labels (adjust child names to match your actual UI)
    local nameLabel = btn:FindFirstChild("NameLabel")
    local costLabel = btn:FindFirstChild("CostLabel")
    local descLabel = btn:FindFirstChild("DescLabel")   -- optional

    if nameLabel then nameLabel.Text = itemName end
    if costLabel then costLabel.Text = ("$%d"):format(data.Cost) end
    if descLabel then descLabel.Text = data.Desc or "" end

    -- ── Buy button ────────────────────────────────────────────────────────
    local buyButton = btn:FindFirstChild("BuyButton")
    if buyButton then
        buyButton.MouseButton1Click:Connect(function()
            -- Fire the server with the item name
            if PurchaseItem then
                PurchaseItem:FireServer(itemName)
                -- Provide immediate visual feedback
                buyButton.Text = "..."
                task.delay(1.5, function()
                    if buyButton and buyButton.Parent then
                        buyButton.Text = "Buy"
                    end
                end)
            else
                warn("[ShopUI] Cannot fire PurchaseItem – RemoteEvent missing.")
            end
        end)
    end

    -- ── Auto-resize the ScrollingFrame's canvas to fit all buttons ────────
    -- CanvasSize.Y = number of items × (button height + padding)
    local BUTTON_HEIGHT = btn.Size.Y.Offset  -- read from template
    local PADDING       = 5
    local itemCount     = 0
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") and child.Visible and child.Name ~= "ItemTemplate" then
            itemCount = itemCount + 1
        end
    end
    list.CanvasSize = UDim2.new(0, 0, 0, itemCount * (BUTTON_HEIGHT + PADDING))
end

--- Populate ALL three ScrollingFrames from the ITEM_CATALOG dictionary.
local function populateShop()
    for itemName, data in pairs(ITEM_CATALOG) do
        -- Map to the correct frame's internal ScrollingFrame
        local parentFrame = CATEGORY_FRAMES[data.Type]
        if parentFrame then
            local list = parentFrame:FindFirstChild("List")
            if list then
                createItemButton(list, itemName, data)
            else
                warn(("[ShopUI] No 'List' ScrollingFrame found in %s"):format(parentFrame.Name))
            end
        else
            warn(("[ShopUI] Unknown item Type '%s' for item '%s'"):format(
                tostring(data.Type), itemName))
        end
    end
end

-- ─── Tab Button Connections ───────────────────────────────────────────────────

workersTab.MouseButton1Click:Connect(function()
    switchTab(workersFrame)
    highlightActiveTab(workersTab)
end)

machinesTab.MouseButton1Click:Connect(function()
    switchTab(machinesFrame)
    highlightActiveTab(machinesTab)
end)

toolsTab.MouseButton1Click:Connect(function()
    switchTab(toolsFrame)
    highlightActiveTab(toolsTab)
end)

-- ─── Initialise ───────────────────────────────────────────────────────────────

-- Default to the Machines tab on open
switchTab(machinesFrame)
highlightActiveTab(machinesTab)

-- Build all item buttons from the catalog
populateShop()

print("[ShopUI] Shop initialised successfully.")
