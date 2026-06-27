local INTERACT_RANGE = 2.0

CreateThread(function()
    while true do
        Wait(500)

        if not OxInvState.open then
            local coords = GetEntityCoords(PlayerPedId())
            local nearestShop, nearestDist

            for name, shop in pairs(Shops) do
                for _, loc in ipairs(shop.locations) do
                    local dist = #(coords - vector3(loc.x, loc.y, loc.z))
                    if dist <= INTERACT_RANGE and (not nearestDist or dist < nearestDist) then
                        nearestShop, nearestDist = name, dist
                    end
                end
            end

            if nearestShop then
                local shop = Shops[nearestShop]
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(('[E] Open %s'):format(shop.label))
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustReleased(0, 38) then
                    OxInvOpen('shop', nearestShop)
                end
            end
        end
    end
end)
