export const MEDIA_PTR_PREFIX = 'idb://';
const DB_NAME = 'billing_media_v1';
const STORE_NAME = 'media';

export const isMediaPointer = (val: unknown): val is string =>
  typeof val === 'string' && val.startsWith(MEDIA_PTR_PREFIX);
export const makeMediaPointer = (key: string): string => `${MEDIA_PTR_PREFIX}${key}`;
export const extractMediaKey = (ptr: string): string => ptr.slice(MEDIA_PTR_PREFIX.length);

function openMediaDb(): Promise<IDBDatabase | null> {
  if (typeof indexedDB === 'undefined') return Promise.resolve(null);
  return new Promise((resolve) => {
    try {
      const req = indexedDB.open(DB_NAME, 1);
      req.onupgradeneeded = () => {
        if (!req.result.objectStoreNames.contains(STORE_NAME)) req.result.createObjectStore(STORE_NAME);
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => resolve(null);
      req.onblocked = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

export async function putMedia(key: string, dataUri: string): Promise<boolean> {
  const db = await openMediaDb();
  if (!db) return false;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).put(dataUri, key);
      tx.oncomplete = () => { db.close(); resolve(true); };
      tx.onerror = () => { db.close(); resolve(false); };
      tx.onabort = () => { db.close(); resolve(false); };
    } catch { db.close(); resolve(false); }
  });
}

export async function getMedia(key: string): Promise<string | null> {
  const db = await openMediaDb();
  if (!db) return null;
  return new Promise((resolve) => {
    try {
      const req = db.transaction(STORE_NAME, 'readonly').objectStore(STORE_NAME).get(key);
      req.onsuccess = () => { db.close(); resolve(typeof req.result === 'string' ? req.result : null); };
      req.onerror = () => { db.close(); resolve(null); };
    } catch { db.close(); resolve(null); }
  });
}

export async function deleteMedia(key: string): Promise<void> {
  const db = await openMediaDb();
  if (!db) return;
  await new Promise<void>((resolve) => {
    try {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).delete(key);
      tx.oncomplete = () => { db.close(); resolve(); };
      tx.onerror = () => { db.close(); resolve(); };
    } catch { db.close(); resolve(); }
  });
}

export async function getAllMedia(): Promise<Record<string, string>> {
  const db = await openMediaDb();
  if (!db) return {};
  return new Promise((resolve) => {
    const out: Record<string, string> = {};
    try {
      const cursorReq = db.transaction(STORE_NAME, 'readonly').objectStore(STORE_NAME).openCursor();
      cursorReq.onsuccess = () => {
        const cur = cursorReq.result;
        if (cur) {
          if (typeof cur.key === 'string' && typeof cur.value === 'string') out[cur.key] = cur.value;
          cur.continue();
        } else { db.close(); resolve(out); }
      };
      cursorReq.onerror = () => { db.close(); resolve(out); };
    } catch { db.close(); resolve(out); }
  });
}

export async function clearAllMedia(): Promise<void> {
  const db = await openMediaDb();
  if (!db) return;
  await new Promise<void>((resolve) => {
    try {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).clear();
      tx.oncomplete = () => { db.close(); resolve(); };
      tx.onerror = () => { db.close(); resolve(); };
    } catch { db.close(); resolve(); }
  });
}
