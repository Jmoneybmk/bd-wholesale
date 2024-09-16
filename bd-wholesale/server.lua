local QBCore = exports['qb-core']:GetCoreObject()

-- Helper Functions
local function CanPlayerSell(player)
    for _, job in ipairs(Config.SellJobRestrictions) do
        if player.PlayerData.job.name == job then
            return true
        end
    end
    return false
end

-- Database Functions
local function InitializeDatabase()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS npc_inventory (
            item VARCHAR(50) PRIMARY KEY,
            quantity INT NOT NULL DEFAULT 0,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]])
end

local function GetNPCItemQuantity(itemName, cb)
    MySQL.query('SELECT quantity FROM npc_inventory WHERE item = ?', {itemName}, function(result)
        cb(result and result[1] and result[1].quantity or 0)
    end)
end

local function UpdateNPCInventory(itemName, amount)
    MySQL.query('INSERT INTO npc_inventory (item, quantity) VALUES (?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + ?',
        {itemName, amount, amount},
        function(affectedRows)
            if affectedRows == 0 then
                print('Failed to update NPC inventory for item: ' .. itemName)
            end
        end
    )
end

local function InitializeNPCInventory()
    for itemName, _ in pairs(Config.Items) do
        MySQL.query('INSERT IGNORE INTO npc_inventory (item, quantity) VALUES (?, ?)',
            {itemName, 0},
            function(affectedRows)
                if affectedRows == 0 then
                    print('Failed to initialize NPC inventory for item: ' .. itemName)
                end
            end
        )
    end
end

-- Transaction Functions
local function BuyItem(source, itemName, amount, npcIndex)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local npcConfig = Config.BuyingNPCs[npcIndex]
    if not npcConfig then
        TriggerClientEvent('npc_distributor:notify', source, 'Invalid NPC', 'error')
        return
    end

    -- Check if the NPC sells this item
    local itemFound = false
    for _, npcItem in ipairs(npcConfig.items) do
        if npcItem == itemName then
            itemFound = true
            break
        end
    end

    if not itemFound then
        TriggerClientEvent('npc_distributor:notify', source, 'This NPC does not sell this item', 'error')
        return
    end

    local item = Config.Items[itemName]
    if not item then
        TriggerClientEvent('npc_distributor:notify', source, 'Invalid item', 'error')
        return
    end

    -- Check for required item
    if not Player.Functions.GetItemByName(npcConfig.requiredItem) then
        TriggerClientEvent('npc_distributor:notify', source, 'You need a ' .. npcConfig.requiredItem .. ' to buy from this NPC', 'error')
        return
    end

    GetNPCItemQuantity(itemName, function(npcQuantity)
        if npcQuantity < amount then
            TriggerClientEvent('npc_distributor:notify', source, 'Not enough stock', 'error')
            return
        end

        local price = item.buyPrice * amount
        if Player.PlayerData.money.cash < price then
            TriggerClientEvent('npc_distributor:notify', source, 'Not enough cash', 'error')
            return
        end

        if Player.Functions.RemoveMoney('cash', price) then
            local success = Player.Functions.AddItem(itemName, amount)
            if success then
                TriggerClientEvent('npc_distributor:notify', source, 'Bought ' .. amount .. ' ' .. item.label .. ' for $' .. price, 'success')
                UpdateNPCInventory(itemName, -amount)
            else
                Player.Functions.AddMoney('cash', price) -- Refund the money
                TriggerClientEvent('npc_distributor:notify', source, 'Failed to add item to inventory', 'error')
            end
        else
            TriggerClientEvent('npc_distributor:notify', source, 'Transaction failed', 'error')
        end
    end)
end

local function SellItem(source, itemName, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    if not CanPlayerSell(Player) then
TriggerClientEvent('npcdistributor:notify', source, 'You are not authorized to sell items', 'error')
        return
    end

    local item = Config.Items[itemName]
    if not item then
        TriggerClientEvent('npc_distributor:notify', source, 'Invalid item', 'error')
        return
    end

    if amount % Config.StackSize ~= 0 then
        TriggerClientEvent('npc_distributor:notify', source, 'You can only sell in stacks of ' .. Config.StackSize, 'error')
        return
    end

    local playerItem = Player.Functions.GetItemByName(itemName)
    if not playerItem or playerItem.amount < amount then
        TriggerClientEvent('npc_distributor:notify', source, 'Not enough items to sell', 'error')
        return
    end

    local stacks = amount / Config.StackSize
    local pricePerStack = math.random(item.sellRange.min, item.sellRange.max)
    local totalPrice = pricePerStack * stacks

    if Player.Functions.RemoveItem(itemName, amount) then
        Player.Functions.AddMoney('cash', totalPrice)
        TriggerClientEvent('npc_distributor:notify', source, 'Sold ' .. amount .. ' ' .. item.label .. ' for $' .. totalPrice, 'success')
        UpdateNPCInventory(itemName, amount)
    else
        TriggerClientEvent('npc_distributor:notify', source, 'Transaction failed', 'error')
    end
end

-- Event Handlers
RegisterNetEvent('npc_distributor:buyItem', function(itemName, amount, npcIndex)
    BuyItem(source, itemName, amount, npcIndex)
end)

RegisterNetEvent('npc_distributor:sellItem', function(itemName, amount)
    SellItem(source, itemName, amount)
end)

RegisterNetEvent('npc_distributor:getNPCInventory', function(npcIndex)
    local src = source
    MySQL.query('SELECT * FROM npc_inventory', {}, function(result)
        local inventory = {}
        for _, item in ipairs(result) do
            inventory[item.item] = item.quantity
        end
        TriggerClientEvent('npc_distributor:receiveNPCInventory', src, inventory, npcIndex)
    end)
end)

-- Admin Commands
QBCore.Commands.Add('checknpcinventory', 'Check NPC Distributor Inventory', {}, false, function(source, args)
    if QBCore.Functions.HasPermission(source, 'admin') then
        MySQL.query('SELECT * FROM npc_inventory', {}, function(result)
            for i = 1, #result do
                TriggerClientEvent('npc_distributor:notify', source, result[i].item .. ': ' .. result[i].quantity, 'primary')
            end
        end)
    else
        TriggerClientEvent('npc_distributor:notify', source, 'You do not have permission to use this command', 'error')
    end
end)

-- Initialization
CreateThread(function()
    InitializeDatabase()
    Wait(1000) -- Wait for database to initialize
    InitializeNPCInventory()
end)