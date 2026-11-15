-- Comodidad: pequeñas automatizaciones, cada una con su interruptor en la
-- página General.
--   - Botín rápido: con el botín automático, recoge todo de golpe.
--   - Reparación automática al abrir un vendedor que repara (con el dinero
--     de la hermandad si lo eliges y el juego lo permite).
--   - Vender la basura (objetos grises) al abrir un vendedor. Si está
--     Blazzito_Bags, el interruptor es el mismo que el suyo (una sola venta).
local _, ns = ...

local Q = ns.NewModule("QoL", "Comodidad", {
    fastLoot = true, autoRepair = true, guildRepair = true, sellJunk = true, report = true,
})
ns.QoL = Q

local Readable = ns.Media.Readable

local Money = ns.Media.Money

---------------------------------------------------------------------------
-- Botín rápido
---------------------------------------------------------------------------
local function AutoLootOn()
    local on = GetCVarBool and GetCVarBool("autoLootDefault")
    local toggled = IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE")
    return (on and true or false) ~= (toggled and true or false)
end

local lastLoot = 0
function Q.FastLoot()
    if not (Q.active and Q.db.fastLoot) or not AutoLootOn() then return end
    local now = GetTime and GetTime() or 0
    if now - lastLoot < 0.3 then return end
    lastLoot = now
    local count = Readable(GetNumLootItems and GetNumLootItems()) or 0
    for slot = count, 1, -1 do LootSlot(slot) end
end

-- Al encender el botín rápido, se enciende también el botín automático del juego.
function Q.SetFastLoot(on)
    Q.db.fastLoot = on
    if on and SetCVar and GetCVarBool and not GetCVarBool("autoLootDefault") then SetCVar("autoLootDefault", "1") end
end

---------------------------------------------------------------------------
-- Reparación automática
---------------------------------------------------------------------------
function Q.CanGuildRepair()
    return type(CanGuildBankRepair) == "function" and IsInGuild and IsInGuild() and CanGuildBankRepair() and true or false
end

function Q.Repair()
    if not (Q.active and Q.db.autoRepair) then return end
    if not (CanMerchantRepair and CanMerchantRepair()) then return end
    local cost, can = GetRepairAllCost()
    cost = Readable(cost)
    if not can or type(cost) ~= "number" or cost <= 0 then return end
    if Q.db.guildRepair and Q.CanGuildRepair() then
        local funds = GetGuildBankWithdrawMoney and Readable(GetGuildBankWithdrawMoney())
        if type(funds) == "number" and (funds == -1 or funds >= cost) then
            RepairAllItems(true)
            if Q.db.report then ns.Print("equipo reparado con el dinero de la hermandad: %s.", Money(cost)) end
            return
        end
    end
    if GetMoney() >= cost then
        RepairAllItems()
        if Q.db.report then ns.Print("equipo reparado por %s.", Money(cost)) end
    elseif Q.db.report then
        ns.Print("no te alcanza para reparar todo (%s).", Money(cost))
    end
end

---------------------------------------------------------------------------
-- Vender la basura
---------------------------------------------------------------------------
local function Bags()
    local bags = ns.modules.Bags
    return bags and bags.active and bags.db and bags.SellJunk and bags or nil
end

-- El interruptor es uno solo: el de Blazzito_Bags si está, o el nuestro.
function Q.GetSellJunk()
    local bags = Bags()
    if bags then return bags.db.autoSellJunk and true or false end
    return Q.db.sellJunk
end
function Q.SetSellJunk(on)
    Q.db.sellJunk = on
    local bags = Bags()
    if bags then bags.db.autoSellJunk = on end
end

local merchantOpen = false
function Q.SellJunk()
    if not (Q.active and Q.db.sellJunk) or Bags() then return end   -- con Bags, vende Bags
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.UseContainerItem) then return end
    local list = {}
    for bag = 0, 4 do
        local slots = Readable(C_Container.GetContainerNumSlots(bag)) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local quality = info and Readable(info.quality)
            if quality == 0 and not info.hasNoValue and not info.isLocked then
                list[#list + 1] = { bag = bag, slot = slot, link = info.hyperlink }
            end
        end
    end
    if #list == 0 then return end
    local sold = 0
    local function Next(i)
        if not merchantOpen then return end
        local item = list[i]
        if not item then
            if Q.db.report then ns.Print(sold == 1 and "basura vendida: %d objeto." or "basura vendida: %d objetos.", sold) end
            return
        end
        local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
        if info and info.hyperlink == item.link then
            C_Container.UseContainerItem(item.bag, item.slot)
            sold = sold + 1
        end
        C_Timer.After(0.2, function() Next(i + 1) end)
    end
    Next(1)
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
ns.On("LOOT_READY", function() Q.FastLoot() end)
ns.On("MERCHANT_SHOW", function()
    merchantOpen = true
    if not Q.active then return end
    Q.Repair()
    Q.SellJunk()
end)
ns.On("MERCHANT_CLOSED", function() merchantOpen = false end)

function Q:OnEnable() end

---------------------------------------------------------------------------
-- Tarjeta en la página General
---------------------------------------------------------------------------
if ns.Config and ns.Config.AddGeneralCard then
    ns.Config.AddGeneralCard(function(L, content)
        local W = ns.Widgets
        local col = L.innerColumn
        local db = Q.db
        local function on() return Q.db.enabled end
        L:Card("Comodidad")
        L:Row(W.Toggle(content, col, "Botín rápido (recoge todo de golpe)", function() return db.fastLoot end, function(v)
                  Q.SetFastLoot(v)
                  L:RefreshStates()
              end),
              W.Toggle(content, col, "Vender la basura al abrir un vendedor", Q.GetSellJunk, function(v)
                  Q.SetSellJunk(v)
                  L:RefreshStates()
              end), on, on)
        L:Row(W.Toggle(content, col, "Reparar el equipo al abrir un vendedor", function() return db.autoRepair end, function(v)
                  db.autoRepair = v
                  L:RefreshStates()
              end),
              W.Toggle(content, col, "Reparar con el dinero de la hermandad si se puede", function() return db.guildRepair end, function(v)
                  db.guildRepair = v
              end), on, function() return on() and db.autoRepair end)
        L:Row(W.Toggle(content, col, "Avisar en el chat de lo reparado y lo vendido", function() return db.report end, function(v)
                  db.report = v
              end), nil, on)
        L:Note("El botín rápido necesita el botín automático del juego: al encenderlo se activa solo (con la tecla de alternar botín, normalmente Mayús, se recoge a mano como siempre). La basura son los objetos grises; si tienes Blazzito_Bags, este interruptor es el mismo que el suyo, así que nunca se vende dos veces.")
        L:EndCard()
    end)
end
