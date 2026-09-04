import pytest

from backend.models import User


class TestRegistrationSecurity:
    def test_register_ignores_role_from_client(self, app, client):
        response = client.post('/api/auth/register', json={
            'full_name': 'Hacker',
            'email': 'hacker@test.com',
            'password': 'pass12345',
            'role': 'admin',
        })
        assert response.status_code == 201
        with app.app_context():
            user = User.query.filter_by(email='hacker@test.com').first()
            assert user is not None
            assert user.role == 'member'

    def test_register_duplicate_email_rejected(self, client):
        payload = {'full_name': 'Uno', 'email': 'dup@test.com', 'password': 'pass12345'}
        assert client.post('/api/auth/register', json=payload).status_code == 201
        assert client.post('/api/auth/register', json=payload).status_code == 400

    def test_login_rejects_bad_credentials(self, client):
        client.post('/api/auth/register', json={
            'full_name': 'Uno',
            'email': 'bad@test.com',
            'password': 'pass12345',
        })
        response = client.post('/api/auth/login', json={
            'email': 'bad@test.com',
            'password': 'incorrecta',
        })
        assert response.status_code == 401

    def test_protected_endpoint_requires_token(self, client):
        response = client.get('/api/banks/')
        assert response.status_code == 401


class TestAdminUserCreation:
    def test_member_cannot_create_users(self, app, client, member_headers):
        response = client.post(
            '/api/auth/users',
            json={'full_name': 'Otro', 'email': 'otro@test.com', 'password': 'pass12345'},
            headers=member_headers,
        )
        assert response.status_code == 403

    def test_admin_can_create_admin(self, app, client, admin_headers):
        response = client.post(
            '/api/auth/users',
            json={'full_name': 'Nuevo Admin', 'email': 'nadmin@test.com', 'password': 'pass12345', 'role': 'admin'},
            headers=admin_headers,
        )
        assert response.status_code == 201
        with app.app_context():
            user = User.query.filter_by(email='nadmin@test.com').first()
            assert user.role == 'admin'