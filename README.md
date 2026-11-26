# StreakKeeper — a "Set It and Forget It" check-in automation

**Reactive Omni Buildathon · Track: Set It and Forget It**

A daily check-in habit tracker whose journal keeps itself. A user checks in
on Base Sepolia; a reactive contract on the Reactive Lasna testnet notices
the check-in event on its own and orders a callback; the callback journals
the check-in — count, timestamp, streak — on a ledger back on Base Sepolia.
No keeper, no cron job, no polling loop, nobody pressing buttons: deploy
the three contracts, fund them once, and the automation runs itself.

## Why this fits "Set It and Forget It"

The track asks: *is this something you'd actually leave running?* Habit and
streak tracking is exactly the kind of small personal automation people
abandon when it needs babysitting. Here the "set it" is one deployment and
one `setRecipient` call. After that, every check-in is journaled
cross-chain automatically — the Reactive Network does the watching, so
there is no server to keep alive and no bot wallet to babysit.

## The loop

```
 Base Sepolia                     Lasna (Reactive)              Base Sepolia
┌────────────┐  CheckedIn event  ┌─────────────────┐  callback  ┌──────────────┐
│  CheckIn   │ ────────────────▶ │ StreakReactive  │ ─────────▶ │ StreakLedger │
│  (origin)  │                   │ react() fires,  │  via proxy │ counts it,   │
└────────────┘                   │ requests call   │            │ stamps it,   │
                                 └─────────────────┘            │ tracks streak│
                                                                └──────────────┘
```

1. **CheckIn** (`src/CheckIn.sol`) — users call `checkIn()` at most once
   per UTC day. It maintains streaks (consecutive days), best streaks, and
   emits `CheckedIn(address indexed user, uint256 streak, uint256 timestamp)`.
   Day boundaries use timestamps, not block numbers (Base Sepolia guidance:
   200 ms blocks).
2. **StreakReactive** (`src/StreakReactive.sol`) — deployed on Lasna,
   subscribed in its constructor to the `CheckedIn` topic of the origin
   contract. Each matching log triggers `react()` (system-contract only),
   which decodes the user and streak, counts the reaction on Lasna, and
   requests a V1.0 callback to the ledger with a 1,000,000 gas limit.
3. **StreakLedger** (`src/StreakLedger.sol`) — the journal. Its
   `recordCheckIn` can only be called by the Base Sepolia callback proxy,
   and only when the sender address the network injects into the payload is
   our reactive contract. It increments `executionCount`, records
   `lastExecutionAt` / `lastOriginTimestamp` / `lastUser`, mirrors streaks,
   and emits `MilestoneReached` whenever a streak hits a whole week.

## Security model

- `react()` is `onlySystem`: only the Reactive system contract
  (`0x8888888888888888888888888888888888888888`) can deliver logs.
- Callbacks are authenticated twice: caller == callback proxy, and the
  injected first payload argument == the authorized reactive contract.
  The first payload argument is an `address(0)` placeholder that the
  network overwrites with the requesting reactive contract's address.
- Both billed contracts implement the payer pattern: the system contract /
  callback proxy collects via `pay()`, which only it can call, drawing on
  the contract's own balance. `coverDebt()` is exposed so anyone can
  restart a funded contract that slipped into debt.
- Non-matching logs fall through in `react()` instead of reverting —
  a reverting reaction is still billed by the network.

## Repository layout

All Solidity in this repository was written for this buildathon entry,
including the minimal Reactive Omni base layer under `src/reactive/`
(interfaces `IPayable`, `IPayer`, `IReactive`, `ISystemContract` and bases
`AbstractPayer`, `AbstractReactive`, `AbstractCallback`), implemented from
the public Omni specification at dev.reactive.network.

```
src/
  CheckIn.sol          origin contract (Base Sepolia)
  StreakReactive.sol   reactive contract (Lasna)
  StreakLedger.sol     callback contract (Base Sepolia)
  reactive/            minimal Omni interfaces + base contracts

demo.sh                live demo / status walkthrough (read-only)
```

## Networks

| Role | Chain | Chain ID | RPC |
|---|---|---|---|
| Origin + destination | Base Sepolia | 84532 | https://sepolia.base.org |
| Reactive | Lasna testnet | 5318007 | https://lasna-rpc.rnk.dev/ |

Base Sepolia callback proxy: `0xa6eA49Ed671B8a4dfCDd34E36b7a75Ac79B8A5a6`

## Deployment (this entry, 2026-11-23)

Deployer / test wallet: `0x56E533CAdFba85B7566589e687c2287f619B4e25`

| Contract | Chain | Address | Deploy tx |
|---|---|---|---|
| CheckIn | Base Sepolia | `0xA7366fbE9e0e65640B2D3188Fd80bE6699bEE28C` | `0xfb056d2f078f985e58c83fe0ef2a6d4de886ceca120d53974cbac9a735c79014` |
| StreakReactive | Lasna | `0x87Cd4e03f8ff04aBA0714ca7ef302c6a54D2cAB3` | `0x8c4651934ac275b22154f205327828323f5a7ee6d765c7b280214eed0bd864d5` |
| StreakLedger | Base Sepolia | `0x3252CA5ee130e13040D30fAE9953bf88211f650c` | `0xa6049f1a56a75542b080db80269c87b63f3d35aaa17d19daa2d005ca9f5873b3` |

Funding at deployment: StreakReactive 0.3 lREACT, StreakLedger 0.1 ETH.
Wiring: `setRecipient(ledger)` on Lasna, tx
`0x964bcdf339e9a30f619db4b8ea3568d9fce126a227ca94873395fa2c93593735`.

### Verified end-to-end run

- Trigger: `checkIn()` on Base Sepolia, tx
  `0xa3c45fb794050c967d6061f7fdc91870b0ee31ba1104ac50b7c314eedb0ee220`
  (block 62242570) — `CheckedIn` emitted, `totalCheckIns` 0 → 1.
- Reaction (Lasna): reactive tx
  `0x8e02cd1996a30a2a2ccf804876b7ab3fa18ba0ba927b1194227280806416713e`
  (block 8992777) — `reactions` 0 → 1 within ~15 seconds; the `Reacted`
  log carries streak 1, the exact origin timestamp, and the origin tx
  hash. The same transaction emitted the system contract's
  `CallbackRequest` with chain 84532, this contract as sender, the ledger
  as recipient, gas limit 1,000,000, and a well-formed payload (selector
  `0xa7a0713f`).
- Destination correctness: an `eth_call` simulation of `recordCheckIn`
  from the callback proxy's address succeeds; from any other address it
  reverts `NotAuthorized`. Both auth guards verified live.
- Callback delivery: the request is registered with the network and both
  contracts are funded (balances **and** `depositTo` reserves on both
  sides, debt 0 everywhere). Final delivery by the Lasna→Base Sepolia
  testnet relay was still pending at the time of writing — see
  "Loop verification" in `../SETUP.md` for the full evidence trail and
  the delivery tx hash once it lands.

### Second run — 26 Nov 2026 (finalization recheck)

- Recheck at ~10:15 WIB, ~81 hours after the first request: `getCallbacks`
  for the first reactive tx still `[]`, `executionCount` still 0 — the
  relay had not delivered, with debt 0 and reserves funded on both sides
  (reactive 0.1 lREACT, ledger 0.05 ETH), so no documented blocker
  applies on our side.
- Fresh check-in fired the same morning (new UTC day, streak restarts at 1
  after the 3-day gap): origin tx
  `0x47af05efa6032f2240c7c143f029392719dcbd0c0c2104d10d163d2e172bef41`
  (block 63706095) → `CheckedIn` emitted, `totalCheckIns` 1 → 2.
- Reaction (Lasna): reactive tx
  `0xaa50ea2962fc47bc98df37df96e5d23bc9f045df1680c487de4e752ed082560f`
  (block 9266254) — `reactions` 1 → 2, `Reacted` log carries streak 1,
  the exact origin timestamp, and the origin tx hash; a second
  `CallbackRequest` is registered with the network.
- Callback delivery for the second request is being watched (polling
  `executionCount` + `getCallbacks` every 60 s). **Status: the final
  destination hop is still pending at the time of this README update.**
  Everything up to the `CallbackRequest` is proven on-chain twice over;
  the outstanding hop is the Lasna testnet relay's delivery to Base
  Sepolia, which is outside these contracts' control. If it lands, the
  delivery tx hash will be recorded here and in the DoraHacks submission.

## Demo video

`streakkeeper-demo.mp4` (2m42s, text-only, no voice narration) walks through
the loop with the real on-chain evidence: the origin check-in tx, the
Lasna reaction tx, and the honest callback status. Frames are generated
from the live `demo.sh` output by `../make-demo-video.py` in the workspace.
Run `./demo.sh` yourself to reproduce every number shown.

```bash
forge build

# 1. Origin on Base Sepolia
forge create src/CheckIn.sol:CheckIn --broadcast \
  --rpc-url base_sepolia --private-key $KEY

# 2. Reactive on Lasna (fund it; args: origin chain, origin contract,
#    CheckedIn topic0, destination chain)
forge create src/StreakReactive.sol:StreakReactive --broadcast \
  --rpc-url lasna --private-key $KEY --value 0.3ether \
  --constructor-args 84532 <CHECKIN_ADDR> \
    0x621d62c6c0c4a0c35e883c6b27ad50ecc3093f08bfaf8aa5f58127d351feeb21 84532

# 3. Ledger on Base Sepolia (args: callback proxy, reactive contract)
forge create src/StreakLedger.sol:StreakLedger --broadcast \
  --rpc-url base_sepolia --private-key $KEY --value 0.1ether \
  --constructor-args 0xa6eA49Ed671B8a4dfCDd34E36b7a75Ac79B8A5a6 <REACTIVE_ADDR>

# 4. Point the reactive contract at the ledger
cast send <REACTIVE_ADDR> 'setRecipient(address)' <LEDGER_ADDR> \
  --rpc-url https://lasna-rpc.rnk.dev/ --private-key $KEY

# 5. Use it: check in, then watch the ledger count itself
cast send <CHECKIN_ADDR> 'checkIn()' --rpc-url https://sepolia.base.org --private-key $KEY
cast call <LEDGER_ADDR> 'executionCount()(uint256)' --rpc-url https://sepolia.base.org
```

Note: Foundry 1.9 dry-runs `forge create` unless `--broadcast` is passed.
