import pytest

from backend.models import (
    CardPayment,
    FinancialMovement,
    LoanPayment,
    Transfer,
)


def _setup_accounts(client, headers, balance_a=1000, balance_b=500):
    client.post('/api/banks/', json={'name': 'Banco F2'}, headers=headers)
    account_a = client.post(
        '/api/banks/accounts',
        json={'bank_id': 1, 'account_number': 'F2-A', 'current_balance': balance_a},
        headers=headers,
    ).get_json()['id']
    account_b = client.post(
        '/api/banks/accounts',
        json={'bank_id': 1, 'account_number': 'F2-B', 'current_balance': balance_b},
        headers=headers,
    ).get_json()['id']
    return account_a, account_b


def _balances(client, headers):
    return {
        a['account_number']: a['current_balance']
        for a in client.get('/api/banks/accounts', headers=headers).get_json()
    }


class TestTransfers:
    def test_transfer_moves_money_and_registers_two_movements(self, client, member_headers):
        account_a, account_b = _setup_accounts(client, member_headers)
        response = client.post('/api/transfers/', json={
            'from_account_id': account_a,
            'to_account_id': account_b,
            'amount': 200,
            'transfer_date': '2026-09-01',
            'description': 'Ahorro',
        }, headers=member_headers)
        assert response.status_code == 201

        assert _balances(client, member_headers)['F2-A'] == 800.0
        assert _balances(client, member_headers)['F2-B'] == 700.0

        data = client.get('/api/movements/?source_type=TRANSFER', headers=member_headers).get_json()
        assert data['total'] == 2
        directions = {item['direction'] for item in data['items']}
        assert directions == {'IN', 'OUT'}
        assert all(item['source_id'] == response.get_json()['id'] for item in data['items'])

    def test_transfer_rejects_same_account_and_insufficient_balance(self, client, member_headers):
        account_a, account_b = _setup_accounts(client, member_headers, balance_a=100)
        same = client.post('/api/transfers/', json={
            'from_account_id': account_a,
            'to_account_id': account_a,
            'amount': 10,
            'transfer_date': '2026-09-01',
        }, headers=member_headers)
        assert same.status_code == 400

        insufficient = client.post('/api/transfers/', json={
            'from_account_id': account_a,
            'to_account_id': account_b,
            'amount': 9999,
            'transfer_date': '2026-09-01',
        }, headers=member_headers)
        assert insufficient.status_code == 400
        assert _balances(client, member_headers)['F2-A'] == 100.0
        assert _balances(client, member_headers)['F2-B'] == 500.0

    def test_transfer_cancel_restores_balances(self, app, client, member_headers):
        account_a, account_b = _setup_accounts(client, member_headers)
        transfer_id = client.post('/api/transfers/', json={
            'from_account_id': account_a,
            'to_account_id': account_b,
            'amount': 150,
            'transfer_date': '2026-09-01',
        }, headers=member_headers).get_json()['id']

        cancelled = client.delete(f'/api/transfers/{transfer_id}', headers=member_headers)
        assert cancelled.status_code == 200
        assert _balances(client, member_headers)['F2-A'] == 1000.0
        assert _balances(client, member_headers)['F2-B'] == 500.0

        with app.app_context():
            transfer = Transfer.query.get(transfer_id)
            assert transfer.status == 'ANULADO'
            originals = FinancialMovement.query.filter_by(
                source_id=transfer_id, source_type='TRANSFER', movement_type='TRANSFERENCIA'
            ).all()
            assert all(m.status == 'ANULADO' for m in originals)
            reversions = FinancialMovement.query.filter_by(
                source_id=transfer_id, source_type='TRANSFER', movement_type='REVERSION'
            ).all()
            assert len(reversions) == 2

    def test_member_cannot_transfer_from_other_account(self, client, member_headers, other_member_headers):
        account_a, account_b = _setup_accounts(client, other_member_headers)
        response = client.post('/api/transfers/', json={
            'from_account_id': account_a,
            'to_account_id': account_b,
            'amount': 10,
            'transfer_date': '2026-09-01',
        }, headers=member_headers)
        assert response.status_code == 400


class TestCardPayments:
    def _setup_card(self, client, headers, account_id):
        return client.post('/api/cards_loans/cards', json={
            'bank_id': 1,
            'card_name': 'Visa X',
            'card_type': 'Crédito',
            'credit_limit': 5000,
            'current_debt': 1000,
            'available_balance': 4000,
        }, headers=headers).get_json()['id']

    def test_payment_reduces_debt_and_debits_account(self, client, member_headers):
        account_a, _ = _setup_accounts(client, member_headers)
        card_id = self._setup_card(client, member_headers, account_a)

        response = client.post(f'/api/cards_loans/cards/{card_id}/payments', json={
            'account_id': account_a,
            'amount': 300,
            'payment_date': '2026-09-01',
        }, headers=member_headers)
        assert response.status_code == 201

        cards = client.get('/api/cards_loans/cards', headers=member_headers).get_json()
        assert cards[0]['current_debt'] == 700.0
        assert cards[0]['available_balance'] == 4300.0
        assert _balances(client, member_headers)['F2-A'] == 700.0

        movements = client.get('/api/movements/?movement_type=PAGO_TARJETA', headers=member_headers).get_json()
        assert movements['total'] == 1
        assert movements['items'][0]['direction'] == 'OUT'

    def test_payment_without_account_keeps_balance(self, app, client, member_headers):
        account_a, _ = _setup_accounts(client, member_headers)
        card_id = self._setup_card(client, member_headers, account_a)
        response = client.post(f'/api/cards_loans/cards/{card_id}/payments', json={
            'amount': 100,
            'payment_date': '2026-09-01',
        }, headers=member_headers)
        assert response.status_code == 201
        assert _balances(client, member_headers)['F2-A'] == 1000.0

    def test_cancel_payment_restores_debt_and_balance(self, app, client, member_headers):
        account_a, _ = _setup_accounts(client, member_headers)
        card_id = self._setup_card(client, member_headers, account_a)
        payment_id = client.post(f'/api/cards_loans/cards/{card_id}/payments', json={
            'account_id': account_a,
            'amount': 300,
            'payment_date': '2026-09-01',
        }, headers=member_headers).get_json()['id']

        cancelled = client.delete(f'/api/cards_loans/cards/payments/{payment_id}', headers=member_headers)
        assert cancelled.status_code == 200
        cards = client.get('/api/cards_loans/cards', headers=member_headers).get_json()
        assert cards[0]['current_debt'] == 1000.0
        assert _balances(client, member_headers)['F2-A'] == 1000.0

        with app.app_context():
            payment = CardPayment.query.get(payment_id)
            assert payment.status == 'ANULADO'
            reversal = FinancialMovement.query.filter_by(
                source_id=payment_id, source_type='CARD_PAYMENT', movement_type='REVERSION'
            ).first()
            assert reversal is not None and reversal.direction == 'IN'


class TestLoanPayments:
    def _setup_loan(self, client, headers):
        loan_id = client.post('/api/cards_loans/loans', json={
            'description': 'Auto',
            'initial_amount': 12000,
            'total_installments': 12,
            'pending_installments': 12,
            'monthly_payment': 1100,
            'interest_rate': 12,
            'start_date': '2026-01-01',
        }, headers=headers).get_json()['id']
        return loan_id

    def test_payment_reduces_pending_and_records_amortization(self, client, member_headers):
        account_a, _ = _setup_accounts(client, member_headers, balance_a=20000)
        loan_id = self._setup_loan(client, member_headers)

        response = client.post(f'/api/cards_loans/loans/{loan_id}/payments', json={
            'amount': 1100,
            'payment_date': '2026-01-31',
            'account_id': account_a,
        }, headers=member_headers)
        assert response.status_code == 201
        body = response.get_json()
        assert body['interest_paid'] == 120.0
        assert body['principal_paid'] == 980.0
        assert body['balance_after'] == 11020.0

        loans = client.get('/api/cards_loans/loans', headers=member_headers).get_json()
        assert loans[0]['pending_installments'] == 11
        assert _balances(client, member_headers)['F2-A'] == 18900.0

    def test_amortization_schedule(self, client, member_headers):
        account_a, _ = _setup_accounts(client, member_headers, balance_a=20000)
        loan_id = self._setup_loan(client, member_headers)
        response = client.get(f'/api/cards_loans/loans/{loan_id}/amortization', headers=member_headers)
        assert response.status_code == 200
        data = response.get_json()
        assert len(data['schedule']) == 12
        assert data['schedule'][0]['number'] == 1
        assert data['schedule'][0]['due_date'] == '2026-02-01'
        assert data['schedule'][-1]['balance'] == 0.0

    def test_cancel_payment_restores_pending_and_balance(self, app, client, member_headers):
        account_a, _ = _setup_accounts(client, member_headers, balance_a=20000)
        loan_id = self._setup_loan(client, member_headers)
        payment_id = client.post(f'/api/cards_loans/loans/{loan_id}/payments', json={
            'amount': 1100,
            'payment_date': '2026-01-31',
            'account_id': account_a,
        }, headers=member_headers).get_json()['id']

        cancelled = client.delete(f'/api/cards_loans/loans/payments/{payment_id}', headers=member_headers)
        assert cancelled.status_code == 200
        loans = client.get('/api/cards_loans/loans', headers=member_headers).get_json()
        assert loans[0]['pending_installments'] == 12
        assert _balances(client, member_headers)['F2-A'] == 20000.0

        with app.app_context():
            payment = LoanPayment.query.get(payment_id)
            assert payment.status == 'ANULADO'

    def test_payment_rejects_insufficient_balance(self, client, member_headers):
        account_a, _ = _setup_accounts(client, member_headers, balance_a=100)
        loan_id = self._setup_loan(client, member_headers)
        response = client.post(f'/api/cards_loans/loans/{loan_id}/payments', json={
            'amount': 1100,
            'payment_date': '2026-01-31',
            'account_id': account_a,
        }, headers=member_headers)
        assert response.status_code == 400

    def test_cannot_pay_other_users_loan(self, client, member_headers, other_member_headers):
        loan_id = self._setup_loan(client, other_member_headers)
        response = client.post(f'/api/cards_loans/loans/{loan_id}/payments', json={
            'amount': 100,
            'payment_date': '2026-01-31',
        }, headers=member_headers)
        assert response.status_code == 403