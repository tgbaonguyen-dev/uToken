import { initializeApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator } from 'firebase/firestore';
import { connectAuthEmulator } from 'firebase/auth';

// Public web config of the "uToken Companion" Firebase web app (not a secret:
// access is enforced by Firestore Rules — only admins/{uid} can read others).
const config = {
  apiKey: 'AIzaSyChPxkapXUiE5yfKVCRJpFlN1y2Yxe22Hc',
  authDomain: 'utoken-78191.firebaseapp.com',
  projectId: 'utoken-78191',
  storageBucket: 'utoken-78191.firebasestorage.app',
  messagingSenderId: '954169269265',
  appId: '1:954169269265:web:fd9702d84b4f3383e7e5b0',
};

export const app = initializeApp(config);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const google = new GoogleAuthProvider();
export const projectId = config.projectId;

if (import.meta.env.VITE_USE_EMULATOR === '1') {
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
}
