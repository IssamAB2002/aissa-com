/**
 * One-off backfill: rewrites Order.creatorId from the old Firebase Auth uid
 * (or null) to the matching `employees` document id, so reward/order-history
 * matching (which now keys off employees.id) works for orders created before
 * that change shipped.
 *
 * Dry-run by default — prints a report and writes it to
 * scripts/backfill_creator_ids.report.json without touching Firestore.
 * Pass --apply to actually commit the writes.
 *
 * Usage:
 *   node backfill_creator_ids.js            # dry run
 *   node backfill_creator_ids.js --apply    # commit the fixes
 */
const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');

const KEY_PATH = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(KEY_PATH)) {
  console.error(
    `Missing ${KEY_PATH}\n` +
      'Download a service account key from Firebase console > Project settings ' +
      '> Service accounts > Generate new private key, and save it there.'
  );
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(KEY_PATH)) });
const db = admin.firestore();

const APPLY = process.argv.includes('--apply');

function normalizeName(name) {
  return (name || '').trim().toLowerCase();
}

async function main() {
  const [employeesSnap, ordersSnap] = await Promise.all([
    db.collection('employees').get(),
    db.collection('orders').get(),
  ]);

  const validEmployeeIds = new Set();
  const uidToEmployeeId = new Map();
  const nameToEmployeeIds = new Map(); // normalized name -> [employeeId, ...]

  for (const doc of employeesSnap.docs) {
    const data = doc.data();
    validEmployeeIds.add(doc.id);
    if (data.uid) uidToEmployeeId.set(data.uid, doc.id);
    const key = normalizeName(data.name);
    if (key) {
      if (!nameToEmployeeIds.has(key)) nameToEmployeeIds.set(key, []);
      nameToEmployeeIds.get(key).push(doc.id);
    }
  }

  const toUpdate = []; // { orderId, oldCreatorId, newCreatorId, reason }
  const unresolved = []; // { orderId, oldCreatorId, creatorName, reason }
  let alreadyCorrect = 0;
  let skippedNoCreator = 0;

  for (const doc of ordersSnap.docs) {
    const data = doc.data();
    const creatorId = data.creatorId || null;
    const creatorName = data.creatorName || null;

    if (creatorId && validEmployeeIds.has(creatorId)) {
      alreadyCorrect++;
      continue;
    }

    // Try the uid -> employeeId map first (the common case: order was
    // attributed via an account that existed at the time).
    if (creatorId && uidToEmployeeId.has(creatorId)) {
      toUpdate.push({
        orderId: doc.id,
        oldCreatorId: creatorId,
        newCreatorId: uidToEmployeeId.get(creatorId),
        reason: 'matched-by-uid',
      });
      continue;
    }

    // Fall back to matching the stored creatorName against a *unique*
    // employee name. Anything ambiguous or unmatched is left for manual
    // review rather than guessed.
    const nameKey = normalizeName(creatorName);
    const nameMatches = nameKey ? nameToEmployeeIds.get(nameKey) || [] : [];

    if (!creatorId && !creatorName) {
      skippedNoCreator++;
      continue;
    }

    if (nameMatches.length === 1) {
      toUpdate.push({
        orderId: doc.id,
        oldCreatorId: creatorId,
        newCreatorId: nameMatches[0],
        reason: creatorId ? 'matched-by-name-fallback' : 'matched-by-name-only',
      });
      continue;
    }

    unresolved.push({
      orderId: doc.id,
      oldCreatorId: creatorId,
      creatorName,
      reason:
        nameMatches.length > 1
          ? 'ambiguous-name'
          : creatorId
          ? 'unmatched-uid-no-name-fallback'
          : 'no-creatorId-no-name-match',
    });
  }

  const report = {
    generatedAt: new Date().toISOString(),
    totalOrders: ordersSnap.size,
    totalEmployees: employeesSnap.size,
    alreadyCorrect,
    skippedNoCreator,
    toUpdateCount: toUpdate.length,
    unresolvedCount: unresolved.length,
    toUpdate,
    unresolved,
  };

  const reportPath = path.join(__dirname, 'backfill_creator_ids.report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

  console.log(`Orders scanned:        ${report.totalOrders}`);
  console.log(`Already correct:       ${alreadyCorrect}`);
  console.log(`No creator at all:     ${skippedNoCreator} (nothing to recover)`);
  console.log(`Will be fixed:         ${toUpdate.length}`);
  console.log(`Left for manual review:${unresolved.length}`);
  console.log(`Full report written to ${reportPath}`);

  if (!APPLY) {
    console.log('\nDry run only — no writes made. Re-run with --apply to commit.');
    return;
  }

  if (toUpdate.length === 0) {
    console.log('\nNothing to apply.');
    return;
  }

  console.log(`\nApplying ${toUpdate.length} updates...`);
  const BATCH_LIMIT = 450;
  for (let i = 0; i < toUpdate.length; i += BATCH_LIMIT) {
    const chunk = toUpdate.slice(i, i + BATCH_LIMIT);
    const batch = db.batch();
    for (const item of chunk) {
      batch.update(db.collection('orders').doc(item.orderId), {
        creatorId: item.newCreatorId,
      });
    }
    await batch.commit();
    console.log(`Committed ${Math.min(i + BATCH_LIMIT, toUpdate.length)}/${toUpdate.length}`);
  }
  console.log('Done.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
