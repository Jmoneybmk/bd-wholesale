Config = {}

-- NPC Configuration
Config.SellingNPC = {
    model = 'a_m_m_farmer_01',
    location = vector4(234.04, 6587.63, 29.32, 60.56)
}

-- Job Restrictions
Config.SellJobRestrictions = {'farmer', 'vineyard'} -- Add all jobs that should be able to sell

-- General Blip Configuration
Config.Blip = {
    sprite = 477,
    color = 5,
    scale = 0.8,
    name = "Distributor"
}

-- Buying NPCs Configuration
Config.BuyingNPCs = {
    {
        model = 'a_m_m_business_01',
        location = vector4(226.55, 6599.87, 29.55, 153.86),
        items = {'ecola', 'sprunk'},
        requiredItem = 'sellers_permit',
        blip = {sprite = 478, color = 2, name = "Corn and Wheat Buyer"}
    },
    {
        model = 's_f_y_shop_mid',
        location = vector4(228.15, 6597.37, 29.56, 120.63),
        items = {'lemonade', 'lemonlimeslushie'},
        requiredItem = 'sellers_permit',
        blip = {sprite = 479, color = 3, name = "Fruit Buyer"}
    },
    -- Add more NPCs as needed
}

-- Items Configuration
Config.Items = {
    ['ecola'] = {
        label = 'E-Cola',
        sellRange = {min = 3, max = 8}, -- Price per stack
        buyPrice = 1
    },
    ['sprunk'] = {
        label = 'Sprunk',
        sellRange = {min = 3, max = 8}, -- Price per stack
        buyPrice = 1
    },
    ['lemonade'] = {
        label = 'Lemonade',
        sellRange = {min = 3, max = 8}, -- Price per stack
        buyPrice = 1
    },
    ['lemonlimeslushie'] = {
        label = 'Lemon Lime Slushie',
        sellRange = {min = 3, max = 8}, -- Price per stack
        buyPrice = 1
    },
    -- Add more items as needed following the structure:
    -- ['itemName'] = {                    -- This is for the item name. As well as the open curly bracket.
    -- label = 'Item Name'                 -- This is the label that the item will have.
    -- sellRange = {min = 10, max = 15},   -- This is the range the item will sell for.
    -- buyPrice = 20                       -- This is the fixed amount the item will be bought for.
    -- }                                   -- Make sure to add the closing curly bracket.
}

Config.StackSize = 10 -- Define the stack size for selling