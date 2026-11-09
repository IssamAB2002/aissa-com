/**
 * Seeds the LOCAL FIREBASE EMULATOR (never the real "aissa-com" project)
 * with mock products, suppliers, ZR territory/hub reference data, orders
 * and purchases — enough to exercise the Inventaire feature end-to-end
 * without needing a working ZR Express sync (which hits CORS on Flutter
 * web) or any real business data.
 *
 * Safety: this script hard-codes the emulator host/port itself, before
 * initializing firebase-admin, and never reads scripts/serviceAccountKey.json.
 * It is therefore unable to reach the real project even if real credentials
 * happen to be present on this machine.
 *
 * Usage:
 *   firebase emulators:start --config firebase.emulator.json --project aissa-com
 *   cd scripts && npm install   (once)
 *   node seed_emulator_data.js            # seed (idempotent, safe to re-run)
 *   node seed_emulator_data.js --reset    # delete previously seeded docs first
 *
 * All seeded documents use deterministic ids prefixed with "seed-" so a
 * --reset can find and remove exactly (and only) what this script created,
 * without touching anything else in the emulator.
 */
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'aissa-com' });
const db = admin.firestore();

const RESET = process.argv.includes('--reset');
const now = admin.firestore.Timestamp.now();
const daysAgo = (n) =>
  admin.firestore.Timestamp.fromMillis(Date.now() - n * 24 * 60 * 60 * 1000);

const SEEDED_COLLECTIONS = [
  'wilayas',
  'baladias',
  'zr_hubs',
  'suppliers',
  'products',
  'orders',
  'purchases',
];

async function deleteSeeded() {
  for (const col of SEEDED_COLLECTIONS) {
    const snap = await db.collection(col).get();
    const toDelete = snap.docs.filter((d) => d.id.startsWith('seed-'));
    if (toDelete.length === 0) continue;
    const batch = db.batch();
    for (const d of toDelete) batch.delete(d.ref);
    await batch.commit();
    console.log(`  deleted ${toDelete.length} seeded doc(s) from ${col}`);
  }
}

// ── Reference data (stands in for a ZR territories/hubs sync) ─────────────

const wilayas = [
  { id: 'seed-wilaya-16', code: 16, nameFr: 'Alger', nameAr: 'الجزائر' },
  { id: 'seed-wilaya-31', code: 31, nameFr: 'Oran', nameAr: 'وهران' },
];

const baladias = [
  { id: 'seed-baladia-16-1', wilayaId: 'seed-wilaya-16', nameFr: 'Hydra', nameAr: 'حيدرة' },
  { id: 'seed-baladia-16-2', wilayaId: 'seed-wilaya-16', nameFr: 'Kouba', nameAr: 'القبة' },
  { id: 'seed-baladia-31-1', wilayaId: 'seed-wilaya-31', nameFr: 'Es Senia', nameAr: 'السانية' },
];

const hubs = [
  {
    id: 'seed-hub-16-1',
    zrHubId: 'seed-hub-16-1',
    name: 'Alger Centre Stopdesk',
    wilayaId: 'seed-wilaya-16',
  },
];

// ── Suppliers ───────────────────────────────────────────────────────────────

const suppliers = [
  { id: 'seed-supplier-1', name: 'Fournisseur Atlas', phone: '0550000001' },
  { id: 'seed-supplier-2', name: 'Fournisseur Sahara', phone: '0550000002' },
];

// ── Products ────────────────────────────────────────────────────────────────
// Deliberately varied so each Inventaire step has something to exercise:
// - seed-product-13/14: costPrice 0/null -> trips the cost-price gate
// - seed-product-15: isActive false -> must be skipped everywhere
// - seed-product-16: stockQuantity 0 -> out-of-stock edge case

const products = [];
for (let i = 1; i <= 12; i++) {
  products.push({
    id: `seed-product-${i}`,
    name: `Produit Test ${i}`,
    category: i % 2 === 0 ? 'Outillage' : 'Quincaillerie',
    price: 1000 + i * 50,
    costPrice: 600 + i * 30,
    stockQuantity: 10 + i,
    lowStockThreshold: 5,
    isActive: true,
  });
}
products.push({
  id: 'seed-product-13',
  name: 'Produit Sans Prix Coûtant',
  category: 'Outillage',
  price: 1500,
  costPrice: 0,
  stockQuantity: 8,
  lowStockThreshold: 5,
  isActive: true,
});
products.push({
  id: 'seed-product-14',
  name: 'Produit Prix Coûtant Null',
  category: 'Outillage',
  price: 1800,
  costPrice: null,
  stockQuantity: 6,
  lowStockThreshold: 5,
  isActive: true,
});
products.push({
  id: 'seed-product-15',
  name: 'Produit Inactif',
  category: 'Divers',
  price: 500,
  costPrice: 300,
  stockQuantity: 3,
  lowStockThreshold: 5,
  isActive: false,
});
products.push({
  id: 'seed-product-16',
  name: 'Produit Rupture Stock',
  category: 'Quincaillerie',
  price: 900,
  costPrice: 500,
  stockQuantity: 0,
  lowStockThreshold: 5,
  isActive: true,
});

function orderItem(productId, quantity) {
  const p = products.find((x) => x.id === productId);
  return {
    productId: p.id,
    productName: p.name,
    unitPrice: p.price,
    quantity,
    unitCostPrice: p.costPrice || 0,
  };
}

function purchaseItem(productId, quantity) {
  const p = products.find((x) => x.id === productId);
  return {
    productId: p.id,
    productName: p.name,
    unitCost: p.costPrice || 0,
    quantity,
  };
}

// ── Orders ──────────────────────────────────────────────────────────────────
// Mix of statuses: pending/confirmed need resolving by Inventaire's resolve
// step; delivered/cancelled are already terminal and must be left alone.

const orders = [
  {
    id: 'seed-order-1',
    customerName: 'Client Test 1',
    customerPhone: '0660000001',
    items: [orderItem('seed-product-1', 2), orderItem('seed-product-2', 1)],
    status: 'pending',
    deliveryType: 'homeDelivery',
    wilayaId: 'seed-wilaya-16',
    wilayaName: 'Alger',
    wilayaZrTerritoryId: 'seed-wilaya-16',
    baladiaId: 'seed-baladia-16-1',
    baladiaName: 'Hydra',
    baladiaZrTerritoryId: 'seed-baladia-16-1',
  },
  {
    id: 'seed-order-2',
    customerName: 'Client Test 2',
    customerPhone: '0660000002',
    items: [orderItem('seed-product-3', 3)],
    status: 'confirmed',
    deliveryType: 'pickupPoint',
    wilayaId: 'seed-wilaya-16',
    wilayaName: 'Alger',
    wilayaZrTerritoryId: 'seed-wilaya-16',
    baladiaId: 'seed-baladia-16-2',
    baladiaName: 'Kouba',
    baladiaZrTerritoryId: 'seed-baladia-16-2',
    hubId: 'seed-hub-16-1',
    hubZrId: 'seed-hub-16-1',
    hubName: 'Alger Centre Stopdesk',
  },
  {
    id: 'seed-order-3',
    customerName: 'Client Test 3',
    customerPhone: '0660000003',
    items: [orderItem('seed-product-4', 1), orderItem('seed-product-5', 2)],
    status: 'pending',
    deliveryType: 'homeDelivery',
    wilayaId: 'seed-wilaya-31',
    wilayaName: 'Oran',
    wilayaZrTerritoryId: 'seed-wilaya-31',
    baladiaId: 'seed-baladia-31-1',
    baladiaName: 'Es Senia',
    baladiaZrTerritoryId: 'seed-baladia-31-1',
  },
  {
    id: 'seed-order-4',
    customerName: 'Client Test 4 (déjà livré)',
    customerPhone: '0660000004',
    items: [orderItem('seed-product-6', 2)],
    status: 'delivered',
    stockApplied: true,
    deliveryType: 'homeDelivery',
    wilayaId: 'seed-wilaya-16',
    wilayaName: 'Alger',
    wilayaZrTerritoryId: 'seed-wilaya-16',
    baladiaId: 'seed-baladia-16-1',
    baladiaName: 'Hydra',
    baladiaZrTerritoryId: 'seed-baladia-16-1',
  },
  {
    id: 'seed-order-5',
    customerName: 'Client Test 5 (annulé)',
    customerPhone: '0660000005',
    items: [orderItem('seed-product-7', 1)],
    status: 'cancelled',
    deliveryType: 'pickupPoint',
    wilayaId: 'seed-wilaya-16',
    wilayaName: 'Alger',
    wilayaZrTerritoryId: 'seed-wilaya-16',
  },
];

// ── Purchases ───────────────────────────────────────────────────────────────

const purchases = [
  {
    id: 'seed-purchase-1',
    supplierId: 'seed-supplier-1',
    supplierName: 'Fournisseur Atlas',
    items: [purchaseItem('seed-product-8', 10), purchaseItem('seed-product-9', 5)],
    status: 'pending',
  },
  {
    id: 'seed-purchase-2',
    supplierId: 'seed-supplier-2',
    supplierName: 'Fournisseur Sahara',
    items: [purchaseItem('seed-product-10', 8)],
    status: 'pending',
  },
  {
    id: 'seed-purchase-3',
    supplierId: 'seed-supplier-1',
    supplierName: 'Fournisseur Atlas',
    items: [purchaseItem('seed-product-11', 6)],
    status: 'received',
    stockApplied: true,
  },
  {
    id: 'seed-purchase-4',
    supplierId: 'seed-supplier-2',
    supplierName: 'Fournisseur Sahara',
    items: [purchaseItem('seed-product-12', 4)],
    status: 'cancelled',
  },
];

async function seedWilayas() {
  const batch = db.batch();
  for (const w of wilayas) {
    batch.set(db.collection('wilayas').doc(w.id), {
      code: w.code,
      nameAr: w.nameAr,
      nameFr: w.nameFr,
      zrTerritoryId: w.id,
      isActive: true,
      shippingPriceHome: 400,
      shippingPriceDesk: 300,
    });
  }
  await batch.commit();
  console.log(`  wilayas: ${wilayas.length}`);
}

async function seedBaladias() {
  const batch = db.batch();
  for (const b of baladias) {
    batch.set(db.collection('baladias').doc(b.id), {
      wilayaId: b.wilayaId,
      nameAr: b.nameAr,
      nameFr: b.nameFr,
      zrTerritoryId: b.id,
      isActive: true,
    });
  }
  await batch.commit();
  console.log(`  baladias: ${baladias.length}`);
}

async function seedHubs() {
  const batch = db.batch();
  for (const h of hubs) {
    batch.set(db.collection('zr_hubs').doc(h.id), {
      zrHubId: h.zrHubId,
      name: h.name,
      type: 'hub',
      isPickupPoint: true,
      isVisible: true,
      wilayaId: h.wilayaId,
      street: '',
      district: '',
      postalCode: '',
      phone: '',
      lat: null,
      lng: null,
    });
  }
  await batch.commit();
  console.log(`  zr_hubs: ${hubs.length}`);
}

async function seedSuppliers() {
  const batch = db.batch();
  for (const s of suppliers) {
    batch.set(db.collection('suppliers').doc(s.id), {
      name: s.name,
      phone: s.phone,
      createdAt: daysAgo(30),
      updatedAt: daysAgo(30),
    });
  }
  await batch.commit();
  console.log(`  suppliers: ${suppliers.length}`);
}

async function seedProducts() {
  const batch = db.batch();
  for (const p of products) {
    batch.set(db.collection('products').doc(p.id), {
      name: p.name,
      description: null,
      category: p.category,
      price: p.price,
      costPrice: p.costPrice,
      stockQuantity: p.stockQuantity,
      lowStockThreshold: p.lowStockThreshold,
      isActive: p.isActive,
      createdAt: daysAgo(20),
      stockUpdatedAt: daysAgo(20),
    });
  }
  await batch.commit();
  console.log(`  products: ${products.length}`);
}

async function seedOrders() {
  const batch = db.batch();
  for (const o of orders) {
    const subtotal = o.items.reduce((s, i) => s + i.unitPrice * i.quantity, 0);
    batch.set(db.collection('orders').doc(o.id), {
      customerName: o.customerName,
      customerPhone: o.customerPhone || null,
      address: null,
      city: null,
      items: o.items,
      status: o.status,
      total: subtotal,
      discountAmount: 0,
      deliveryType: o.deliveryType,
      notes: null,
      createdAt: daysAgo(5),
      updatedAt: null,
      paymentConfirmed: false,
      stockApplied: o.stockApplied || false,
      creatorId: null,
      creatorName: 'Admin (seed)',
      wilayaId: o.wilayaId || null,
      wilayaName: o.wilayaName || null,
      wilayaZrTerritoryId: o.wilayaZrTerritoryId || null,
      baladiaId: o.baladiaId || null,
      baladiaName: o.baladiaName || null,
      baladiaZrTerritoryId: o.baladiaZrTerritoryId || null,
      hubId: o.hubId || null,
      hubZrId: o.hubZrId || null,
      hubName: o.hubName || null,
      zrSubmitted: false,
      zrCustomerId: null,
      zrParcelId: null,
      zrTrackingNumber: null,
      zrPostedAt: null,
      zrDeliveryFee: 0,
      fees: 0,
      plGenerated: false,
      plId: null,
    });
  }
  await batch.commit();
  console.log(`  orders: ${orders.length}`);
}

async function seedPurchases() {
  const batch = db.batch();
  for (const p of purchases) {
    const subtotal = p.items.reduce((s, i) => s + i.unitCost * i.quantity, 0);
    batch.set(db.collection('purchases').doc(p.id), {
      supplierId: p.supplierId,
      supplierName: p.supplierName,
      items: p.items,
      total: subtotal,
      fees: 0,
      status: p.status,
      notes: null,
      createdAt: daysAgo(4),
      updatedAt: null,
      paymentConfirmed: false,
      stockApplied: p.stockApplied || false,
      sourceOrderId: null,
      sourceOrderIds: [],
      plGenerated: false,
      plId: null,
    });
  }
  await batch.commit();
  console.log(`  purchases: ${purchases.length}`);
}

async function main() {
  console.log(`Target: ${process.env.FIRESTORE_EMULATOR_HOST} (emulator only)`);

  if (RESET) {
    console.log('Resetting previously seeded docs...');
    await deleteSeeded();
  }

  console.log('Seeding...');
  await seedWilayas();
  await seedBaladias();
  await seedHubs();
  await seedSuppliers();
  await seedProducts();
  await seedOrders();
  await seedPurchases();

  console.log('\nDone. Open http://127.0.0.1:4000/firestore to inspect the data.');
  console.log('Orders pending/confirmed (need resolving in Inventaire): seed-order-1, seed-order-2, seed-order-3');
  console.log('Purchases pending (need resolving): seed-purchase-1, seed-purchase-2');
  console.log('Products missing cost price (cost-price gate): seed-product-13, seed-product-14');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
