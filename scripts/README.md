# Admin scripts

One-off Node scripts for direct Firestore maintenance. Not part of the Flutter app.

## Setup

1. `cd scripts && npm install`
2. Get a service account key: Firebase console → Project settings → Service accounts
   → Generate new private key. Save the downloaded file as `scripts/serviceAccountKey.json`
   (already gitignored — never commit it).

## backfill_creator_ids.js

Rewrites `Order.creatorId` from the old Firebase Auth uid (or null) to the matching
`employees` document id, for orders created before reward/order-history matching
switched to keying off `employees.id`.

```
node backfill_creator_ids.js            # dry run — writes a report, no Firestore writes
node backfill_creator_ids.js --apply    # commits the fixes found by the dry run
```

Always run the dry run first and check `backfill_creator_ids.report.json`:
- `toUpdate` — orders it will fix, and how it matched them (`matched-by-uid` is the
  normal case; `matched-by-name-*` means it fell back to the saved `creatorName` because
  the uid lookup failed or the order never had a creatorId)
- `unresolved` — orders it would NOT touch: ambiguous name matches (two+ employees with
  the same name) or no way to recover the creator at all. Review these by hand.

This script only touches `creatorId`. It does not recompute `amountOwed` for orders
that were confirmed-paid but never got credited under the old matching — that was an
explicit choice to keep this backfill reversible-ish; handle historical reward balances
separately if needed.
