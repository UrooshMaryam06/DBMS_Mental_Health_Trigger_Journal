-- ============================================================
--  DBMS SEMESTER PROJECT — Mental Health Trigger Journal
--  FINAL VERSION — Firebase Auth + PostgreSQL Data
--  Database: PostgreSQL 15+
--  Run this in: pgAdmin / psql / Supabase SQL Editor
-- ============================================================

-- ============================================================
--  SETUP — use public schema for simplicity
-- ============================================================

SET search_path TO public;

-- ============================================================
--  TABLE 1: users
--  firebase_uid links each row to Firebase Auth user
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
    user_id           SERIAL          PRIMARY KEY,
    firebase_uid      VARCHAR(128)    UNIQUE,           -- Firebase Auth UID
    full_name         VARCHAR(100)    NOT NULL,
    email             VARCHAR(150)    NOT NULL UNIQUE,
    password_hash     VARCHAR(255),                     -- kept for reference only, auth is Firebase
    role              VARCHAR(20)     NOT NULL DEFAULT 'patient'
                                      CHECK (role IN ('patient', 'therapist', 'admin')),
    date_of_birth     DATE            NOT NULL,
    gender            VARCHAR(20),
    profile_audio_url TEXT,                             -- Firebase Storage URL
    profile_photo_url TEXT,                             -- Firebase Storage URL
    is_active         BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email        ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role         ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users(firebase_uid);
CREATE INDEX IF NOT EXISTS idx_users_active       ON users(is_active);


-- ============================================================
--  TABLE 2: coping_strategies
--  Created before trigger_logs because of FK dependency
-- ============================================================

CREATE TABLE IF NOT EXISTS coping_strategies (
    strategy_id      SERIAL          PRIMARY KEY,
    strategy_name    VARCHAR(100)    NOT NULL UNIQUE,
    category         VARCHAR(50)     CHECK (category IN ('Physical', 'Cognitive', 'Social', 'Creative')),
    description      TEXT,
    difficulty_level VARCHAR(20)     NOT NULL DEFAULT 'easy'
                                     CHECK (difficulty_level IN ('easy', 'moderate', 'hard')),
    recommended_for  TEXT,
    added_by         INTEGER         REFERENCES users(user_id) ON DELETE SET NULL,
    created_at       TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_coping_category ON coping_strategies(category);


-- ============================================================
--  TABLE 3: trigger_categories
-- ============================================================

CREATE TABLE IF NOT EXISTS trigger_categories (
    category_id   SERIAL          PRIMARY KEY,
    category_name VARCHAR(100)    NOT NULL UNIQUE,
    color_code    VARCHAR(10),
    icon_url      TEXT,
    description   TEXT
);


-- ============================================================
--  TABLE 4: trigger_logs
--  Core journal entry table
-- ============================================================

CREATE TABLE IF NOT EXISTS trigger_logs (
    log_id               SERIAL      PRIMARY KEY,
    user_id              INTEGER     NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    log_date             TIMESTAMP   NOT NULL DEFAULT NOW(),
    mood_score           INTEGER     NOT NULL CHECK (mood_score BETWEEN 1 AND 10),
    trigger_description  TEXT        NOT NULL,
    location             VARCHAR(150),
    people_involved      TEXT,
    physical_symptoms    TEXT,
    strategy_id          INTEGER     REFERENCES coping_strategies(strategy_id) ON DELETE SET NULL,
    audio_log_url        TEXT,                          -- Firebase Storage URL
    is_crisis            BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at           TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_logs_user_id ON trigger_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_logs_date    ON trigger_logs(log_date DESC);
CREATE INDEX IF NOT EXISTS idx_logs_crisis  ON trigger_logs(is_crisis) WHERE is_crisis = TRUE;
CREATE INDEX IF NOT EXISTS idx_logs_mood    ON trigger_logs(mood_score);


-- ============================================================
--  TABLE 5: log_category_map
--  Many-to-many: journal entries <-> categories
-- ============================================================

CREATE TABLE IF NOT EXISTS log_category_map (
    map_id      SERIAL    PRIMARY KEY,
    log_id      INTEGER   NOT NULL REFERENCES trigger_logs(log_id) ON DELETE CASCADE,
    category_id INTEGER   NOT NULL REFERENCES trigger_categories(category_id) ON DELETE CASCADE,
    UNIQUE (log_id, category_id)
);

CREATE INDEX IF NOT EXISTS idx_catmap_log      ON log_category_map(log_id);
CREATE INDEX IF NOT EXISTS idx_catmap_category ON log_category_map(category_id);


-- ============================================================
--  TABLE 6: media_attachments
--  Files stored in Firebase Storage, URLs saved here
-- ============================================================

CREATE TABLE IF NOT EXISTS media_attachments (
    media_id         SERIAL          PRIMARY KEY,
    log_id           INTEGER         NOT NULL REFERENCES trigger_logs(log_id) ON DELETE CASCADE,
    media_type       VARCHAR(20)     NOT NULL CHECK (media_type IN ('image', 'audio', 'video')),
    file_url         TEXT            NOT NULL,          -- Firebase Storage download URL
    file_size_kb     INTEGER         CHECK (file_size_kb > 0),
    storage_backend  VARCHAR(20)     NOT NULL DEFAULT 'firebase'
                                     CHECK (storage_backend IN ('postgres', 'firebase')),
    uploaded_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_media_log ON media_attachments(log_id);


-- ============================================================
--  TABLE 7: therapist_patient_link
-- ============================================================

CREATE TABLE IF NOT EXISTS therapist_patient_link (
    link_id      SERIAL      PRIMARY KEY,
    therapist_id INTEGER     NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    patient_id   INTEGER     NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    linked_at    TIMESTAMP   NOT NULL DEFAULT NOW(),
    is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
    notes        TEXT,
    UNIQUE (therapist_id, patient_id),
    CHECK (therapist_id <> patient_id)
);

CREATE INDEX IF NOT EXISTS idx_tpl_therapist ON therapist_patient_link(therapist_id);
CREATE INDEX IF NOT EXISTS idx_tpl_patient   ON therapist_patient_link(patient_id);
CREATE INDEX IF NOT EXISTS idx_tpl_active    ON therapist_patient_link(is_active);


-- ============================================================
--  TABLE 8: appointments
-- ============================================================

CREATE TABLE IF NOT EXISTS appointments (
    appointment_id SERIAL          PRIMARY KEY,
    patient_id     INTEGER         NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    therapist_id   INTEGER         NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    scheduled_at   TIMESTAMP       NOT NULL,
    duration_mins  INTEGER         NOT NULL DEFAULT 60 CHECK (duration_mins > 0),
    status         VARCHAR(20)     NOT NULL DEFAULT 'pending'
                                    CHECK (status IN ('pending','confirmed','completed','cancelled')),
    session_type   VARCHAR(20)     CHECK (session_type IN ('in-person','video','phone')),
    notes          TEXT,
    created_at     TIMESTAMP       NOT NULL DEFAULT NOW(),
    CHECK (patient_id <> therapist_id)
);

CREATE INDEX IF NOT EXISTS idx_appt_patient   ON appointments(patient_id);
CREATE INDEX IF NOT EXISTS idx_appt_therapist ON appointments(therapist_id);
CREATE INDEX IF NOT EXISTS idx_appt_scheduled ON appointments(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_appt_status    ON appointments(status);


-- ============================================================
--  TABLE 9: session_feedback
-- ============================================================

CREATE TABLE IF NOT EXISTS session_feedback (
    feedback_id    SERIAL      PRIMARY KEY,
    appointment_id INTEGER     NOT NULL UNIQUE REFERENCES appointments(appointment_id) ON DELETE CASCADE,
    patient_id     INTEGER     NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    therapist_id   INTEGER     NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    rating         INTEGER     NOT NULL CHECK (rating BETWEEN 1 AND 5),
    felt_heard     BOOLEAN,
    would_rebook   BOOLEAN,
    comments       TEXT,
    submitted_at   TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feedback_therapist ON session_feedback(therapist_id);
CREATE INDEX IF NOT EXISTS idx_feedback_patient   ON session_feedback(patient_id);


-- ============================================================
--  TABLE 10: crisis_alerts
--  Auto-populated by PostgreSQL trigger
-- ============================================================

CREATE TABLE IF NOT EXISTS crisis_alerts (
    alert_id        SERIAL      PRIMARY KEY,
    log_id          INTEGER     NOT NULL REFERENCES trigger_logs(log_id) ON DELETE CASCADE,
    patient_id      INTEGER     NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    therapist_id    INTEGER     REFERENCES users(user_id) ON DELETE SET NULL,
    alert_time      TIMESTAMP   NOT NULL DEFAULT NOW(),
    is_resolved     BOOLEAN     NOT NULL DEFAULT FALSE,
    resolution_note TEXT
);

CREATE INDEX IF NOT EXISTS idx_alerts_patient   ON crisis_alerts(patient_id);
CREATE INDEX IF NOT EXISTS idx_alerts_therapist ON crisis_alerts(therapist_id);
CREATE INDEX IF NOT EXISTS idx_alerts_resolved  ON crisis_alerts(is_resolved) WHERE is_resolved = FALSE;


-- ============================================================
--  TABLE 11: emergency_contacts
-- ============================================================

CREATE TABLE IF NOT EXISTS emergency_contacts (
    contact_id       SERIAL          PRIMARY KEY,
    patient_id       INTEGER         NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    full_name        VARCHAR(100)    NOT NULL,
    relationship     VARCHAR(50),
    phone_number     VARCHAR(20)     NOT NULL,
    email            VARCHAR(150),
    is_primary       BOOLEAN         NOT NULL DEFAULT FALSE,
    notify_on_crisis BOOLEAN         NOT NULL DEFAULT TRUE,
    added_at         TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ec_patient ON emergency_contacts(patient_id);


-- ============================================================
--  TABLE 12: notifications
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications (
    notification_id   SERIAL          PRIMARY KEY,
    user_id           INTEGER         NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    notification_type VARCHAR(50)     NOT NULL
                                       CHECK (notification_type IN (
                                           'appointment_reminder',
                                           'crisis_alert',
                                           'insight_ready',
                                           'feedback_request'
                                       )),
    reference_id      INTEGER,
    message           TEXT            NOT NULL,
    is_read           BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMP       NOT NULL DEFAULT NOW(),
    read_at           TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notif_user   ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notif_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notif_type   ON notifications(notification_type);


-- ============================================================
--  TABLE 13: ai_insights
--  Updated: added therapist_notes_summary + shared_with_patient
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_insights (
    insight_id              SERIAL          PRIMARY KEY,
    user_id                 INTEGER         NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    generated_at            TIMESTAMP       NOT NULL DEFAULT NOW(),
    pattern_found           TEXT            NOT NULL,
    therapist_notes_summary TEXT,
    dominant_category       INTEGER         REFERENCES trigger_categories(category_id) ON DELETE SET NULL,
    avg_mood_score          DECIMAL(4,2)    CHECK (avg_mood_score BETWEEN 1.00 AND 10.00),
    week_start              DATE            NOT NULL,
    week_end                DATE            NOT NULL,
    shared_with_patient     BOOLEAN         NOT NULL DEFAULT FALSE,
    CHECK (week_end > week_start)
);

CREATE INDEX IF NOT EXISTS idx_insights_user ON ai_insights(user_id);
CREATE INDEX IF NOT EXISTS idx_insights_week ON ai_insights(week_start, week_end);


-- ============================================================
--  TABLE 14: sync_log
--  Tracks Firebase <-> PostgreSQL sync operations
-- ============================================================

CREATE TABLE IF NOT EXISTS sync_log (
    sync_id        SERIAL          PRIMARY KEY,
    sync_type      VARCHAR(30)     NOT NULL
                                    CHECK (sync_type IN ('postgres_to_firebase','firebase_to_postgres')),
    records_synced INTEGER         DEFAULT 0 CHECK (records_synced >= 0),
    synced_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    triggered_by   INTEGER         REFERENCES users(user_id) ON DELETE SET NULL,
    status         VARCHAR(20)     NOT NULL CHECK (status IN ('success','partial','failed')),
    error_log      TEXT
);

CREATE INDEX IF NOT EXISTS idx_sync_status ON sync_log(status);
CREATE INDEX IF NOT EXISTS idx_sync_date   ON sync_log(synced_at DESC);


-- ============================================================
--  TRIGGER 1: auto_crisis_alert
--  Fires when is_crisis = TRUE on any journal entry
--  Auto-inserts into crisis_alerts + notifications
-- ============================================================

CREATE OR REPLACE FUNCTION fn_handle_crisis_entry()
RETURNS TRIGGER AS $$
DECLARE
    v_therapist_id  INTEGER;
    v_patient_name  VARCHAR(100);
BEGIN
    IF NEW.is_crisis = TRUE AND (OLD IS NULL OR OLD.is_crisis = FALSE) THEN

        SELECT therapist_id INTO v_therapist_id
        FROM therapist_patient_link
        WHERE patient_id = NEW.user_id
          AND is_active = TRUE
        LIMIT 1;

        SELECT full_name INTO v_patient_name
        FROM users WHERE user_id = NEW.user_id;

        INSERT INTO crisis_alerts (log_id, patient_id, therapist_id, alert_time)
        VALUES (NEW.log_id, NEW.user_id, v_therapist_id, NOW());

        IF v_therapist_id IS NOT NULL THEN
            INSERT INTO notifications (user_id, notification_type, reference_id, message)
            VALUES (
                v_therapist_id,
                'crisis_alert',
                NEW.log_id,
                'CRISIS: ' || v_patient_name || ' has logged a crisis entry. Immediate review required.'
            );
        END IF;

        INSERT INTO notifications (user_id, notification_type, reference_id, message)
        VALUES (
            NEW.user_id,
            'crisis_alert',
            NEW.log_id,
            'Your therapist has been notified. You are not alone — help is on the way.'
        );

    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_crisis_alert ON trigger_logs;
CREATE TRIGGER trg_crisis_alert
AFTER INSERT OR UPDATE OF is_crisis ON trigger_logs
FOR EACH ROW
EXECUTE FUNCTION fn_handle_crisis_entry();


-- ============================================================
--  TRIGGER 2: appointment_feedback_request
--  Fires when appointment status becomes 'completed'
-- ============================================================

CREATE OR REPLACE FUNCTION fn_request_session_feedback()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND OLD.status <> 'completed' THEN
        INSERT INTO notifications (user_id, notification_type, reference_id, message)
        VALUES (
            NEW.patient_id,
            'feedback_request',
            NEW.appointment_id,
            'Your session is complete. Please take a moment to rate your experience.'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_feedback_request ON appointments;
CREATE TRIGGER trg_feedback_request
AFTER UPDATE OF status ON appointments
FOR EACH ROW
EXECUTE FUNCTION fn_request_session_feedback();


-- ============================================================
--  TRIGGER 3: soft_delete_user
--  When user is deactivated, cancel their pending appointments
-- ============================================================

CREATE OR REPLACE FUNCTION fn_soft_delete_user()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_active = FALSE AND OLD.is_active = TRUE THEN
        UPDATE appointments
        SET status = 'cancelled'
        WHERE (patient_id = NEW.user_id OR therapist_id = NEW.user_id)
          AND status IN ('pending', 'confirmed');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_soft_delete_user ON users;
CREATE TRIGGER trg_soft_delete_user
AFTER UPDATE OF is_active ON users
FOR EACH ROW
EXECUTE FUNCTION fn_soft_delete_user();


-- ============================================================
--  STORED PROCEDURE: generate_weekly_insight
--  Called when therapist clicks "Generate Report"
--  Computes all stats, pulls therapist notes, saves to ai_insights
-- ============================================================

CREATE OR REPLACE PROCEDURE generate_weekly_insight(
    p_patient_id  INTEGER,
    p_week_start  DATE,
    p_week_end    DATE
)
LANGUAGE plpgsql AS $$
DECLARE
    v_avg_mood          DECIMAL(4,2);
    v_entry_count       INTEGER;
    v_crisis_count      INTEGER;
    v_dominant_cat_id   INTEGER;
    v_dominant_cat_name VARCHAR(100);
    v_pattern_text      TEXT;
    v_therapist_notes   TEXT;
    v_therapist_id      INTEGER;
    v_appt_notes        TEXT;
BEGIN
    -- Mood stats for the week
    SELECT
        ROUND(AVG(mood_score)::NUMERIC, 2),
        COUNT(*),
        SUM(CASE WHEN is_crisis THEN 1 ELSE 0 END)
    INTO v_avg_mood, v_entry_count, v_crisis_count
    FROM trigger_logs
    WHERE user_id = p_patient_id
      AND log_date >= p_week_start
      AND log_date < (p_week_end + INTERVAL '1 day');

    -- Dominant trigger category
    SELECT lcm.category_id, tc.category_name
    INTO v_dominant_cat_id, v_dominant_cat_name
    FROM log_category_map lcm
    JOIN trigger_logs tl       ON tl.log_id = lcm.log_id
    JOIN trigger_categories tc ON tc.category_id = lcm.category_id
    WHERE tl.user_id = p_patient_id
      AND tl.log_date >= p_week_start
      AND tl.log_date < (p_week_end + INTERVAL '1 day')
    GROUP BY lcm.category_id, tc.category_name
    ORDER BY COUNT(*) DESC
    LIMIT 1;

    -- Therapist general notes
    SELECT therapist_id, notes
    INTO v_therapist_id, v_therapist_notes
    FROM therapist_patient_link
    WHERE patient_id = p_patient_id AND is_active = TRUE
    LIMIT 1;

    -- Appointment notes from this week's sessions
    SELECT STRING_AGG(notes, ' | ')
    INTO v_appt_notes
    FROM appointments
    WHERE patient_id   = p_patient_id
      AND therapist_id = v_therapist_id
      AND scheduled_at >= p_week_start
      AND scheduled_at < (p_week_end + INTERVAL '1 day')
      AND status = 'completed'
      AND notes IS NOT NULL;

    -- Compile therapist notes summary
    v_therapist_notes := COALESCE(v_therapist_notes, '') ||
                         CASE WHEN v_appt_notes IS NOT NULL
                              THEN ' | Session notes: ' || v_appt_notes
                              ELSE '' END;

    -- Build pattern summary text (Claude API will enhance this)
    v_pattern_text := FORMAT(
        'Week %s to %s | Entries: %s | Avg mood: %s/10 | Crisis entries: %s | Dominant trigger: %s',
        p_week_start,
        p_week_end,
        COALESCE(v_entry_count, 0),
        COALESCE(v_avg_mood, 0),
        COALESCE(v_crisis_count, 0),
        COALESCE(v_dominant_cat_name, 'None recorded')
    );

    -- Save insight record
    INSERT INTO ai_insights (
        user_id,
        pattern_found,
        therapist_notes_summary,
        dominant_category,
        avg_mood_score,
        week_start,
        week_end,
        shared_with_patient
    ) VALUES (
        p_patient_id,
        v_pattern_text,
        NULLIF(TRIM(v_therapist_notes), ''),
        v_dominant_cat_id,
        v_avg_mood,
        p_week_start,
        p_week_end,
        FALSE
    );

    -- Notify therapist
    IF v_therapist_id IS NOT NULL THEN
        INSERT INTO notifications (user_id, notification_type, reference_id, message)
        VALUES (
            v_therapist_id,
            'insight_ready',
            p_patient_id,
            'Weekly insight report generated for patient. Review and share when ready.'
        );
    END IF;

END;
$$;


-- ============================================================
--  VIEW 1: patient_weekly_summary
--  Powers the patient dashboard mood chart
-- ============================================================

CREATE OR REPLACE VIEW patient_weekly_summary AS
SELECT
    tl.user_id,
    u.full_name,
    DATE_TRUNC('week', tl.log_date)::DATE          AS week_start,
    COUNT(tl.log_id)                                AS total_entries,
    ROUND(AVG(tl.mood_score)::NUMERIC, 2)           AS avg_mood,
    MIN(tl.mood_score)                              AS lowest_mood,
    MAX(tl.mood_score)                              AS highest_mood,
    SUM(CASE WHEN tl.is_crisis THEN 1 ELSE 0 END)  AS crisis_count
FROM trigger_logs tl
JOIN users u ON u.user_id = tl.user_id
GROUP BY tl.user_id, u.full_name, DATE_TRUNC('week', tl.log_date)::DATE
ORDER BY week_start DESC;


-- ============================================================
--  VIEW 2: therapist_patient_overview
--  Powers the therapist dashboard patient list
-- ============================================================

CREATE OR REPLACE VIEW therapist_patient_overview AS
SELECT
    tpl.therapist_id,
    t.full_name                                         AS therapist_name,
    tpl.patient_id,
    p.full_name                                         AS patient_name,
    p.email                                             AS patient_email,
    tpl.linked_at,
    ROUND(AVG(tl.mood_score)::NUMERIC, 2)               AS avg_mood_last_30_days,
    MAX(tl.log_date)                                    AS last_entry_date,
    SUM(CASE WHEN tl.is_crisis THEN 1 ELSE 0 END)      AS crisis_count_last_30_days,
    EXISTS (
        SELECT 1 FROM crisis_alerts ca
        WHERE ca.patient_id = tpl.patient_id
          AND ca.is_resolved = FALSE
    )                                                    AS has_unresolved_crisis
FROM therapist_patient_link tpl
JOIN users t ON t.user_id = tpl.therapist_id
JOIN users p ON p.user_id = tpl.patient_id
LEFT JOIN trigger_logs tl
       ON tl.user_id = tpl.patient_id
      AND tl.log_date >= NOW() - INTERVAL '30 days'
WHERE tpl.is_active = TRUE
GROUP BY tpl.therapist_id, t.full_name, tpl.patient_id, p.full_name, p.email, tpl.linked_at;


-- ============================================================
--  VIEW 3: unread_notifications_view
-- ============================================================

CREATE OR REPLACE VIEW unread_notifications_view AS
SELECT
    n.notification_id,
    n.user_id,
    u.full_name         AS recipient_name,
    n.notification_type,
    n.message,
    n.reference_id,
    n.created_at
FROM notifications n
JOIN users u ON u.user_id = n.user_id
WHERE n.is_read = FALSE
ORDER BY n.created_at DESC;


-- ============================================================
--  VIEW 4: crisis_dashboard_view
--  Therapist sees all unresolved crisis alerts with detail
-- ============================================================

CREATE OR REPLACE VIEW crisis_dashboard_view AS
SELECT
    ca.alert_id,
    ca.alert_time,
    ca.is_resolved,
    ca.resolution_note,
    p.full_name         AS patient_name,
    p.email             AS patient_email,
    tl.mood_score,
    tl.trigger_description,
    tl.location,
    tl.physical_symptoms,
    tl.log_date
FROM crisis_alerts ca
JOIN users p          ON p.user_id = ca.patient_id
JOIN trigger_logs tl  ON tl.log_id = ca.log_id
WHERE ca.is_resolved = FALSE
ORDER BY ca.alert_time DESC;


-- ============================================================
--  SEED DATA
--  Ready-to-use demo accounts for your presentation
--  NOTE: In real app, Firebase Auth creates the user first,
--        then firebase_uid gets stored here
-- ============================================================

INSERT INTO users (firebase_uid, full_name, email, role, date_of_birth, gender) VALUES
('firebase-uid-admin-001',     'Admin User',     'admin@mhjournal.com',  'admin',     '1985-01-01', 'Other'),
('firebase-uid-therapist-001', 'Dr. Imran Khan', 'imran@mhjournal.com',  'therapist', '1980-05-15', 'Male'),
('firebase-uid-patient-001',   'Sara Ahmed',     'sara@mhjournal.com',   'patient',   '1998-03-22', 'Female'),
('firebase-uid-patient-002',   'Ali Hassan',     'ali@mhjournal.com',    'patient',   '2000-07-10', 'Male')
ON CONFLICT (email) DO NOTHING;

INSERT INTO trigger_categories (category_name, color_code, description) VALUES
('Work',     '#378ADD', 'Work-related stress and pressure'),
('Family',   '#1D9E75', 'Family conflicts and relationships'),
('Finance',  '#EF9F27', 'Financial stress and money concerns'),
('Health',   '#D4537E', 'Physical or mental health concerns'),
('Social',   '#7F77DD', 'Social situations and relationships'),
('Academic', '#639922', 'Study and academic pressure')
ON CONFLICT (category_name) DO NOTHING;

INSERT INTO coping_strategies (strategy_name, category, description, difficulty_level, recommended_for, added_by) VALUES
('Deep Breathing',         'Physical',  'Slow diaphragmatic breathing to calm the nervous system',  'easy',     'anxiety, panic attacks',       1),
('Journaling',             'Cognitive', 'Writing thoughts and feelings to process emotions',         'easy',     'low mood, stress',             1),
('Light Exercise',         'Physical',  'Walking, stretching, or yoga for 20-30 minutes',           'easy',     'anxiety, low mood',            1),
('Calling a Friend',       'Social',    'Reaching out to a trusted person for support',             'easy',     'isolation, low mood',          1),
('Grounding (5-4-3-2-1)', 'Cognitive', '5 things you see, 4 touch, 3 hear, 2 smell, 1 taste',      'easy',     'panic attacks, dissociation',  1),
('Progressive Relaxation', 'Physical',  'Systematically tensing and releasing muscle groups',       'moderate', 'tension, anxiety',             1)
ON CONFLICT (strategy_name) DO NOTHING;

INSERT INTO therapist_patient_link (therapist_id, patient_id, notes) VALUES
(2, 3, 'Sara presents with work-related anxiety and family tension. Making good progress with coping strategies.'),
(2, 4, 'Ali is dealing with academic pressure and social withdrawal. Needs consistent check-ins.')
ON CONFLICT (therapist_id, patient_id) DO NOTHING;

INSERT INTO trigger_logs (user_id, log_date, mood_score, trigger_description, location, people_involved, physical_symptoms, strategy_id, is_crisis) VALUES
(3, NOW() - INTERVAL '13 days', 6, 'Stressful team meeting, felt ignored by manager.',        'Office',      'Manager, colleagues', 'Headache',              1, FALSE),
(3, NOW() - INTERVAL '12 days', 5, 'Argument with sister about money.',                       'Home',        'Sister',              'Chest tightness',       2, FALSE),
(3, NOW() - INTERVAL '11 days', 7, 'Completed big project, team praised my work.',            'Office',      'Team',                NULL,                    NULL, FALSE),
(3, NOW() - INTERVAL '10 days', 4, 'Unexpected bill arrived, anxious about finances.',        'Home',        'Alone',               'Nausea, tight chest',   1, FALSE),
(3, NOW() - INTERVAL '8 days',  8, 'Great therapy session, felt heard and understood.',       'Clinic',      'Dr. Imran',           NULL,                    NULL, FALSE),
(3, NOW() - INTERVAL '6 days',  5, 'Skipped lunch due to workload, felt overwhelmed.',        'Office',      'Colleagues',          'Fatigue, headache',     3, FALSE),
(3, NOW() - INTERVAL '3 days',  3, 'Panic attack during meeting. Could not breathe.',         'Office',      'Manager',             'Chest pain, dizziness', 1, TRUE),
(3, NOW() - INTERVAL '2 days',  5, 'Talked to friend Hina, feeling slightly better.',         'Cafe',        'Friend Hina',         'Fatigue',               4, FALSE),
(3, NOW() - INTERVAL '1 day',   6, 'Slept well, gentle morning walk helped my mood.',         'Neighborhood','Alone',               NULL,                    3, FALSE),
(4, NOW() - INTERVAL '5 days',  4, 'Failed exam, feeling hopeless about semester.',           'University',  'Alone',               'Headache, fatigue',     2, FALSE),
(4, NOW() - INTERVAL '2 days',  6, 'Study group helped, feel more confident now.',            'Library',     'Study group',         NULL,                    3, FALSE)
ON CONFLICT DO NOTHING;

INSERT INTO log_category_map (log_id, category_id) VALUES
(1, 1),(2, 2),(2, 3),(3, 1),(4, 3),(6, 1),(7, 1),(7, 4),(8, 2),(9, 1),(10, 6),(11, 6)
ON CONFLICT DO NOTHING;

INSERT INTO appointments (patient_id, therapist_id, scheduled_at, duration_mins, status, session_type, notes) VALUES
(3, 2, NOW() + INTERVAL '2 days',  60, 'confirmed', 'video',      'Follow-up after crisis entry. Assess coping strategies.'),
(3, 2, NOW() - INTERVAL '8 days',  60, 'completed', 'in-person',  'Initial session. Patient opened up about work stress.'),
(4, 2, NOW() + INTERVAL '4 days',  60, 'pending',   'video',      'Check-in after exam failure.')
ON CONFLICT DO NOTHING;

INSERT INTO session_feedback (appointment_id, patient_id, therapist_id, rating, felt_heard, would_rebook, comments) VALUES
(2, 3, 2, 5, TRUE, TRUE, 'Dr. Imran was very understanding. I felt less alone after this session.')
ON CONFLICT DO NOTHING;

INSERT INTO emergency_contacts (patient_id, full_name, relationship, phone_number, email, is_primary, notify_on_crisis) VALUES
(3, 'Fatima Ahmed', 'Mother', '+92-300-1234567', 'fatima@email.com', TRUE,  TRUE),
(3, 'Hina Malik',   'Friend', '+92-321-9876543', 'hina@email.com',   FALSE, TRUE),
(4, 'Hassan Ali',   'Father', '+92-333-9876543', 'hassan@email.com', TRUE,  TRUE)
ON CONFLICT DO NOTHING;


-- ============================================================
--  DEMO QUERIES — uncomment and run during presentation
-- ============================================================

-- 1. All journal entries for Sara with categories and coping strategy
-- SELECT tl.log_id, tl.log_date, tl.mood_score, tl.trigger_description,
--        tl.is_crisis, tc.category_name, cs.strategy_name
-- FROM trigger_logs tl
-- LEFT JOIN log_category_map lcm  ON lcm.log_id = tl.log_id
-- LEFT JOIN trigger_categories tc ON tc.category_id = lcm.category_id
-- LEFT JOIN coping_strategies cs  ON cs.strategy_id = tl.strategy_id
-- WHERE tl.user_id = 3
-- ORDER BY tl.log_date DESC;

-- 2. All unresolved crisis alerts (therapist dashboard)
-- SELECT * FROM crisis_dashboard_view;

-- 3. Therapist overview of all patients
-- SELECT * FROM therapist_patient_overview WHERE therapist_id = 2;

-- 4. Generate weekly insight report for Sara
-- CALL generate_weekly_insight(3, CURRENT_DATE - 7, CURRENT_DATE);

-- 5. View generated insights
-- SELECT * FROM ai_insights WHERE user_id = 3 ORDER BY generated_at DESC;

-- 6. Patient mood summary by week
-- SELECT * FROM patient_weekly_summary WHERE user_id = 3;

-- 7. All unread notifications
-- SELECT * FROM unread_notifications_view;

-- 8. Verify crisis trigger fired automatically
-- SELECT * FROM crisis_alerts;
-- SELECT * FROM notifications WHERE notification_type = 'crisis_alert';

-- ============================================================
--  END OF SCHEMA — FINAL VERSION
-- ============================================================