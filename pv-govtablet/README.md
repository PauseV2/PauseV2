# pv-govtablet — Government Tablet System

A secure, QBCore-based tablet for high-authority jobs (Mayor, Tax Agency,
Government, DOJ, Judges) to look up citizens and manage their financial,
vehicle, property and criminal records.

Every action is validated and re-checked **server side**. The NUI only
ever hides/shows buttons for convenience — it has no authority of its own.

## Features

- Citizen search by name, citizen ID, phone number or plate
- Full profile view: identity, finances, properties, vehicles, criminal record
- Bank account freeze / unfreeze / hide / reveal / seizure
- Vehicle seizure, impound and release
- Property seizure and restoration (fully reversible)
- Criminal record viewing + adding convictions
- Judge approval queue for seizures (configurable)
- Full audit log, with optional Discord webhook mirroring
- Config-driven job/grade permission matrix
- Bridge layer so it talks to your housing/garage/police resources without
  hard dependencies

## Requirements

- [qb-core](https://github.com/qbcore-framework/qb-core)
- [oxmysql](https://github.com/overextended/oxmysql)
- MySQL 5.7+ / MariaDB 10.2+ (for `JSON_EXTRACT`/`JSON_UNQUOTE` used in search)

## Installation

1. Copy the `pv-govtablet` folder into your server's `resources` directory.
2. Import `sql/install.sql` into your database (phpMyAdmin, HeidiSQL, or
   `mysql -u user -p database < sql/install.sql`). It only creates new
   tables — nothing in qb-core, qb-houses or qb-garages is modified.
3. Add to your `server.cfg` **after** `qb-core` and `oxmysql`:
   ```
   ensure oxmysql
   ensure qb-core
   ensure pv-govtablet
   ```
4. (Optional) Add the tablet item to `qb-core/shared/items.lua`:
   ```lua
   ['gov_tablet'] = { name = 'gov_tablet', label = 'Government Tablet', weight = 500, type = 'item', image = 'gov_tablet.png', unique = true, useable = true, shouldClose = true, description = 'Secure government access terminal' },
   ```
   and give it to staff via your job's starting loadout, a shop, or
   `/giveitem` for testing. Drop the matching image into your inventory
   resource's `image` folder.
5. Open `config.lua` and adjust `Config.Jobs` to match your job names exactly
   (`QBCore.Shared.Jobs` keys), grades, and per-action permissions.
6. Set `Config.Webhook` if you want actions mirrored to Discord.

Open the tablet with `/govtablet` (configurable via `Config.Command`) or by
using the `gov_tablet` item, provided the player's job/grade is present in
`Config.Jobs`.

## Permissions

`config.lua` defines a job → permission matrix:

```lua
Config.Jobs = {
    ['mayor'] = {
        label = 'Mayor',
        minGrade = 0,
        permissions = { search = true, freeze = true, seizeFunds = true, ... }
    },
    ...
}
```

- `minGrade` is the minimum `PlayerData.job.grade.level` required.
- Every permission key maps 1:1 to a server-side check — adding a job here
  does nothing on its own unless the relevant permission flags are `true`.
- `approveSeizure` marks a role as a "judge" for the purposes of the seizure
  approval queue (see below).

All permission checks happen in `server/sv_main.lua` via `hasPermission()`.
The client/NUI cannot bypass this — even if someone edits the NUI JS or
fires events directly, the server re-validates the job, grade and specific
permission on every single request.

## Judge approval queue

When `Config.RequireJudgeApproval = true`, any staff member who lacks the
`approveSeizure` permission has their fund/vehicle/property seizure requests
queued in `gt_seizure_requests` instead of executed immediately. Online
judges (any job with `approveSeizure = true`) are notified and can
Approve/Deny from the **Approvals** tab. Approving runs the seizure exactly
as if the judge had performed it themselves, and is logged accordingly.

Set `Config.RequireJudgeApproval = false` to let any role with direct
seizure permissions act immediately.

## Integration guide

### Police / MDT systems

The tablet keeps its own canonical table, `gt_criminal_records`, so it has
no hard dependency on any specific MDT. Push records into it from your
existing MDT/booking system with the exported function:

```lua
exports['pv-govtablet']:AddCriminalRecord(citizenid, {
    officerName = ('%s %s'):format(Officer.PlayerData.charinfo.firstname, Officer.PlayerData.charinfo.lastname),
    officerCitizenId = Officer.PlayerData.citizenid,
    charges = 'Grand Theft Auto, Evading',
    fine = 15000,
    sentenceMonths = 8,
    status = 'served', -- active | served | warrant | fined | dismissed
    notes = 'Booked at Mission Row PD',
})
```

Call this wherever your MDT finalizes a booking/report (e.g. at the end of
`qb-policejob`'s report submission handler). Read access is exposed too:

```lua
local records = exports['pv-govtablet']:GetCriminalRecords(citizenid)
```

### Housing systems

`bridge/sv_housing.lua` reads ownership rows directly from your housing
resource's table (default: qb-houses' `player_houses`, columns `citizenid`
and `house`). If you run a different housing script:

1. Update `Config.Bridge.Housing` in `config.lua` with the correct table and
   column names.
2. The tablet doesn't know your house display names/locations/prices unless
   you populate the `gt_properties` catalogue table:
   ```sql
   INSERT INTO gt_properties (house, type, label, location, price)
   VALUES ('apt_downtown_1', 'apartment', 'Downtown Loft #1', 'Eclipse Towers, Downtown', 250000);
   ```
   Houses without a catalogue entry still show up (using the raw house key
   as the label) so nothing breaks if you skip this step.

Seizing a property **deletes** the ownership row from your housing table
(after snapshotting it) so the house becomes available again through your
normal housing resource; restoring re-inserts the exact original row.

### Garage / vehicle systems

`bridge/sv_garage.lua` reads/writes the `player_vehicles` table that ships
with qb-core and is used by qb-garages and most forks (qs-advancedgarages,
cd_garage, etc). If your garage script uses a different table/columns,
update `Config.Bridge.Garage`.

Seizing or impounding a vehicle simply sets its `state` column to `2`
(impound) — the same value your garage script already uses to keep
impounded vehicles out of the normal spawn list. No rows are deleted.

### Banking systems (preventing use of frozen accounts)

Freeze/hide state lives in `gt_account_freezes`, independent of whatever
banking script you use. Other resources should check this **before**
allowing a transaction:

```lua
-- e.g. inside qb-banking's deposit/withdraw/transfer handler
local frozen = exports['pv-govtablet']:IsAccountFrozen(Player.PlayerData.citizenid, 'bank')
if frozen then
    TriggerClientEvent('QBCore:Notify', src, 'This account has been frozen by the government.', 'error')
    return
end
```

Also exported: `IsAccountHidden(citizenid, accountType)` and
`GetBalances(citizenid)`.

## Security notes

- Every read/write callback re-validates the caller's job, grade, and the
  specific permission flag required for that action — never trust the NUI.
- All SQL is parameterized; nothing is string-concatenated from user input
  into a query value.
- Citizen IDs, plates and house keys are validated against strict
  whitelisted patterns before being used anywhere.
- A sliding-window rate limit (`Config.MaxActionsPerMinute`) and a search
  cooldown (`Config.SearchCooldown`) blunt event-spam/exploit attempts.
- Every action is written to `gt_logs` (staff name, job, action, target
  citizen, details, timestamp) and optionally mirrored to Discord.

## File structure

```
pv-govtablet/
├── fxmanifest.lua
├── config.lua
├── shared/sh_utils.lua        -- shared validation helpers
├── client/cl_main.lua         -- NUI open/close + generic NUI->server forwarder
├── server/sv_main.lua         -- permissions, callbacks, orchestration
├── server/sv_logs.lua         -- audit logging + Discord webhook
├── bridge/sv_banking.lua      -- money/freeze integration
├── bridge/sv_housing.lua      -- houses/apartments integration
├── bridge/sv_garage.lua       -- vehicles integration
├── bridge/sv_police.lua       -- criminal records integration
├── sql/install.sql
└── html/                      -- NUI (index.html, css/style.css, js/app.js)
```
