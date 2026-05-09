import psycopg2

def get_connection():
    return psycopg2.connect(
        host="localhost",
        database="mental_health_db_",
        user="postgres",
        password="NewStrongPassword123!",
        port="5432"
    )
