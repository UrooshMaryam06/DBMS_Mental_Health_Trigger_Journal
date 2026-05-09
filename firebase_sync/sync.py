from db.postgres import get_connection
from db.firebase import get_firestore

def postgres_to_firebase():
    conn = get_connection()
    cur = conn.cursor()
    db = get_firestore()
    print("Starting PostgreSQL → Firebase backup...")

    # Sync Users
    cur.execute("SELECT user_id, firebase_uid, full_name, email, role FROM users")
    for row in cur.fetchall():
        db.collection("users").document(str(row[0])).set({
            "user_id": row[0],
            "firebase_uid": row[1] or "",
            "full_name": row[2],
            "email": row[3],
            "role": row[4]
        })
    print("Users synced")

    # Sync Trigger Logs (journal entries)
    cur.execute("SELECT log_id, user_id, mood_score, trigger_description, location, is_crisis, log_date FROM trigger_logs")
    for row in cur.fetchall():
        db.collection("trigger_logs").document(str(row[0])).set({
            "log_id": row[0],
            "user_id": row[1],
            "mood_score": row[2],
            "trigger_description": row[3],
            "location": row[4] or "",
            "is_crisis": row[5],
            "log_date": str(row[6])
        })
    print("Trigger logs synced")

    # Sync Crisis Alerts
    cur.execute("SELECT alert_id, log_id, patient_id, therapist_id, is_resolved FROM crisis_alerts")
    for row in cur.fetchall():
        db.collection("crisis_alerts").document(str(row[0])).set({
            "alert_id": row[0],
            "log_id": row[1],
            "patient_id": row[2],
            "therapist_id": row[3],
            "is_resolved": row[4]
        })
    print("Crisis alerts synced")

    # Sync Appointments
    cur.execute("SELECT appointment_id, patient_id, therapist_id, status, session_type FROM appointments")
    for row in cur.fetchall():
        db.collection("appointments").document(str(row[0])).set({
            "appointment_id": row[0],
            "patient_id": row[1],
            "therapist_id": row[2],
            "status": row[3],
            "session_type": row[4] or ""
        })
    print("Appointments synced")

    # Sync Notifications
    cur.execute("SELECT notification_id, user_id, notification_type, message, is_read FROM notifications")
    for row in cur.fetchall():
        db.collection("notifications").document(str(row[0])).set({
            "notification_id": row[0],
            "user_id": row[1],
            "notification_type": row[2],
            "message": row[3],
            "is_read": row[4]
        })
    print("Notifications synced")

    cur.close()
    conn.close()
    print("PostgreSQL → Firebase COMPLETE")


def firebase_to_postgres():
    db = get_firestore()
    conn = get_connection()
    cur = conn.cursor()
    print("Starting Firebase → PostgreSQL restore...")

    # Restore Users
    for doc in db.collection("users").stream():
        d = doc.to_dict()
        cur.execute("""
            INSERT INTO users (user_id, firebase_uid, full_name, email, role, date_of_birth)
            VALUES (%s, %s, %s, %s, %s, '2000-01-01')
            ON CONFLICT (user_id) DO UPDATE
            SET full_name = EXCLUDED.full_name,
                role = EXCLUDED.role
        """, (d["user_id"], d["firebase_uid"], d["full_name"], d["email"], d["role"]))
    print("Users restored")

    # Restore Trigger Logs
    for doc in db.collection("trigger_logs").stream():
        d = doc.to_dict()
        cur.execute("""
            INSERT INTO trigger_logs (log_id, user_id, mood_score, trigger_description, location, is_crisis)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (log_id) DO UPDATE
            SET mood_score = EXCLUDED.mood_score,
                trigger_description = EXCLUDED.trigger_description
        """, (d["log_id"], d["user_id"], d["mood_score"],
              d["trigger_description"], d["location"], d["is_crisis"]))
    print("Trigger logs restored")

    conn.commit()
    cur.close()
    conn.close()
    print("Firebase → PostgreSQL COMPLETE")