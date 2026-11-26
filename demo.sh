#!/usr/bin/env bash
# StreakKeeper — live demo script (read-only, no keys needed).
#
# Walks through the full automation loop with on-chain evidence:
#   1. Origin check-in on Base Sepolia (CheckedIn event)
#   2. Reaction on Lasna (react() fired, CallbackRequest registered)
#   3. Callback journal on Base Sepolia (executionCount)
#
# Usage: ./demo.sh            (read-only status walkthrough)
#        ./demo.sh checkin    (also fires a fresh check-in; needs $KEY set
#                              to the deployer/test wallet private key)
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"

BASE=https://sepolia.base.org
LASNA=https://lasna-rpc.rnk.dev/
CHECKIN=0xA7366fbE9e0e65640B2D3188Fd80bE6699bEE28C
REACTIVE=0x87Cd4e03f8ff04aBA0714ca7ef302c6a54D2cAB3
LEDGER=0x3252CA5ee130e13040D30fAE9953bf88211f650c
SYSTEM=0x8888888888888888888888888888888888888888
USER=0x56E533CAdFba85B7566589e687c2287f619B4e25

say() { printf '\n==> %s\n' "$*"; }

say "1/4  Origin — CheckIn on Base Sepolia ($CHECKIN)"
echo "    total check-ins : $(cast call $CHECKIN 'totalCheckIns()(uint256)' --rpc-url $BASE)"
echo "    our streak      : $(cast call $CHECKIN 'streakOf(address)(uint256)' $USER --rpc-url $BASE)"
echo "    best streak     : $(cast call $CHECKIN 'bestStreakOf(address)(uint256)' $USER --rpc-url $BASE)"

if [ "${1:-}" = "checkin" ]; then
  [ -n "${KEY:-}" ] || { echo "set KEY to the test wallet private key first"; exit 1; }
  say "Firing a fresh check-in (once per UTC day)…"
  cast send $CHECKIN 'checkIn()' --rpc-url $BASE --private-key "$KEY"
  sleep 75
fi

say "2/4  Reactive — StreakReactive on Lasna ($REACTIVE)"
echo "    reactions       : $(cast call $REACTIVE 'reactions()(uint256)' --rpc-url $LASNA)"
echo "    last reaction   : $(cast call $REACTIVE 'lastReactionAt()(uint256)' --rpc-url $LASNA) (unix)"
echo "    balance         : $(cast call $REACTIVE 'balanceOf()(uint256)' --rpc-url $LASNA 2>/dev/null || cast balance $REACTIVE --rpc-url $LASNA) wei lREACT"
echo "    debt / reserves : $(cast call $SYSTEM 'debt(address)(uint256)' $REACTIVE --rpc-url $LASNA) / $(cast call $SYSTEM 'reserves(address)(uint256)' $REACTIVE --rpc-url $LASNA)"

say "3/4  Callback — StreakLedger on Base Sepolia ($LEDGER)"
echo "    executionCount  : $(cast call $LEDGER 'executionCount()(uint256)' --rpc-url $BASE)"
echo "    last user       : $(cast call $LEDGER 'lastUser()(address)' --rpc-url $BASE)"
echo "    last origin ts  : $(cast call $LEDGER 'lastOriginTimestamp()(uint256)' --rpc-url $BASE)"
echo "    debt / reserves : $(cast call 0xa6eA49Ed671B8a4dfCDd34E36b7a75Ac79B8A5a6 'debt(address)(uint256)' $LEDGER --rpc-url $BASE) / $(cast call 0xa6eA49Ed671B8a4dfCDd34E36b7a75Ac79B8A5a6 'reserves(address)(uint256)' $LEDGER --rpc-url $BASE)"

say "4/4  Callback records registered with the network (Lasna system contract)"
for TX in 0x8e02cd1996a30a2a2ccf804876b7ab3fa18ba0ba927b1194227280806416713e 0xaa50ea2962fc47bc98df37df96e5d23bc9f045df1680c487de4e752ed082560f; do
  echo "    getCallbacks($TX):"
  cast call $SYSTEM 'getCallbacks(uint256)((uint256,address,uint256,uint256,uint256,bytes)[])' "$TX" --rpc-url $LASNA
done

say "Done. Explorers:"
echo "    CheckIn:       https://sepolia.basescan.org/address/$CHECKIN"
echo "    StreakReactive: https://lasna.reactscan.net/address/$REACTIVE"
echo "    StreakLedger:  https://sepolia.basescan.org/address/$LEDGER"
