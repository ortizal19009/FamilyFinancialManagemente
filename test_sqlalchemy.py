import os
from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv('backend/.env')
db_url = os.environ.get('DATABASE_URL')
print(f"URL: {db_url}")

try:
    engine = create_engine(db_url)
    with engine.connect() as conn:
        print("SQLAlchemy conectó exitosamente!")
except Exception as e:
    print(f"Error SQLAlchemy: {e}")
