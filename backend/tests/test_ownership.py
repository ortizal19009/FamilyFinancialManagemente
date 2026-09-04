import pytest


@pytest.fixture()
def sample_bank(client, member_headers):
    response = client.post(
        '/api/banks/',
        json={'name': 'Banco Prueba'},
        headers=member_headers,
    )
    assert response.status_code == 201
    return response.get_json()['id']


class TestBankAccountOwnership:
    def test_create_account_assigns_owner(self, client, member_headers, sample_bank):
        response = client.post(
            '/api/banks/accounts',
            json={
                'bank_id': sample_bank,
                'account_number': '0001',
                'account_type': 'Ahorros',
                'current_balance': 1000,
            },
            headers=member_headers,
        )
        assert response.status_code == 201

        accounts = client.get('/api/banks/accounts', headers=member_headers).get_json()
        account = next(a for a in accounts if a['account_number'] == '0001')
        assert account['user_id'] is not None

    def test_member_only_sees_own_accounts(
        self, client, member_headers, other_member_headers, admin_headers, sample_bank
    ):
        client.post(
            '/api/banks/accounts',
            json={'bank_id': sample_bank, 'account_number': 'Solo-A'},
            headers=member_headers,
        )
        client.post(
            '/api/banks/accounts',
            json={'bank_id': sample_bank, 'account_number': 'Solo-B'},
            headers=other_member_headers,
        )

        own = client.get('/api/banks/accounts', headers=member_headers).get_json()
        other = client.get('/api/banks/accounts', headers=other_member_headers).get_json()
        admin = client.get('/api/banks/accounts', headers=admin_headers).get_json()

        assert [a['account_number'] for a in own] == ['Solo-A']
        assert [a['account_number'] for a in other] == ['Solo-B']
        assert sorted(a['account_number'] for a in admin) == ['Solo-A', 'Solo-B']

    def test_member_cannot_edit_other_account(self, client, member_headers, other_member_headers, sample_bank):
        client.post(
            '/api/banks/accounts',
            json={'bank_id': sample_bank, 'account_number': 'Ajeno'},
            headers=other_member_headers,
        )
        account_id = client.get(
            '/api/banks/accounts', headers=other_member_headers
        ).get_json()[0]['id']

        assert member_headers.get('Authorization') != other_member_headers.get('Authorization')
        response = client.put(
            f'/api/banks/accounts/{account_id}',
            json={'bank_id': sample_bank, 'account_number': 'Hackeado', 'current_balance': 999},
            headers=member_headers,
        )
        assert response.status_code == 403

    def test_member_cannot_delete_other_account(self, client, member_headers, other_member_headers, sample_bank):
        client.post(
            '/api/banks/accounts',
            json={'bank_id': sample_bank, 'account_number': 'Ajeno2'},
            headers=other_member_headers,
        )
        account_id = client.get(
            '/api/banks/accounts', headers=other_member_headers
        ).get_json()[0]['id']

        response = client.delete(f'/api/banks/accounts/{account_id}', headers=member_headers)
        assert response.status_code == 403


class TestAssetOwnership:
    def test_member_only_sees_own_assets(self, client, member_headers, other_member_headers):
        client.post(
            '/api/assets_income/assets',
            json={'name': 'Auto X', 'value': 10000},
            headers=member_headers,
        )
        client.post(
            '/api/assets_income/assets',
            json={'name': 'Casa Y', 'value': 50000},
            headers=other_member_headers,
        )

        own = client.get('/api/assets_income/assets', headers=member_headers).get_json()
        other = client.get('/api/assets_income/assets', headers=other_member_headers).get_json()

        assert [a['name'] for a in own] == ['Auto X']
        assert [a['name'] for a in other] == ['Casa Y']

    def test_member_cannot_edit_other_asset(self, client, member_headers, other_member_headers):
        client.post(
            '/api/assets_income/assets',
            json={'name': 'Ajeno', 'value': 100},
            headers=other_member_headers,
        )
        asset_id = client.get(
            '/api/assets_income/assets', headers=other_member_headers
        ).get_json()[0]['id']

        response = client.put(
            f'/api/assets_income/assets/{asset_id}',
            json={'name': 'Hackeado', 'value': 999},
            headers=member_headers,
        )
        assert response.status_code == 403

    def test_member_cannot_delete_other_asset(self, client, member_headers, other_member_headers):
        client.post(
            '/api/assets_income/assets',
            json={'name': 'Ajeno2', 'value': 100},
            headers=other_member_headers,
        )
        asset_id = client.get(
            '/api/assets_income/assets', headers=other_member_headers
        ).get_json()[0]['id']

        response = client.delete(f'/api/assets_income/assets/{asset_id}', headers=member_headers)
        assert response.status_code == 403