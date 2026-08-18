/**
 * Security-rule tests for Balance Book, run against the Firestore emulator.
 *
 *   npm run rules:test        (from the project root)
 *
 * These exist because "the app never shows you someone else's data" proves
 * nothing on its own. The rules are the boundary, so they get tested directly
 * with raw SDK calls that bypass the app entirely.
 */

import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const ALICE = 'alice-uid';
const BOB = 'bob-uid';

let testEnv;

/** A well-formed client document. */
const clientDoc = (overrides = {}) => ({
  name: 'Rahul Sharma',
  nameLower: 'rahul sharma',
  companyName: 'ABC Agency',
  phone: '+919876543210',
  email: 'rahul@example.com',
  address: '',
  notes: '',
  avatarColor: '#4F46E5',
  currentBalance: 2000000,
  totalCharged: 2000000,
  totalPaid: 0,
  transactionCount: 1,
  isFavorite: false,
  status: 'active',
  lastTransactionId: 'tx1',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  lastActivityAt: serverTimestamp(),
  ...overrides,
});

/** A well-formed transaction document. */
const txDoc = (uid, clientId, overrides = {}) => ({
  userId: uid,
  clientId,
  projectId: null,
  type: 'charge',
  amount: 200000,
  delta: 200000,
  runningBalance: 2200000,
  note: 'Extra landing page',
  paymentMethod: '',
  prevTransactionId: null,
  reversesId: null,
  reversedById: null,
  isReversed: false,
  createdAt: serverTimestamp(),
  createdBy: uid,
  createdByName: 'Alice',
  editedAt: null,
  ...overrides,
});

const profileDoc = (overrides = {}) => ({
  name: 'Alice',
  email: 'alice@example.com',
  photoURL: null,
  currency: 'INR',
  paymentDetails: '',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
});

const db = (uid) => testEnv.authenticatedContext(uid).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-balance-book',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

/** Seeds data with the rules disabled, so setup never depends on them. */
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

describe('isolation between users', () => {
  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (raw) => {
      await setDoc(doc(raw, `users/${ALICE}`), profileDoc());
      await setDoc(doc(raw, `users/${ALICE}/clients/c1`), clientDoc());
      await setDoc(
        doc(raw, `users/${ALICE}/clients/c1/transactions/tx1`),
        txDoc(ALICE, 'c1'),
      );
      await setDoc(doc(raw, `users/${ALICE}/clients/c1/projects/p1`), {
        name: 'Website',
        nameLower: 'website',
        note: '',
        color: '#4F46E5',
        status: 'active',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });
  });

  it('lets a user read their own client', async () => {
    await assertSucceeds(getDoc(doc(db(ALICE), `users/${ALICE}/clients/c1`)));
  });

  it("blocks reading another user's profile", async () => {
    await assertFails(getDoc(doc(db(BOB), `users/${ALICE}`)));
  });

  it("blocks reading another user's client", async () => {
    await assertFails(getDoc(doc(db(BOB), `users/${ALICE}/clients/c1`)));
  });

  it("blocks listing another user's clients", async () => {
    await assertFails(getDocs(collection(db(BOB), `users/${ALICE}/clients`)));
  });

  it("blocks reading another user's transaction", async () => {
    await assertFails(
      getDoc(doc(db(BOB), `users/${ALICE}/clients/c1/transactions/tx1`)),
    );
  });

  it("blocks reading another user's projects", async () => {
    await assertFails(
      getDocs(collection(db(BOB), `users/${ALICE}/clients/c1/projects`)),
    );
  });

  it("blocks writing to another user's client", async () => {
    await assertFails(
      updateDoc(doc(db(BOB), `users/${ALICE}/clients/c1`), {
        currentBalance: 0,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it("blocks creating a client under another user", async () => {
    await assertFails(
      setDoc(doc(db(BOB), `users/${ALICE}/clients/c2`), clientDoc()),
    );
  });

  it("blocks deleting another user's transaction", async () => {
    await assertFails(
      deleteDoc(doc(db(BOB), `users/${ALICE}/clients/c1/transactions/tx1`)),
    );
  });

  it('blocks unauthenticated access entirely', async () => {
    await assertFails(getDoc(doc(anon(), `users/${ALICE}/clients/c1`)));
    await assertFails(
      setDoc(doc(anon(), `users/${ALICE}/clients/c9`), clientDoc()),
    );
  });
});

describe('the activity feed collection-group query', () => {
  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (raw) => {
      await setDoc(doc(raw, `users/${ALICE}/clients/c1`), clientDoc());
      await setDoc(
        doc(raw, `users/${ALICE}/clients/c1/transactions/tx1`),
        txDoc(ALICE, 'c1'),
      );
      await setDoc(doc(raw, `users/${BOB}/clients/c2`), clientDoc());
      await setDoc(
        doc(raw, `users/${BOB}/clients/c2/transactions/tx2`),
        txDoc(BOB, 'c2'),
      );
    });
  });

  it('succeeds when scoped to the caller and returns only their rows', async () => {
    const snap = await assertSucceeds(
      getDocs(
        query(
          collectionGroup(db(ALICE), 'transactions'),
          where('userId', '==', ALICE),
        ),
      ),
    );
    assert.equal(snap.size, 1);
    assert.equal(snap.docs[0].id, 'tx1');
  });

  it('rejects an unscoped collection-group query', async () => {
    await assertFails(
      getDocs(collectionGroup(db(ALICE), 'transactions')),
    );
  });

  it("rejects a query scoped to somebody else's uid", async () => {
    await assertFails(
      getDocs(
        query(
          collectionGroup(db(ALICE), 'transactions'),
          where('userId', '==', BOB),
        ),
      ),
    );
  });
});

describe('transaction validation', () => {
  const path = `users/${ALICE}/clients/c1/transactions`;

  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (raw) => {
      await setDoc(doc(raw, `users/${ALICE}/clients/c1`), clientDoc());
      await setDoc(doc(raw, `${path}/existing`), txDoc(ALICE, 'c1'));
    });
  });

  it('accepts a well-formed charge', async () => {
    await assertSucceeds(
      setDoc(doc(db(ALICE), `${path}/ok1`), txDoc(ALICE, 'c1')),
    );
  });

  it('accepts a payment, whose delta is negative', async () => {
    await assertSucceeds(
      setDoc(
        doc(db(ALICE), `${path}/ok2`),
        txDoc(ALICE, 'c1', {
          type: 'payment',
          amount: 500000,
          delta: -500000,
          runningBalance: 1700000,
        }),
      ),
    );
  });

  it('rejects a float amount, money must be integer minor units', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), `${path}/bad1`),
        txDoc(ALICE, 'c1', { amount: 2000.5, delta: 2000.5 }),
      ),
    );
  });

  it('rejects a negative headline amount', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), `${path}/bad2`),
        txDoc(ALICE, 'c1', { amount: -200000, delta: -200000 }),
      ),
    );
  });

  it('rejects a delta that does not match its amount', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), `${path}/bad3`),
        txDoc(ALICE, 'c1', { amount: 200000, delta: 999999 }),
      ),
    );
  });

  it('rejects a back-dated createdAt, it must be the server timestamp', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), `${path}/bad4`),
        txDoc(ALICE, 'c1', { createdAt: new Date('2020-01-01') }),
      ),
    );
  });

  it('rejects an unknown transaction type', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), `${path}/bad5`),
        txDoc(ALICE, 'c1', { type: 'freebie' }),
      ),
    );
  });

  it('rejects a transaction stamped with the wrong userId', async () => {
    await assertFails(
      setDoc(doc(db(ALICE), `${path}/bad6`), txDoc(BOB, 'c1')),
    );
  });

  it('rejects a transaction created as already reversed', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), `${path}/bad7`),
        txDoc(ALICE, 'c1', { isReversed: true }),
      ),
    );
  });
});

describe('recorded transactions are immutable where it matters', () => {
  const path = `users/${ALICE}/clients/c1/transactions/existing`;

  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (raw) => {
      await setDoc(doc(raw, `users/${ALICE}/clients/c1`), clientDoc());
      await setDoc(doc(raw, path), txDoc(ALICE, 'c1'));
    });
  });

  it('allows editing the description', async () => {
    await assertSucceeds(
      updateDoc(doc(db(ALICE), path), {
        note: 'Extra landing page (revised)',
        paymentMethod: '',
        projectId: null,
        editedAt: serverTimestamp(),
      }),
    );
  });

  it('allows flagging it as reversed', async () => {
    await assertSucceeds(
      updateDoc(doc(db(ALICE), path), {
        isReversed: true,
        reversedById: 'tx-reversal',
      }),
    );
  });

  it('rejects changing the amount', async () => {
    await assertFails(updateDoc(doc(db(ALICE), path), { amount: 1 }));
  });

  it('rejects changing the signed delta', async () => {
    await assertFails(updateDoc(doc(db(ALICE), path), { delta: -200000 }));
  });

  it('rejects changing the running balance', async () => {
    await assertFails(
      updateDoc(doc(db(ALICE), path), { runningBalance: 0 }),
    );
  });

  it('rejects changing the type', async () => {
    await assertFails(updateDoc(doc(db(ALICE), path), { type: 'payment' }));
  });

  it('rejects re-stamping createdAt', async () => {
    await assertFails(
      updateDoc(doc(db(ALICE), path), { createdAt: serverTimestamp() }),
    );
  });
});

describe('client validation', () => {
  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (raw) => {
      await setDoc(doc(raw, `users/${ALICE}/clients/c1`), clientDoc());
    });
  });

  it('accepts a well-formed client', async () => {
    await assertSucceeds(
      setDoc(doc(db(ALICE), `users/${ALICE}/clients/new1`), clientDoc()),
    );
  });

  it('accepts a negative balance, a client can be in credit', async () => {
    await assertSucceeds(
      setDoc(
        doc(db(ALICE), `users/${ALICE}/clients/new2`),
        clientDoc({ currentBalance: -200000, totalCharged: 0, totalPaid: 200000 }),
      ),
    );
  });

  it('rejects an empty name', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), `users/${ALICE}/clients/bad1`),
        clientDoc({ name: '' }),
      ),
    );
  });

  it('rejects a float balance', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), `users/${ALICE}/clients/bad2`),
        clientDoc({ currentBalance: 20000.5 }),
      ),
    );
  });

  it('rejects an unknown status', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), `users/${ALICE}/clients/bad3`),
        clientDoc({ status: 'vip' }),
      ),
    );
  });

  it('rejects negative lifetime totals', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), `users/${ALICE}/clients/bad4`),
        clientDoc({ totalPaid: -1 }),
      ),
    );
  });
});

describe('profile documents', () => {
  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (raw) => {
      await setDoc(doc(raw, `users/${ALICE}`), profileDoc());
    });
  });

  it('lets a user update their own profile', async () => {
    await assertSucceeds(
      setDoc(
        doc(db(ALICE), `users/${ALICE}`),
        { name: 'Alice B', updatedAt: serverTimestamp() },
        { merge: true },
      ),
    );
  });

  it('blocks deleting a profile, which would orphan every client under it', async () => {
    await assertFails(deleteDoc(doc(db(ALICE), `users/${ALICE}`)));
  });

  it("blocks writing to another user's profile", async () => {
    await assertFails(
      setDoc(
        doc(db(BOB), `users/${ALICE}`),
        { name: 'hacked', updatedAt: serverTimestamp() },
        { merge: true },
      ),
    );
  });
});

describe('public balance pages', () => {
  const ledger = (uid = ALICE, overrides = {}) => ({
    userId: uid,
    clientId: 'c1',
    clientName: 'Rahul Sharma',
    companyName: 'ABC Agency',
    currency: 'INR',
    currentBalance: 1700000,
    totalCharged: 2200000,
    totalPaid: 500000,
    transactionCount: 3,
    projects: [],
    transactions: [],
    historyTruncated: false,
    updatedAt: serverTimestamp(),
    ...overrides,
  });

  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (raw) => {
      await setDoc(doc(raw, 'publicLedgers/alicesharekey000000000001'), {
        ...ledger(),
        updatedAt: new Date(),
      });
      await setDoc(doc(raw, 'publicLedgers/bobsharekey0000000000000002'), {
        ...ledger(BOB),
        updatedAt: new Date(),
      });
    });
  });

  it('lets anyone holding the link read that one page', async () => {
    const snap = await assertSucceeds(
      getDoc(doc(anon(), 'publicLedgers/alicesharekey000000000001')),
    );
    assert.equal(snap.data().clientName, 'Rahul Sharma');
  });

  it('BLOCKS listing the collection, so links cannot be enumerated', async () => {
    // This is the assertion that turns a public collection into a capability
    // URL. Without it, one query would hand over every client of every user.
    await assertFails(getDocs(collection(anon(), 'publicLedgers')));
    await assertFails(getDocs(collection(db(BOB), 'publicLedgers')));
  });

  it('returns nothing for an id that does not exist', async () => {
    const snap = await assertSucceeds(
      getDoc(doc(anon(), 'publicLedgers/thisidwasneverissued00001')),
    );
    assert.equal(snap.exists(), false);
  });

  it('blocks an anonymous visitor from writing to a page', async () => {
    await assertFails(
      updateDoc(doc(anon(), 'publicLedgers/alicesharekey000000000001'), {
        currentBalance: 0,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      deleteDoc(doc(anon(), 'publicLedgers/alicesharekey000000000001')),
    );
  });

  it("blocks another user from overwriting someone else's page", async () => {
    await assertFails(
      updateDoc(doc(db(BOB), 'publicLedgers/alicesharekey000000000001'), {
        userId: BOB,
        currentBalance: 0,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it("blocks another user from deleting someone else's page", async () => {
    await assertFails(
      deleteDoc(doc(db(BOB), 'publicLedgers/alicesharekey000000000001')),
    );
  });

  it('lets the owner publish and revoke their own page', async () => {
    await assertSucceeds(
      setDoc(doc(db(ALICE), 'publicLedgers/newaliceshare00000000001'), ledger()),
    );
    await assertSucceeds(
      deleteDoc(doc(db(ALICE), 'publicLedgers/newaliceshare00000000001')),
    );
  });

  it("blocks publishing a page stamped with someone else's uid", async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), 'publicLedgers/forgedpage000000000000001'),
        ledger(BOB),
      ),
    );
  });

  it('rejects a float balance on a public page too', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), 'publicLedgers/floatpage00000000000000001'),
        ledger(ALICE, { currentBalance: 17000.5 }),
      ),
    );
  });

  it('rejects a back-dated updatedAt', async () => {
    await assertFails(
      setDoc(
        doc(db(ALICE), 'publicLedgers/staledate000000000000001'),
        ledger(ALICE, { updatedAt: new Date('2020-01-01') }),
      ),
    );
  });

  it('a public page never exposes the private tree it mirrors', async () => {
    // Belt and braces: publishing a snapshot must not make the real client
    // readable to anyone else.
    await seed(async (raw) => {
      await setDoc(doc(raw, `users/${ALICE}/clients/c1`), clientDoc());
    });
    await assertFails(getDoc(doc(anon(), `users/${ALICE}/clients/c1`)));
    await assertFails(getDoc(doc(db(BOB), `users/${ALICE}/clients/c1`)));
  });
});
