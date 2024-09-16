local QBCore = exports['qb-core']:GetCoreObject()

-- Local Variables
local sellingNPC = nil
local buyingNPCs = {}

-- Debug function
local function DebugPrint(message)
    print("^2[BD-Wholesale Debug] ^7" .. message)
end

-- Helper Functions
local function CanPlayerSell(playerJob)
    for _, job in ipairs(Config.SellJobRestrictions) do
        if playerJob == job then
            return true
        end
    end
    return false
end

-- NPC and Blip Creation
local function CreateNPCAndBlip(npcConfig, isSelling)
    DebugPrint("Creating NPC: " .. npcConfig.model .. " at " .. json.encode(npcConfig.location))

    RequestModel(GetHashKey(npcConfig.model))
    while not HasModelLoaded(GetHashKey(npcConfig.model)) do
        Wait(1)
    end

    local npc = CreatePed(4, GetHashKey(npcConfig.model), npcConfig.location.x, npcConfig.location.y, npcConfig.location.z - 1, npcConfig.location.w, false, true)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)

    local blipConfig = isSelling and Config.Blip or npcConfig.blip
    if blipConfig then
        local blip = AddBlipForCoord(npcConfig.location.x, npcConfig.location.y, npcConfig.location.z)
        SetBlipSprite(blip, blipConfig.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, blipConfig.scale or 0.7)
        SetBlipColour(blip, blipConfig.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(blipConfig.name)
        EndTextCommandSetBlipName(blip)
    end

    if npc and DoesEntityExist(npc) then
        DebugPrint("NPC created successfully with handle: " .. npc)
        return npc
    else
        DebugPrint("Failed to create NPC")
        return nil
    end
end

-- Target Setup
local function SetupTarget()
    DebugPrint("Setting up targets")

    if sellingNPC and DoesEntityExist(sellingNPC) then
        DebugPrint("Setting up target for Selling NPC with handle: " .. sellingNPC)
        exports['qb-target']:AddTargetEntity(sellingNPC, {
            options = {
                {
                    type = "client",
                    event = "npc_distributor:openSellMenu",
                    icon = "fas fa-sell",
                    label = "Sell Items",
                    canInteract = function(entity)
                        DebugPrint("Checking interaction for Selling NPC")
                        local Player = QBCore.Functions.GetPlayerData()
                        local canSell = CanPlayerSell(Player.job.name)
                        DebugPrint("Can player sell in canInteract: " .. tostring(canSell))
                        return canSell
                    end
                },
            },
            distance = 2.5,
        })
        DebugPrint("Target set up for Selling NPC")
    else
        DebugPrint("Selling NPC does not exist, cannot set up target")
    end

    for i, npc in ipairs(buyingNPCs) do
        if npc and DoesEntityExist(npc) then
            exports['qb-target']:AddTargetEntity(npc, {
                options = {
                    {
                        type = "client",
                        event = "npc_distributor:openBuyMenu",
                        icon = "fas fa-shop",
                        label = "Buy Items",
                        npcIndex = i
                    },
                },
                distance = 2.5,
            })
            DebugPrint("Target set up for Buying NPC " .. i)
        else
            DebugPrint("Buying NPC " .. i .. " does not exist, cannot set up target")
        end
    end
end

-- Menu Functions
local function OpenBuyMenu(npcIndex)
    DebugPrint("Attempting to open buy menu for NPC " .. npcIndex)
    local Player = QBCore.Functions.GetPlayerData()
    local npcConfig = Config.BuyingNPCs[npcIndex]

    if not npcConfig then
        DebugPrint("NPC configuration not found for index " .. npcIndex)
        return
    end

    -- Check for required item
    local hasRequiredItem = QBCore.Functions.HasItem(npcConfig.requiredItem)
    if not hasRequiredItem then
        QBCore.Functions.Notify("You need a " .. npcConfig.requiredItem .. " to access this shop", "error")
        return
    end

    TriggerServerEvent('npc_distributor:getNPCInventory', npcIndex)
end

local function OpenSellMenu()
    DebugPrint("Attempting to open sell menu")
    local Player = QBCore.Functions.GetPlayerData()
    if not CanPlayerSell(Player.job.name) then
        QBCore.Functions.Notify("You are not authorized to sell items", "error")
        return
    end

    local options = {}
    for itemName, itemData in pairs(Config.Items) do
        table.insert(options, {
            title = itemData.label,
            description = 'Sell ' .. itemData.label .. ' (Stack of ' .. Config.StackSize .. ')',
            onSelect = function()
                local input = lib.inputDialog('Sell ' .. itemData.label, {
                    {type = 'number', label = 'Number of Stacks', min = 1, max = 10}
                })
                if input and input[1] then
                    local stacks = tonumber(input[1])
                    if stacks and stacks > 0 then
                        local amount = stacks * Config.StackSize
                        TriggerServerEvent('npc_distributor:sellItem', itemName, amount)
                    else
                        QBCore.Functions.Notify('Invalid amount', 'error')
                    end
                end
            end,
        })
    end

    lib.registerContext({
        id = 'sell_menu',
        title = 'Sell Items',
        options = options
    })

    lib.showContext('sell_menu')
end

-- Event Handlers
RegisterNetEvent('npc_distributor:openSellMenu')
AddEventHandler('npc_distributor:openSellMenu', function()
    DebugPrint("Sell menu event triggered")
    OpenSellMenu()
end)

RegisterNetEvent('npc_distributor:openBuyMenu')
AddEventHandler('npc_distributor:openBuyMenu', function(data)
    DebugPrint("Buy menu event triggered for NPC " .. tostring(data.npcIndex))
    OpenBuyMenu(data.npcIndex)
end)

RegisterNetEvent('npc_distributor:receiveNPCInventory')
AddEventHandler('npc_distributor:receiveNPCInventory', function(inventory, npcIndex)
    DebugPrint("Received inventory for NPC " .. npcIndex)
    local options = {}
    local npcConfig = Config.BuyingNPCs[npcIndex]

    for _, itemName in ipairs(npcConfig.items) do
        local itemData = Config.Items[itemName]
        local stock = inventory[itemName] or 0
        table.insert(options, {
            title = itemData.label,
            description = 'Buy ' .. itemData.label .. ' (Stock: ' .. stock .. ', Price: $' .. itemData.buyPrice .. ')',
            disabled = stock == 0,
            onSelect = function()
                local input = lib.inputDialog('Buy ' .. itemData.label, {
                    {type = 'number', label = 'Amount', min = 1, max = stock}
                })
                if input and input[1] then
                    local amount = tonumber(input[1])
                    if amount and amount > 0 then
                        TriggerServerEvent('npc_distributor:buyItem', itemName, amount, npcIndex)
                    else
                        QBCore.Functions.Notify('Invalid amount', 'error')
                    end
                end
            end,
        })
    end

    lib.registerContext({
        id = 'buy_menu',
        title = 'Buy Items',
        options = options
    })

    lib.showContext('buy_menu')
end)

RegisterNetEvent('npc_distributor:notify')
AddEventHandler('npc_distributor:notify', function(message, type)
    QBCore.Functions.Notify(message, type)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(job)
    DebugPrint("Player job updated to: " .. job.name)
    DebugPrint("Can player sell: " .. tostring(CanPlayerSell(job.name)))
end)

-- Initialization
CreateThread(function()
    DebugPrint("Initializing NPCs")

    if Config.SellingNPC then
        DebugPrint("Attempting to create Selling NPC")
        sellingNPC = CreateNPCAndBlip(Config.SellingNPC, true)
        if sellingNPC and DoesEntityExist(sellingNPC) then
            DebugPrint("Selling NPC created successfully with handle: " .. sellingNPC)
        else
            DebugPrint("Failed to create Selling NPC")
        end
    else
        DebugPrint("No Selling NPC configuration found")
    end

    if Config.BuyingNPCs then
        for i, npcConfig in ipairs(Config.BuyingNPCs) do
            DebugPrint("Attempting to create Buying NPC " .. i)
            local npc = CreateNPCAndBlip(npcConfig, false)
            if npc and DoesEntityExist(npc) then
                buyingNPCs[i] = npc
                DebugPrint("Buying NPC " .. i .. " created successfully with handle: " .. npc)
            else
                DebugPrint("Failed to create Buying NPC " .. i)
            end
        end
    else
        DebugPrint("No Buying NPCs configuration found")
    end

    Wait(1000)
    SetupTarget()

    -- Add this line to re-check target setup after a delay
    Wait(5000)
    SetupTarget()
end)

-- Command to check sell menu access
-- RegisterCommand("checksellmenu", function()
--     local Player = QBCore.Functions.GetPlayerData()
--     DebugPrint("Checking sell menu access for job: " .. Player.job.name)
--     if CanPlayerSell(Player.job.name) then
--         DebugPrint("Player can sell. Opening sell menu.")
--         OpenSellMenu()
--     else
--         DebugPrint("Player cannot sell with current job.")
--         QBCore.Functions.Notify("You are not authorized to sell items", "error")
--     end
-- end, false)

-- Command to force-check the NPC setup
RegisterCommand("checksellingnpc", function()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local npcCoords = GetEntityCoords(sellingNPC)
    local distance = #(playerCoords - npcCoords)

    DebugPrint("Distance to Selling NPC: " .. distance)
    DebugPrint("Selling NPC handle: " .. tostring(sellingNPC))
    DebugPrint("Selling NPC exists: " .. tostring(DoesEntityExist(sellingNPC)))

    local Player = QBCore.Functions.GetPlayerData()
    DebugPrint("Player job: " .. Player.job.name)
    DebugPrint("Can player sell: " .. tostring(CanPlayerSell(Player.job.name)))
end, false)

-- Command to force reset the NPC
RegisterCommand("resetsellingnpctarget", function()
    DebugPrint("Resetting Selling NPC target")
    exports['qb-target']:RemoveTargetEntity(sellingNPC, "Sell Items")
    Wait(1000)
    SetupTarget()
end, false)