-- ============================================================
--  SERENITY — SUPABASE RLS POLICIES
--  Run this entire file in:
--  Supabase Dashboard → SQL Editor → New Query → Paste → Run
-- ============================================================

-- ── STEP 1: Enable RLS on all tables
ALTER TABLE users                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE trigger_logs           ENABLE ROW LEVEL SECURITY;
ALTER TABLE crisis_alerts          ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments           ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications          ENABLE ROW LEVEL SECURITY;
ALTER TABLE therapist_patient_link ENABLE ROW LEVEL SECURITY;
ALTER TABLE coping_strategies      ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_insights            ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_feedback       ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_contacts     ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_attachments      ENABLE ROW LEVEL SECURITY;

-- ── STEP 2: DROP old conflicting policies
DROP POLICY IF EXISTS "users_select"       ON users;
DROP POLICY IF EXISTS "users_insert"       ON users;
DROP POLICY IF EXISTS "users_update"       ON users;
DROP POLICY IF EXISTS "logs_select"        ON trigger_logs;
DROP POLICY IF EXISTS "logs_insert"        ON trigger_logs;
DROP POLICY IF EXISTS "crisis_select"      ON crisis_alerts;
DROP POLICY IF EXISTS "crisis_insert"      ON crisis_alerts;
DROP POLICY IF EXISTS "appts_select"       ON appointments;
DROP POLICY IF EXISTS "appts_insert"       ON appointments;
DROP POLICY IF EXISTS "appts_update"       ON appointments;
DROP POLICY IF EXISTS "notifs_select"      ON notifications;
DROP POLICY IF EXISTS "notifs_update"      ON notifications;
DROP POLICY IF EXISTS "tpl_select"         ON therapist_patient_link;
DROP POLICY IF EXISTS "coping_select"      ON coping_strategies;
DROP POLICY IF EXISTS "insights_select"    ON ai_insights;
DROP POLICY IF EXISTS "feedback_select"    ON session_feedback;
DROP POLICY IF EXISTS "feedback_insert"    ON session_feedback;
DROP POLICY IF EXISTS "emergency_select"   ON emergency_contacts;
DROP POLICY IF EXISTS "media_select"       ON media_attachments;

-- ── STEP 3: USERS table
CREATE POLICY "users_select" ON users
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "users_insert" ON users
  FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "users_update" ON users
  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

-- ── STEP 4: TRIGGER_LOGS table
CREATE POLICY "logs_select" ON trigger_logs
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "logs_insert" ON trigger_logs
  FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "logs_update" ON trigger_logs
  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

-- ── STEP 5: CRISIS_ALERTS table
CREATE POLICY "crisis_select" ON crisis_alerts
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "crisis_insert" ON crisis_alerts
  FOR INSERT TO anon, authenticated WITH CHECK (true);

-- ── STEP 6: APPOINTMENTS table
CREATE POLICY "appts_select" ON appointments
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "appts_insert" ON appointments
  FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "appts_update" ON appointments
  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

-- ── STEP 7: NOTIFICATIONS table
CREATE POLICY "notifs_select" ON notifications
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "notifs_update" ON notifications
  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

-- ── STEP 8: THERAPIST_PATIENT_LINK table
CREATE POLICY "tpl_select" ON therapist_patient_link
  FOR SELECT TO anon, authenticated USING (true);

-- ── STEP 9: Other tables
CREATE POLICY "coping_select" ON coping_strategies
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "insights_select" ON ai_insights
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "feedback_select" ON session_feedback
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "feedback_insert" ON session_feedback
  FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "emergency_select" ON emergency_contacts
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "media_select" ON media_attachments
  FOR SELECT TO anon, authenticated USING (true);

-- ── STEP 10: INSERT SEED DATA
DO $$
DECLARE
  sara_id   INT;
  imran_id  INT;
BEGIN
  SELECT user_id INTO sara_id  FROM users WHERE email = 'sara@mhjournal.com'  LIMIT 1;
  SELECT user_id INTO imran_id FROM users WHERE email = 'imran@mhjournal.com' LIMIT 1;

  IF sara_id IS NULL OR imran_id IS NULL THEN
    RAISE NOTICE 'Demo users not found. Log in with each account first, then re-run this file.';
    RETURN;
  END IF;

  -- Link Sara to Imran as therapist
  IF NOT EXISTS (SELECT 1 FROM therapist_patient_link WHERE patient_id=sara_id AND therapist_id=imran_id) THEN
    INSERT INTO therapist_patient_link(therapist_id, patient_id, linked_date, is_active)
    VALUES (imran_id, sara_id, NOW(), true);
    RAISE NOTICE 'Sara linked to Imran';
  END IF;

  -- Seed 14 days of trigger logs for Sara
  INSERT INTO trigger_logs(user_id, mood_score, trigger_description, is_crisis, log_date)
  SELECT sara_id, mood, desc_text, is_c, NOW() - (n || ' days')::INTERVAL
  FROM (VALUES
    (0,  7, 'Had a productive day at university. Felt focused and calm.',          false),
    (1,  5, 'Work deadline stress. Felt anxious about the project submission.',    false),
    (2,  8, 'Family dinner was wonderful. Felt grateful and connected.',           false),
    (3,  4, 'Could not sleep well. Health concerns about headaches.',             false),
    (4,  6, 'Journaling helped me process the week. Feeling better.',             false),
    (5,  3, 'Family argument was very upsetting. Felt overwhelmed.',              false),
    (6,  7, 'Academic progress review went well. Proud of myself.',               false),
    (7,  5, 'Finance worries about semester fees. Stressed.',                     false),
    (8,  9, 'Best day in weeks. Friends and family time was healing.',            false),
    (9,  2, 'Work pressure and academic deadline clashed. Crisis moment.',        true),
    (10, 6, 'Therapist session helped a lot. Feeling hopeful.',                   false),
    (11, 7, 'Used breathing exercises during work stress. It worked!',            false),
    (12, 5, 'Health appointment today. Waiting for results nervously.',           false),
    (13, 8, 'Completed journal exercise Dr. Khan recommended. Proud.',            false)
  ) AS t(n, mood, desc_text, is_c)
  ON CONFLICT DO NOTHING;

  -- Seed appointments for Sara
  -- session_type: 'in-person' | 'video' | 'phone'
  -- status:       'pending' | 'confirmed' | 'completed' | 'cancelled'
  INSERT INTO appointments(patient_id, therapist_id, scheduled_at, session_type, status, notes)
  VALUES
    (sara_id, imran_id, NOW() + INTERVAL '3 days',  'video',     'confirmed', 'Weekly check-in'),
    (sara_id, imran_id, NOW() + INTERVAL '10 days', 'video',     'confirmed', 'Follow-up on coping strategies'),
    (sara_id, imran_id, NOW() + INTERVAL '17 days', 'in-person', 'pending',   'Monthly review session')
  ON CONFLICT DO NOTHING;

  -- Seed notifications for Sara
  -- notification_type: 'appointment_reminder' | 'crisis_alert' | 'insight_ready' | 'feedback_request'
  -- columns: user_id, notification_type, reference_id, message, is_read, created_at
  INSERT INTO notifications(user_id, notification_type, reference_id, message, is_read, created_at)
  VALUES
    (sara_id, 'appointment_reminder', NULL, 'Your session with Dr. Khan is in 3 days',        false, NOW() - INTERVAL '2 hours'),
    (sara_id, 'insight_ready',        NULL, 'You have logged for 5 days in a row!',           false, NOW() - INTERVAL '1 day'),
    (sara_id, 'feedback_request',     NULL, 'A new breathing exercise has been added for you', true,  NOW() - INTERVAL '3 days')
  ON CONFLICT DO NOTHING;

  RAISE NOTICE 'Seed data inserted successfully for Sara (user_id: %)', sara_id;
END $$;
