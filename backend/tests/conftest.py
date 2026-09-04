import os

os.environ['DATABASE_URL'] = 'sqlite:///:memory:'
os.environ['APP_ENV'] = 'development'

import pytest
from sqlalchemy import inspect

from backend.app import create_app
from backend.models import User, db


@pytest.fixture(scope='session')
def app():
    application = create_app()
    with application.app_context():
        db.create_all()
        yield application


@pytest.fixture(autouse=True)
def clean_tables(app):
    with app.app_context():
        for table in reversed(inspect(db.engine).get_table_names()):
            db.session.execute(db.text(f'DELETE FROM "{table}"'))
        db.session.commit()
    yield


@pytest.fixture()
def client(app):
    return app.test_client()


def _register(client, full_name, email, password, role=None):
    payload = {'full_name': full_name, 'email': email, 'password': password}
    if role is not None:
        payload['role'] = role
    return client.post('/api/auth/register', json=payload)


def register_and_login(client, full_name, email, password, role=None):
    _register(client, full_name, email, password, role)
    response = client.post('/api/auth/login', json={
        'email': email,
        'password': password,
    })
    assert response.status_code == 200, response.get_json()
    token = response.get_json()['access_token']
    return {'Authorization': f'Bearer {token}'}


@pytest.fixture()
def member_headers(client):
    return register_and_login(client, 'Miembro Uno', 'member1@test.com', 'pass12345')


@pytest.fixture()
def other_member_headers(client):
    return register_and_login(client, 'Miembro Dos', 'member2@test.com', 'pass12345')


@pytest.fixture()
def admin_headers(app, client):
    with app.app_context():
        admin = User(full_name='Admin', email='admin@test.com', role='admin')
        admin.set_password('admin12345')
        db.session.add(admin)
        db.session.commit()
    response = client.post('/api/auth/login', json={
        'email': 'admin@test.com',
        'password': 'admin12345',
    })
    assert response.status_code == 200, response.get_json()
    token = response.get_json()['access_token']
    return {'Authorization': f'Bearer {token}'}