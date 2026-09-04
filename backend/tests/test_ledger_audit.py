import pytest

from backend.models import (
    AuditLog,
    Expense,
    FinancialMovement,
    Income,
)


def _setup_financial_context(client, headers):
    client.post('/api/banks/', json={'name': 'Banco Ledger'}, headers=headers)
    account_id = client.post(
        '/api/banks/accounts',
        json={'bank_id': 1, 'account_number': 'L-1', 'current_balance': 1000},
        headers=headers,
    ).get_json()['id']
    category_id = client.post(
        '/api/expenses/categories',
        json={'name': 'LedgerAlimentos'},
        headers=headers,
    ).get_json()['id']
    return account_id, category_id


def _movements(client, headers):
    return client.get('/api/movements/', headers=headers).get_json()


class TestFinancialLedger:
    def test_create_expense_registers_movement_and_audit(self, app, client, member_headers):
        account_id, category_id = _setup_financial_context(client, member_headers)
        response = client.post('/api/expenses/', json={
            'payment_method': 'Banca Móvil',
            'expense_date': '2026-09-01',
            'bank_account_id': account_id,
            'items': [{'category_id': category_id, 'amount': 100}],
        }, headers=member_headers)
        assert response.status_code == 201

        data = _movements(client, member_headers)
        assert data['total'] == 1
        movement = data['items'][0]
        assert movement['movement_type'] == 'GASTO'
        assert movement['direction'] == 'OUT'
        assert movement['amount'] == 100.0
        assert movement['status'] == 'ACTIVO'
        assert movement['account_id'] == account_id

        with app.app_context():
            audit = AuditLog.query.filter_by(entity='expense', action='CREATE').first()
            assert audit is not None
            assert audit.new_values['total_amount'] == 100.0

    def test_cancel_expense_soft_removes_and_reverts(self, app, client, member_headers):
        account_id, category_id = _setup_financial_context(client, member_headers)
        client.post('/api/expenses/', json={
            'payment_method': 'Banca Móvil',
            'expense_date': '2026-09-01',
            'bank_account_id': account_id,
            'items': [{'category_id': category_id, 'amount': 100}],
        }, headers=member_headers)
        expense_id = client.get('/api/expenses/', headers=member_headers).get_json()[0]['id']

        cancelled = client.delete(
            f'/api/expenses/{expense_id}',
            json={'reason': 'Compra errada'},
            headers=member_headers,
        )
        assert cancelled.status_code == 200

        accounts = client.get('/api/banks/accounts', headers=member_headers).get_json()
        assert accounts[0]['current_balance'] == 1000

        assert client.get('/api/expenses/', headers=member_headers).get_json() == []
        cancelled_visible = client.get(
            '/api/expenses/?include_cancelled=true', headers=member_headers
        ).get_json()
        assert cancelled_visible[0]['status'] == 'ANULADO'
        assert cancelled_visible[0]['cancellation_reason'] == 'Compra errada'

        with app.app_context():
            expense = db_get(Expense, expense_id)
            assert expense.status == 'ANULADO'
            original = FinancialMovement.query.filter_by(
                source_id=expense_id, movement_type='GASTO'
            ).all()
            assert all(m.status == 'ANULADO' for m in original)
            reversal = FinancialMovement.query.filter_by(
                source_id=expense_id, movement_type='REVERSION'
            ).first()
            assert reversal is not None
            assert reversal.direction == 'IN'
            assert reversal.amount == 100
            audit = AuditLog.query.filter_by(entity='expense', action='CANCEL').first()
            assert audit is not None
            assert audit.new_values['reason'] == 'Compra errada'

    def test_update_expense_registers_new_movement(self, app, client, member_headers):
        account_id, category_id = _setup_financial_context(client, member_headers)
        client.post('/api/expenses/', json={
            'payment_method': 'Banca Móvil',
            'expense_date': '2026-09-01',
            'bank_account_id': account_id,
            'items': [{'category_id': category_id, 'amount': 100}],
        }, headers=member_headers)
        expense_id = client.get('/api/expenses/', headers=member_headers).get_json()[0]['id']

        updated = client.put(f'/api/expenses/{expense_id}', json={
            'payment_method': 'Banca Móvil',
            'expense_date': '2026-09-01',
            'bank_account_id': account_id,
            'items': [{'category_id': category_id, 'amount': 150}],
        }, headers=member_headers)
        assert updated.status_code == 200

        with app.app_context():
            original = FinancialMovement.query.filter_by(
                user_id=1, movement_type='GASTO'
            ).order_by(FinancialMovement.id).all()
            assert [m.status for m in original] == ['ANULADO', 'ACTIVO']
            assert [float(m.amount) for m in original] == [100.0, 150.0]
            audit = AuditLog.query.filter_by(entity='expense', action='UPDATE').first()
            assert audit is not None
            assert len(audit.old_values) == 1

    def test_income_registers_movement_and_cancel_reverts(self, app, client, member_headers):
        account_id, _ = _setup_financial_context(client, member_headers)
        created = client.post('/api/assets_income/income', json={
            'amount': 500,
            'source': 'Sueldo',
            'income_date': '2026-09-01',
            'destination_type': 'bank_account',
            'bank_account_id': account_id,
        }, headers=member_headers)
        assert created.status_code == 201
        income_id = created.get_json()['id']

        data = _movements(client, member_headers)
        assert data['items'][0]['movement_type'] == 'INGRESO'
        assert data['items'][0]['direction'] == 'IN'

        accounts = client.get('/api/banks/accounts', headers=member_headers).get_json()
        assert accounts[0]['current_balance'] == 1500

        cancelled = client.delete(f'/api/assets_income/income/{income_id}', headers=member_headers)
        assert cancelled.status_code == 200

        accounts = client.get('/api/banks/accounts', headers=member_headers).get_json()
        assert accounts[0]['current_balance'] == 1000

        with app.app_context():
            income = db_get(Income, income_id)
            assert income.status == 'ANULADO'
            reversal = FinancialMovement.query.filter_by(
                source_id=income_id, movement_type='REVERSION'
            ).first()
            assert reversal is not None and reversal.direction == 'OUT'

    def test_member_cannot_see_other_user_movements(self, client, member_headers, other_member_headers):
        account_id_a, category_id_a = _setup_financial_context(client, member_headers)
        account_id_b, category_id_b = _setup_financial_context(client, other_member_headers)
        client.post('/api/expenses/', json={
            'payment_method': 'Banca Móvil',
            'expense_date': '2026-09-01',
            'bank_account_id': account_id_a,
            'items': [{'category_id': category_id_a, 'amount': 100}],
        }, headers=member_headers)
        client.post('/api/expenses/', json={
            'payment_method': 'Banca Móvil',
            'expense_date': '2026-09-01',
            'bank_account_id': account_id_b,
            'items': [{'category_id': category_id_b, 'amount': 200}],
        }, headers=other_member_headers)

        own = _movements(client, member_headers)
        other = _movements(client, other_member_headers)
        assert own['total'] == 1 and own['items'][0]['amount'] == 100.0
        assert other['total'] == 1 and other['items'][0]['amount'] == 200.0


class TestAuditPermissions:
    def test_member_cannot_access_audit(self, client, member_headers):
        response = client.get('/api/audit/', headers=member_headers)
        assert response.status_code == 403

    def test_admin_can_access_audit(self, client, member_headers, admin_headers):
        _setup_financial_context(client, member_headers)
        client.post('/api/assets_income/income', json={
            'amount': 100,
            'source': 'Venta',
            'income_date': '2026-09-01',
        }, headers=member_headers)

        response = client.get('/api/audit/', headers=admin_headers)
        assert response.status_code == 200
        data = response.get_json()
        assert data['total'] >= 1
        entities = {item['entity'] for item in data['items']}
        assert 'income' in entities

    def test_audit_filters_by_entity(self, client, member_headers, admin_headers):
        _setup_financial_context(client, member_headers)
        client.post('/api/assets_income/income', json={
            'amount': 100,
            'source': 'Venta',
            'income_date': '2026-09-01',
        }, headers=member_headers)

        response = client.get('/api/audit/?entity=income', headers=admin_headers)
        assert response.status_code == 200
        data = response.get_json()
        assert data['total'] >= 1
        assert all(item['entity'] == 'income' for item in data['items'])


def db_get(model, entity_id):
    from backend.models import db
    return db.session.get(model, entity_id)