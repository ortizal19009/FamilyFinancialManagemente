import io


def _build_ctx(client, headers):
    bank = client.post('/api/banks/', json={'name': 'Banco Gastos'}, headers=headers)
    bank_id = bank.get_json()['id']
    account = client.post(
        '/api/banks/accounts',
        json={'bank_id': bank_id, 'account_number': 'CUENTA-1', 'current_balance': 1000},
        headers=headers,
    )
    account_id = account.get_json()['id']
    category = client.post(
        '/api/expenses/categories',
        json={'name': 'TestAlimentos'},
        headers=headers,
    )
    category_id = category.get_json()['id']
    return bank_id, account_id, category_id


def _account_balance(client, headers):
    accounts = client.get('/api/banks/accounts', headers=headers).get_json()
    return accounts[0]['current_balance']


class TestFinancialIntegrity:
    def test_create_expense_affects_balance_atomically(self, client, member_headers):
        _, account_id, category_id = _build_ctx(client, member_headers)
        response = client.post('/api/expenses/', json={
            'payment_method': 'Banca Móvil',
            'expense_date': '2026-09-01',
            'bank_account_id': account_id,
            'items': [{'category_id': category_id, 'amount': 100}],
        }, headers=member_headers)
        assert response.status_code == 201
        assert _account_balance(client, member_headers) == 900

    def test_update_expense_recalculates_balance(self, client, member_headers):
        _, account_id, category_id = _build_ctx(client, member_headers)
        created = client.post('/api/expenses/', json={
            'payment_method': 'Banca Móvil',
            'expense_date': '2026-09-01',
            'bank_account_id': account_id,
            'items': [{'category_id': category_id, 'amount': 100}],
        }, headers=member_headers)
        assert created.status_code == 201
        expense_id = client.get('/api/expenses/', headers=member_headers).get_json()[0]['id']

        updated = client.put(f'/api/expenses/{expense_id}', json={
            'payment_method': 'Banca Móvil',
            'expense_date': '2026-09-01',
            'bank_account_id': account_id,
            'items': [{'category_id': category_id, 'amount': 150}],
        }, headers=member_headers)
        assert updated.status_code == 200
        assert _account_balance(client, member_headers) == 850

    def test_delete_expense_restores_balance(self, client, member_headers):
        _, account_id, category_id = _build_ctx(client, member_headers)
        created = client.post('/api/expenses/', json={
            'payment_method': 'Banca Móvil',
            'expense_date': '2026-09-01',
            'bank_account_id': account_id,
            'items': [{'category_id': category_id, 'amount': 100}],
        }, headers=member_headers)
        assert created.status_code == 201
        expense_id = client.get('/api/expenses/', headers=member_headers).get_json()[0]['id']

        deleted = client.delete(f'/api/expenses/{expense_id}', headers=member_headers)
        assert deleted.status_code == 200
        assert _account_balance(client, member_headers) == 1000

    def test_invalid_receipt_does_not_create_expense(self, client, member_headers):
        _, account_id, category_id = _build_ctx(client, member_headers)
        fake_file = (io.BytesIO(b'not-a-real-image'), 'comprobante.exe')
        response = client.post(
            '/api/expenses/',
            data={
                'payload': '{"payment_method": "Banca Móvil", "expense_date": "2026-09-01", "bank_account_id": %d, "items": [{"category_id": %d, "amount": 100}]}' % (account_id, category_id),
                'receipt': fake_file,
            },
            content_type='multipart/form-data',
            headers=member_headers,
        )
        assert response.status_code == 400
        assert _account_balance(client, member_headers) == 1000
        assert client.get('/api/expenses/', headers=member_headers).get_json() == []