import { initializeApp } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { initializeFirestore, memoryLocalCache } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";
import { getStorage } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-storage.js";

const firebaseConfig = {
  apiKey: "AIzaSyC5KoU8YyrSwRIjuhMczS8mnEBgMfDlrzc",
  authDomain: "plataforma-examenes-f2df9.firebaseapp.com",
  projectId: "plataforma-examenes-f2df9",
  storageBucket: "plataforma-examenes-f2df9.firebasestorage.app",
  messagingSenderId: "504614396126",
  appId: "1:504614396126:web:2d526051d5c7503e21224f"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = initializeFirestore(app, {
  localCache: memoryLocalCache(),
  experimentalForceLongPolling: true
});
export const storage = getStorage(app);
