// ============================================================
//  firebase-config.example.js
//  TEMPLATE FILE — safe to push to GitHub
//  
//  To use: copy this file, rename to firebase-config.js
//  and fill in your real values
//  Get Firebase values from: Firebase Console → Settings → General
//  Get Supabase values from: Supabase Dashboard → Settings → API
// ============================================================

import { initializeApp }  from "https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js";
import { getAuth }        from "https://www.gstatic.com/firebasejs/10.12.0/firebase-auth.js";
import { getFirestore }   from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";

const firebaseConfig = {
  apiKey:            "YOUR_API_KEY",
  authDomain:        "YOUR_AUTH_DOMAIN",
  projectId:         "YOUR_PROJECT_ID",
  storageBucket:     "YOUR_STORAGE_BUCKET",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId:             "YOUR_APP_ID"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db   = getFirestore(app);

export const SUPABASE_URL = "YOUR_SUPABASE_URL";
export const SUPABASE_KEY = "YOUR_SUPABASE_ANON_KEY";