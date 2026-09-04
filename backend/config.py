import os
import secrets
from datetime import timedelta
from dotenv import load_dotenv

# Buscar el archivo .env en la carpeta actual y en el raíz
basedir = os.path.abspath(os.path.dirname(__file__))
load_dotenv(os.path.join(basedir, '.env'))
load_dotenv(os.path.join(os.path.dirname(basedir), '.env'))

INSECURE_DEFAULT_SECRET_KEY = 'dev-key-very-secret'
INSECURE_DEFAULT_JWT_SECRET_KEY = 'jwt-dev-key'

APP_ENV = (os.environ.get('APP_ENV') or 'development').strip().lower()
IS_PRODUCTION = APP_ENV == 'production'


def _dev_fallback(key, insecure_default):
    if IS_PRODUCTION:
        return os.environ.get(key)
    value = os.environ.get(key)
    if not value or value == insecure_default:
        return secrets.token_hex(32)
    return value


class Config:
    SECRET_KEY = _dev_fallback('SECRET_KEY', INSECURE_DEFAULT_SECRET_KEY)
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or \
        'postgresql+psycopg2://postgres:12345@localhost/FFM_DB'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JWT_SECRET_KEY = _dev_fallback('JWT_SECRET_KEY', INSECURE_DEFAULT_JWT_SECRET_KEY)
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=1)
    JWT_HEADER_NAME = 'Authorization'
    JWT_HEADER_TYPE = 'Bearer'
    JWT_TOKEN_LOCATION = ['headers']
    UPLOAD_FOLDER = os.environ.get('UPLOAD_FOLDER') or os.path.join(basedir, 'uploads')
    MAX_CONTENT_LENGTH = 10 * 1024 * 1024
    APP_ENV = APP_ENV
    DEFAULT_ADMIN_ENABLED = os.environ.get('DEFAULT_ADMIN_ENABLED', 'true').lower() == 'true'
    DEFAULT_ADMIN_NAME = os.environ.get('DEFAULT_ADMIN_NAME') or 'Administrador'
    DEFAULT_ADMIN_EMAIL = os.environ.get('DEFAULT_ADMIN_EMAIL') or 'admin@localhost.com'
    DEFAULT_ADMIN_PASSWORD = os.environ.get('DEFAULT_ADMIN_PASSWORD') or 'admin'

    @classmethod
    def validate_required_secrets(cls):
        if not IS_PRODUCTION:
            return
        missing = []
        if not cls.SECRET_KEY:
            missing.append('SECRET_KEY')
        if not cls.JWT_SECRET_KEY:
            missing.append('JWT_SECRET_KEY')
        if missing:
            raise RuntimeError(
                'Configuración de producción inválida. Faltan: '
                + ', '.join(missing)
                + '. Define valores seguros en el .env de producción.'
            )
