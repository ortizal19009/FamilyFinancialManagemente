from backend.models import Category, db


def _add_categories(app):
    with app.app_context():
        comida = Category(name='Comida')
        transporte = Category(name='Transporte')
        db.session.add(comida)
        db.session.add(transporte)
        db.session.commit()
        return comida.id, transporte.id


def _seed_finances(client, headers, app):
    comida_id, transporte_id = _add_categories(app)
    client.post('/api/banks/', json={'name': 'Banco Dash'}, headers=headers)
    account_id = client.post(
        '/api/banks/accounts',
        json={'bank_id': 1, 'account_number': 'DASH-1', 'current_balance': 5000},
        headers=headers,
    ).get_json()['id']
    client.post('/api/cards_loans/cards', json={
        'bank_id': 1,
        'card_name': 'Visa Dash',
        'card_type': 'Crédito',
        'credit_limit': 5000,
        'current_debt': 1000,
        'available_balance': 4000,
    }, headers=headers)
    card_id = client.get('/api/cards_loans/cards', headers=headers).get_json()[0]['id']
    client.post('/api/cards_loans/loans', json={
        'description': 'Auto',
        'initial_amount': 12000,
        'total_installments': 12,
        'pending_installments': 5,
        'monthly_payment': 1100,
        'interest_rate': 12,
        'start_date': '2026-01-01',
    }, headers=headers)
    client.post('/api/assets_income/income', json={
        'amount': 3000, 'source': 'Salario', 'income_date': '2026-09-02',
    }, headers=headers)
    client.post('/api/assets_income/assets', json={'name': 'Casa', 'value': 80000}, headers=headers)
    client.post('/api/expenses/', json={
        'description': 'Mercado', 'amount': 400, 'category_id': comida_id,
        'payment_method': 'Efectivo', 'expense_date': '2026-09-03',
    }, headers=headers)
    client.post('/api/expenses/', json={
        'description': 'Taxi', 'amount': 100, 'category_id': transporte_id,
        'payment_method': 'Efectivo', 'expense_date': '2026-09-04',
    }, headers=headers)
    client.post('/api/debtors/', json={'name': 'Juan', 'amount_owed': 200}, headers=headers)
    client.post('/api/debtors/small-debts', json={'lender_name': 'Pedro', 'amount': 150}, headers=headers)
    client.post('/api/planning/', json={
        'category_id': comida_id, 'planned_amount': 600, 'month': 9, 'year': 2026,
    }, headers=headers)
    client.post('/api/cards_loans/cards/{}/payments'.format(card_id), json={
        'account_id': account_id, 'amount': 300, 'payment_date': '2026-09-02',
    }, headers=headers)
    return account_id


def _summary(client, headers):
    response = client.get('/api/dashboard/summary', headers=headers)
    assert response.status_code == 200, response.get_json()
    return response.get_json()['stats']


class TestDashboardSummary:
    def test_summary_kpis(self, client, member_headers, app):
        _seed_finances(client, member_headers, app)
        stats = _summary(client, member_headers)

        assert stats['availableBalance'] == 4700.0
        assert stats['monthlyIncome'] == 3000.0
        assert stats['monthlyExpenses'] == 500.0
        assert stats['monthlySavings'] == 2500.0
        assert stats['savingsRate'] == 83.33
        assert stats['creditCardDebt'] == 700.0
        assert stats['loanDebt'] == 5500.0
        assert stats['totalDebt'] == 6200.0
        assert stats['totalAssets'] == 80000.0
        assert stats['receivables'] == 200.0
        assert stats['payables'] == 150.0
        assert stats['netWorth'] == 78500.0
        assert stats['budgetPlanned'] == 600.0
        assert stats['budgetUsed'] == 400.0
        assert stats['budgetUsedPercent'] == 66.67

    def test_summary_excludes_anulled_expenses(self, client, member_headers, app):
        _seed_finances(client, member_headers, app)
        expenses = client.get('/api/expenses/', headers=member_headers).get_json()
        client.delete("/api/expenses/{}".format(expenses[0]['id']), headers=member_headers)

        stats = _summary(client, member_headers)
        assert stats['monthlyExpenses'] == 400.0
        assert stats['monthlySavings'] == 2600.0

    def test_summary_scoped_per_member(self, client, member_headers, other_member_headers, app):
        _seed_finances(client, member_headers, app)
        empty = _summary(client, other_member_headers)
        assert empty['availableBalance'] == 0.0
        assert empty['monthlyExpenses'] == 0.0
        assert empty['totalDebt'] == 0.0
        assert empty['netWorth'] == 0.0

    def test_summary_requires_auth(self, client, app):
        response = client.get('/api/dashboard/summary')
        assert response.status_code == 401


class TestDashboardCharts:
    def test_chart_endpoints(self, client, member_headers, app):
        _seed_finances(client, member_headers, app)

        series = client.get('/api/dashboard/income-vs-expenses', headers=member_headers).get_json()
        assert series['series'][0] == {'month': '2026-09', 'income': 3000.0, 'expenses': 500.0}

        categories = client.get('/api/dashboard/expenses-by-category', headers=member_headers).get_json()
        assert categories['total'] == 500.0
        by_name = {row['name']: row for row in categories['categories']}
        assert by_name['Comida']['amount'] == 400.0
        assert by_name['Transporte']['amount'] == 100.0

        institutions = client.get('/api/dashboard/money-by-institution', headers=member_headers).get_json()
        assert institutions['total'] == 4700.0
        assert institutions['institutions'][0]['name'] == 'Banco Dash'
        assert institutions['institutions'][0]['accounts'][0]['balance'] == 4700.0

        assets = client.get('/api/dashboard/assets-distribution', headers=member_headers).get_json()
        assert assets['total'] == 80000.0
        assert assets['assets'][0]['percentage'] == 100.0

        budget = client.get('/api/dashboard/budget-vs-actual', headers=member_headers).get_json()
        assert budget['plannedTotal'] == 600.0
        assert budget['usedTotal'] == 400.0
        assert budget['usedPercent'] == 66.67

        evolution = client.get(
            '/api/dashboard/debt-evolution?start=2026-07-01', headers=member_headers
        ).get_json()
        assert evolution['currentOutstanding'] == 6200.0
        assert [point['outstanding'] for point in evolution['series']] == [6500.0, 6500.0, 6200.0]

    def test_range_filtering(self, client, member_headers, app):
        _seed_finances(client, member_headers, app)

        quarter = client.get(
            '/api/dashboard/income-vs-expenses?range=quarter', headers=member_headers
        ).get_json()
        assert len(quarter['series']) == 3

        year = client.get(
            '/api/dashboard/income-vs-expenses?range=year', headers=member_headers
        ).get_json()
        assert len(year['series']) == 12

        custom = client.get(
            '/api/dashboard/income-vs-expenses?range=custom&start=2026-06-01&end=2026-12-31',
            headers=member_headers,
        ).get_json()
        assert len(custom['series']) == 7

        empty_range = client.get(
            '/api/dashboard/income-vs-expenses?start=2024-01-01&end=2024-12-31',
            headers=member_headers,
        ).get_json()
        assert all(point['income'] == 0.0 and point['expenses'] == 0.0 for point in empty_range['series'])

    def test_administrator_sees_all_members_data(self, client, member_headers, admin_headers, app):
        _seed_finances(client, member_headers, app)
        admin_stats = _summary(client, admin_headers)
        assert admin_stats['monthlyExpenses'] == 500.0
        assert admin_stats['monthlyIncome'] == 3000.0
        assert admin_stats['availableBalance'] == 4700.0