# pv-govtablet — Government Tablet System

This is not just a staff lookup menu — it's a financial oversight system
that changes how crime has to work on your server. Every dollar that moves
through a player's bank or crypto account is watched in real time. If
Jimmy is unemployed but is suddenly driving a $1.3 million supercar, has a
business he can't explain, or just deposited $900,000 with no paycheck or
sale behind it, the tablet already knows before staff even go looking —
the **High Risk Payments** tab flags it the instant the money moves, with
the exact amount, account, reason string and timestamp attached.

That means money can no longer just disappear into a clean bank balance.
A bank robbery, a drug deal, an illegal chip-dumping scheme through a
front business — the second the cash lands or gets spent on something
big, it's on the radar. The Tax Agency, Government and DOJ can trace it
straight to the account, freeze it, seize it, and tie it to a criminal
record, all from the same tablet. Players who want to launder money now
have to actually launder it — spread it out, route it through a legitimate
business, stay under the thresholds — instead of just walking up to an ATM.

It cuts both ways: government and judicial roles get a real, provable
paper trail to act on (and judges can require approval before a seizure
goes through, so it can't be abused), while criminals who play it smart —
small amounts, real cover stories, patience — can still stay under the
radar. It raises the skill ceiling on crime instead of removing it.

Built on QBCore, it also covers the more everyday staff workflows: citizen
lookup, financial/vehicle/property management, business oversight and
criminal records.

Every action is validated and re-checked **server side**. The NUI only
ever hides/shows buttons for convenience — it has no authority of its own.

## Features

- Citizen search by name, citizen ID, phone number or plate
- Full profile view: identity, finances, properties, vehicles, criminal record
- Automatic citizen photo capture on first login (optional, via screenshot-basic)
- Bank account freeze / unfreeze / hide / reveal / seizure
- Vehicle seizure (paperwork order, resolved by police in the field), impound and release
- Property seizure and restoration (fully reversible)
- Criminal record viewing + adding convictions
- Judge approval queue for seizures (configurable)
- **High Risk Payments** tab — large vehicle purchases and unexplained bank/crypto
  deposits are flagged automatically the instant the money moves, with full
  what/when/how detail, and pushed live to every online staff member who can see them
- **Businesses** tab — staff roster, grades, pay and live account balance for
  every configured business, with deposit/withdrawal history and a direct
  link to that business's bank account
- **Account Lookup** tab — search any citizen or business account number to
  see its complete transaction history
- Full audit log, with optional Discord webhook mirroring
- Config-driven job/grade permission matrix
- Bridge layer so it talks to your housing/garage/banking/business resources
  without hard dependencies, with everything synced live to the database so
  every staff member sees the same state instantly

## Requirements

- [qb-core](https://github.com/qbcore-framework/qb-core)
- [oxmysql](https://github.com/overextended/oxmysql)
- MySQL 5.7+ / MariaDB 10.2+ (for `JSON_EXTRACT`/`JSON_UNQUOTE` used in search)
- [screenshot-basic](https://github.com/citizenfx/screenshot-basic) — optional,
  only needed for automatic citizen photo capture (see below)

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

**Seize** and **impound** are deliberately different actions:

- **Impound** is immediate — it sets the `state` column to `2` (impound),
  the same value your garage script already uses to keep impounded
  vehicles out of the normal spawn list. No rows are deleted.
- **Seize** is a paperwork order, not a physical one. It only flags the
  vehicle in `gt_vehicle_seizures` with a reason (e.g. "Not paying taxes",
  "Purchased with criminal money") — the car stays exactly where it was,
  still drivable/in the owner's garage, until police actually find it.
  Your police/MDT resource should check the flag whenever an officer runs
  a plate, and resolve it once the vehicle is physically impounded:

  ```lua
  -- when an officer runs a plate, e.g. in your ALPR/MDT lookup
  local isSeized, reason = exports['pv-govtablet']:IsVehicleSeized(plate)
  if isSeized then
      TriggerClientEvent('QBCore:Notify', src, ('This vehicle is flagged for seizure: %s'):format(reason), 'error')
  end

  -- once the officer has physically impounded the flagged vehicle
  exports['pv-govtablet']:ResolveVehicleSeizure(plate, officerName)
  ```

  `ResolveVehicleSeizure` puts the vehicle into impound (`state = 2`) and
  marks the seizure as fulfilled, exactly as if staff had used the
  tablet's direct Impound action.

### Automatic citizen photos

By default, staff have to paste a photo URL into a citizen's profile by
hand. If you run [screenshot-basic](https://github.com/citizenfx/screenshot-basic),
the tablet can instead capture a photo of a citizen's character automatically
the first time they load in, so most profiles already have a picture before
staff ever open the tablet:

```lua
Config.AutoPhoto = {
    Enabled          = true,             -- master switch
    Resource         = 'screenshot-basic',
    Webhook          = '',               -- Discord webhook screenshot-basic uploads to (required)
    Delay            = 2500,             -- ms to wait after spawn before capturing, so the ped/clothing is fully loaded
    RetakeEveryLogin = false,            -- if true, re-captures every login instead of only when no photo exists yet
}
```

Set `Config.AutoPhoto.Webhook` to a Discord webhook URL to enable it — with
it left blank, or `screenshot-basic` not running, this feature silently does
nothing and staff can still set photos manually from the tablet. Captured
photos are written to `gt_citizen_photos` with `is_auto = 1`; manually-set
photos always use `is_auto = 0` and are never overwritten by an auto-capture
once set.

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

### High Risk Payments

Every bank/crypto change on a player's QBCore money object already flows
through `QBCore:Server:OnMoneyChange` — `server/sv_riskmonitor.lua` hooks
that single event, so nothing else needs to call into the tablet for this
to work. Every change is logged to that citizen's ledger automatically, and
screened in real time against `Config.HighRiskPayments`:

```lua
Config.HighRiskPayments = {
    Enabled          = true,
    DepositThreshold = 900000,  -- unexplained incoming deposit >= this amount gets flagged
    VehicleThreshold = 400000,  -- outgoing payment >= this amount tagged as a vehicle purchase gets flagged
    VehicleReasonKeywords = { 'vehicle', 'showroom', 'dealership' }, -- substrings of the `reason` your vehicle shop passes to RemoveMoney
    IgnoreReasonKeywords  = { 'paycheck', 'salary', 'gov-tablet' },  -- reasons that are NEVER flagged, however large
}
```

Adjust `VehicleReasonKeywords` to match whatever string your vehicle
shop/dealership resource passes as the `reason` argument when it calls
`Player.Functions.RemoveMoney`. Any large deposit whose reason isn't on the
`IgnoreReasonKeywords` list gets flagged regardless of where it actually came
from — this is what catches money of unknown origin (e.g. drug sales)
without needing to know what every illicit money-maker on your server looks
like.

Flags land in the **High Risk Payments** tab (gated behind the
`viewHighRisk` permission) showing the citizen, account number, amount,
category, full reason string and timestamp, and are pushed live via NUI to
every online staff member who can see them — no refresh needed. Staff can
mark a flag Reviewed or Dismiss it.

Other resources can also raise a flag explicitly, regardless of amount or
keywords:

```lua
exports['pv-govtablet']:FlagHighRiskTransaction(citizenid, 'manual', 50000, 'bank', 'Reported by qb-drugs: suspected laundering')
```

### Businesses

`Config.Businesses` maps `QBCore.Shared.Jobs` keys to a tablet-visible
business profile. Staff roster, grades and pay are read live from
`QBCore.Shared.Jobs` and the `players` table — nothing needs to be kept in
sync manually:

```lua
Config.Businesses = {
    ['mechanic']   = { label = 'Bennys Motorworks' },
    ['realestate'] = { label = 'Dynasty 8 Real Estate' },
    ['tax']        = { label = 'Tax Agency' },
}
```

The live balance shown is read from `Config.Bridge.Business`, which assumes
qb-management's default `management_funds` schema:

```lua
Config.Bridge.Business = {
    FundsTable  = 'management_funds',
    JobField    = 'job_name',
    AmountField = 'amount',
}
```

Adjust the table/column names if your society-money resource differs
(qb-banking job accounts, a custom boss-menu, etc). If the configured table
doesn't exist on your server, businesses simply show a $0 balance instead of
erroring.

Deposit/withdrawal history is **not** something QBCore tracks anywhere by
default for society accounts, so the tablet keeps its own ledger that only
fills in once your boss-menu/society script calls the
`RecordBusinessTransaction` export whenever money actually moves in or out:

```lua
exports['pv-govtablet']:RecordBusinessTransaction('mechanic', 'in', 2500, 'sale', 'Vehicle repair - Michael De Santa')
exports['pv-govtablet']:RecordBusinessTransaction('mechanic', 'out', 1200, 'payroll', 'Weekly payroll run')
```

Every business automatically gets a stable bank account number the first
time it's viewed — clicking a business in the **Businesses** tab shows that
account number and links straight through to its full transaction history
in **Account Lookup**.

### Account Lookup

Every citizen and every configured business has exactly one bank account
number, minted automatically the first time it's needed and stored in
`gt_bank_accounts`. The **Account Lookup** tab (gated behind the
`viewAccountLookup` permission) lets staff search any account number and see
the owner, live balance(s) and full transaction history — the same
underlying ledger (`gt_transactions`) that powers both citizen financial
history and the Businesses tab.

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
├── client/cl_photo.lua        -- automatic citizen photo capture (optional)
├── server/sv_main.lua         -- permissions, callbacks, orchestration
├── server/sv_logs.lua         -- audit logging + Discord webhook
├── server/sv_riskmonitor.lua  -- high-risk payment detection (OnMoneyChange hook)
├── bridge/sv_banking.lua      -- money/freeze integration
├── bridge/sv_housing.lua      -- houses/apartments integration
├── bridge/sv_garage.lua       -- vehicles integration
├── bridge/sv_police.lua       -- criminal records integration
├── bridge/sv_accounts.lua     -- canonical account registry + transaction ledger
├── bridge/sv_business.lua     -- business roster/balance integration
├── sql/install.sql
└── html/                      -- NUI (index.html, css/style.css, js/app.js)
```
