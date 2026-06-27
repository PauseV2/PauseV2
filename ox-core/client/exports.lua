exports('GetPlayerData', function()
    return {
        citizenid = LocalPlayer.state.citizenid,
        job = LocalPlayer.state.job,
        gang = LocalPlayer.state.gang,
        money = OxClientData.money,
        metadata = OxClientData.metadata,
    }
end)

exports('IsCharacterLoaded', function()
    return LocalPlayer.state.citizenid ~= nil
end)
