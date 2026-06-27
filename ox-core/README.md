# ox-core

OXBase core framework: player/character lifecycle, jobs, gangs, and money.

## Install

1. Drop this folder into your `resources` directory as `ox-core`.
2. Run `db.sql` against your server's database (creates `ox_players` and `ox_characters`).
3. In `server.cfg`, **before** `ensure ox-core`:
   ```
   ensure oxmysql
   ensure ox-core
   ```
4. Grant admin commands as needed:
   ```
   add_ace group.admin command.setjob allow
   add_ace group.admin command.addmoney allow
   ```

## Exports (server)

`GetPlayer(source)`, `GetPlayerByCitizenId(citizenid)`, `GetPlayers()`, `CreateCharacter(source, data)`,
`DeleteCharacter(source, citizenid)`, `AddMoney/RemoveMoney/SetMoney(source, account, amount, reason)`,
`GetMoney(source, account)`, `SetJob/SetGang(source, name, grade)`, `SetMetadata(source, key, value)`,
`RegisterHook(name, fn, priority)`.

## Exports (client)

`GetPlayerData()`, `IsCharacterLoaded()`.

## Hooks

Other resources can veto core actions without editing core:

```lua
exports['ox-core']:RegisterHook('beforeRemoveMoney', function(player, account, amount, reason)
    if account == 'bank' and amount > 100000 then
        return false, 'amount too large'
    end
end, 50)
```

Hook names available in v1: `beforeJobSet`, `beforeAddMoney`, `beforeRemoveMoney`, `canCreateCharacter`.

## Notes

This is v1 of the core only — multi-character select, jobs/gangs, money, state-bag sync, the
hook/middleware system, and the multiplexed callback system. Inventory, MDT, and other gameplay
resources are deliberately separate follow-up builds on top of this.
