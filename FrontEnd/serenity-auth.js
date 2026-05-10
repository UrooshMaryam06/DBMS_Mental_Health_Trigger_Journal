// ============================================================
//  serenity-auth.js
//  Import this in every protected page with type="module".
//
//  What it does:
//   1. Reads mh_user from localStorage
//   2. If missing → redirect to login
//   3. If role !== "patient" → redirect to login (wrong portal)
//   4. Exposes getSession(), getInitials(), getGreeting()
//   5. Auto-populates sidebar name / initials / role pill
//   6. Wires up the Sign Out button
// ============================================================

import { SESSION_KEY, ROLE_HOME } from "./serenity-config.js";

// ── 1. READ & VALIDATE SESSION ───────────────────────────────
function loadSession() {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const session = JSON.parse(raw);
    if (!session.user_id || !session.role) return null;
    return session;
  } catch {
    return null;
  }
}

const session = loadSession();

// ── 2. GUARD: redirect if not logged in or wrong role ────────
(function guard() {
  if (!session) {
    window.location.replace("1_login_register.html");
    return;
  }
  // Each portal only accepts its own role
  const allowedRole = document.documentElement.dataset.portalRole || "patient";
  if (session.role !== allowedRole) {
    // Send them to their actual home page
    const home = ROLE_HOME[session.role] || "1_login_register.html";
    window.location.replace(home);
  }
})();

// ── 3. HELPERS ────────────────────────────────────────────────
export function getSession() { return session; }

export function getInitials(name = "") {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map(w => w[0].toUpperCase())
    .join("");
}

export function getGreeting() {
  const h = new Date().getHours();
  if (h < 12) return "Good morning";
  if (h < 17) return "Good afternoon";
  return "Good evening";
}

export function formatDate(date = new Date()) {
  return date.toLocaleDateString("en-US", {
    weekday: "long", year: "numeric",
    month: "long", day: "numeric"
  });
}

// ── 4. AUTO-POPULATE SIDEBAR UI ──────────────────────────────
document.addEventListener("DOMContentLoaded", () => {
  if (!session) return;

  const firstName  = session.full_name?.split(" ")[0] || "There";
  const initials   = getInitials(session.full_name);
  const roleLabel  = session.role.charAt(0).toUpperCase() + session.role.slice(1);

  // Sidebar avatar initials
  const sbAvi = document.getElementById("sbAvatarInitials");
  if (sbAvi) sbAvi.textContent = initials;

  // Sidebar display name
  const sbName = document.getElementById("sbUname");
  if (sbName) sbName.textContent = session.full_name || "User";

  // Sidebar role label (if element exists)
  const sbRole = document.getElementById("sbRoleLabel");
  if (sbRole) sbRole.textContent = roleLabel;

  // Topbar greeting
  const tbGreeting = document.getElementById("tbGreeting");
  if (tbGreeting) tbGreeting.textContent = `${getGreeting()}, ${firstName} 🌸`;

  // Topbar date line
  const tbDate = document.getElementById("tbDate");
  if (tbDate) tbDate.textContent = formatDate();

  // Profile hero (patient_profile.html)
  const heroName = document.getElementById("heroName");
  if (heroName) heroName.textContent = session.full_name || "User";
  const heroInitials = document.getElementById("heroInitials");
  if (heroInitials) heroInitials.textContent = initials;
  const heroEmail = document.getElementById("heroEmail");
  if (heroEmail) heroEmail.textContent = session.email || "";

  // Pre-fill form fields on profile page
  const firstNameField = document.getElementById("firstName");
  const lastNameField  = document.getElementById("lastName");
  if (firstNameField && lastNameField) {
    const parts = (session.full_name || "").split(" ");
    firstNameField.value = parts[0] || "";
    lastNameField.value  = parts.slice(1).join(" ") || "";
  }
  const emailField = document.getElementById("emailField");
  if (emailField) emailField.value = session.email || "";

  // ── SIGN OUT button ──────────────────────────────────────
  document.querySelectorAll("[data-action='signout']").forEach(el => {
    el.addEventListener("click", (e) => {
      e.preventDefault();
      signOut();
    });
  });
});

// ── 5. SIGN OUT ───────────────────────────────────────────────
export function signOut() {
  localStorage.removeItem(SESSION_KEY);
  // Also clear theme if desired (optional — comment out to keep theme):
  // localStorage.removeItem("serenity_theme");
  window.location.replace("1_login_register.html");
}

// ── 6. SUPABASE FETCH HELPER ─────────────────────────────────
// Lightweight wrapper so pages don't need to repeat headers.
// Usage: const data = await supaFetch("trigger_logs?user_id=eq."+uid);
import { SUPABASE_URL, SUPABASE_ANON } from "./serenity-config.js";

export async function supaFetch(endpoint, options = {}) {
  const url = `${SUPABASE_URL}/rest/v1/${endpoint}`;
  const res = await fetch(url, {
    headers: {
      "apikey":        SUPABASE_ANON,
      "Authorization": `Bearer ${SUPABASE_ANON}`,
      "Content-Type":  "application/json",
      "Prefer":        "return=representation",
      ...(options.headers || {})
    },
    ...options
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.message || `Supabase error ${res.status}`);
  }
  return res.json();
}

// ── 7. NOTIFICATION LOADER ────────────────────────────────────
// Fetches unread notifications for current user from Supabase.
// Returns array; falls back to [] on error.
export async function loadNotifications() {
  if (!session) return [];
  try {
    return await supaFetch(
      `notifications?user_id=eq.${session.user_id}&order=created_at.desc&limit=10`
    );
  } catch (e) {
    console.warn("Notifications fetch failed:", e.message);
    return [];
  }
}
