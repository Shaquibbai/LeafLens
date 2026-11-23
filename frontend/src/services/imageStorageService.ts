/**
 * IndexedDB Binary Image Storage Service for LeafLens.
 *
 * Stores raw image Blobs in an isolated IndexedDB object store, keeping
 * localStorage dedicated strictly to lightweight submission metadata.
 */

const DB_NAME = 'LeafLens_ImageDB';
const DB_VERSION = 1;
const STORE_NAME = 'images';

interface StoredImageRecord {
  submissionId: string;
  blob: Blob;
  mimeType: string;
  createdAt: string;
}

/**
 * Initializes and returns the IndexedDB database instance.
 */
function openDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (typeof window === 'undefined' || !window.indexedDB) {
      reject(new Error('IndexedDB is not supported in this environment.'));
      return;
    }

    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onupgradeneeded = (event) => {
      const db = (event.target as IDBOpenDBRequest).result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: 'submissionId' });
      }
    };

    request.onsuccess = () => {
      resolve(request.result);
    };

    request.onerror = () => {
      reject(request.error || new Error('Failed to open LeafLens image database.'));
    };
  });
}

/**
 * Saves a binary image Blob associated with a submission ID.
 */
export async function saveImageBlob(submissionId: string, blob: Blob): Promise<void> {
  const db = await openDatabase();
  return new Promise((resolve, reject) => {
    try {
      const transaction = db.transaction(STORE_NAME, 'readwrite');
      const store = transaction.objectStore(STORE_NAME);

      const record: StoredImageRecord = {
        submissionId,
        blob,
        mimeType: blob.type || 'image/jpeg',
        createdAt: new Date().toISOString(),
      };

      const request = store.put(record);

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error || new Error('Failed to save image Blob.'));
      transaction.onerror = () => reject(transaction.error || new Error('Transaction failed.'));
    } catch (err) {
      reject(err);
    }
  });
}

/**
 * Retrieves an image Blob for a given submission ID.
 * Returns null if the image does not exist.
 */
export async function getImageBlob(submissionId: string): Promise<Blob | null> {
  const db = await openDatabase();
  return new Promise((resolve, reject) => {
    try {
      const transaction = db.transaction(STORE_NAME, 'readonly');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.get(submissionId);

      request.onsuccess = () => {
        const record = request.result as StoredImageRecord | undefined;
        if (record && record.blob instanceof Blob) {
          resolve(record.blob);
        } else {
          resolve(null);
        }
      };

      request.onerror = () => reject(request.error || new Error('Failed to retrieve image Blob.'));
      transaction.onerror = () => reject(transaction.error || new Error('Transaction failed.'));
    } catch (err) {
      reject(err);
    }
  });
}

/**
 * Checks whether an image Blob exists for a given submission ID.
 */
export async function hasImageBlob(submissionId: string): Promise<boolean> {
  const blob = await getImageBlob(submissionId);
  return blob !== null;
}

/**
 * Deletes an image Blob by submission ID.
 */
export async function deleteImageBlob(submissionId: string): Promise<void> {
  const db = await openDatabase();
  return new Promise((resolve, reject) => {
    try {
      const transaction = db.transaction(STORE_NAME, 'readwrite');
      const store = transaction.objectStore(STORE_NAME);
      const request = store.delete(submissionId);

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error || new Error('Failed to delete image Blob.'));
      transaction.onerror = () => reject(transaction.error || new Error('Transaction failed.'));
    } catch (err) {
      reject(err);
    }
  });
}

/**
 * Helper to convert a Base64 Data URL to a Blob.
 * Used exclusively for legacy data migration.
 */
export function dataUrlToBlob(dataUrl: string): Blob {
  const parts = dataUrl.split(',');
  const mimeMatch = parts[0].match(/:(.*?);/);
  const mimeType = mimeMatch ? mimeMatch[1] : 'image/jpeg';
  const byteString = atob(parts[1]);
  const arrayBuffer = new ArrayBuffer(byteString.length);
  const uint8Array = new Uint8Array(arrayBuffer);

  for (let i = 0; i < byteString.length; i++) {
    uint8Array[i] = byteString.charCodeAt(i);
  }

  return new Blob([uint8Array], { type: mimeType });
}
