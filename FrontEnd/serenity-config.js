// ============================================================
//  serenity-config.js
//  Shared configuration — imported by every page via type="module"
//  FILL IN your actual keys before running the app
// ============================================================

// ── SUPABASE ─────────────────────────────────────────────────
export const SUPABASE_URL = "https://pjernwhcerujrfczodpq.supabase.co";
export const SUPABASE_KEY= "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBqZXJud2hjZXJ1anJmY3pvZHBxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzMjYwOTEsImV4cCI6MjA5MzkwMjA5MX0.Efw1Kf20W4Lho_Znz2z4vb2qReNxGI0FVDk8D1042nU";

// ── FIREBASE ─────────────────────────────────────────────────
const firebaseConfig = {
  apiKey: "AIzaSyBg1S62gu-Nj3ElkkGCyOr7qmBXzai6jow",
  authDomain: "mh-journal-754db.firebaseapp.com",
  projectId: "mh-journal-754db",
  storageBucket: "mh-journal-754db.firebasestorage.app",
  messagingSenderId: "254544548183",
  appId: "1:254544548183:web:e9a28ce5e471e5a2b96e12",
  measurementId: "G-1DGTNMB6XG"
};

// ── SESSION KEY ───────────────────────────────────────────────
// Shape: { user_id, full_name, role, email }
export const SESSION_KEY = "mh_user";

// ── ROLE → HOME PAGE MAP ──────────────────────────────────────
export const ROLE_HOME = {
  patient:   "2_patient_dashboard.html",
  therapist: "therapist_dashboard.html",
  admin:     "admin_dashboard.html"
};
