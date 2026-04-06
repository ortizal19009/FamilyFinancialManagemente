import os
from dotenv import load_dotenv
import psycopg

# Intentar cargar desde backend/
load_dotenv('backend/.env')
# Si no está, cargar desde root
load_dotenv()

db_url = os.environ.get('DATABASE_URL')
print(f"DATABASE_URL: {db_url}")

try:
    conn = psycopg.connect(db_url)
    print("Conexión exitosa a la base de datos!")
    conn.close()
except Exception as e:
    print(f"Error conectando: {e}")
