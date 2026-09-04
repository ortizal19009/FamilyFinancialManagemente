from backend.models import Category, db


def _add_categories(app):
    with app.app_context():
        comida = Category(name='Comida')
        transporte = Category(name='Transporte')
        db.session.add(comida)
        db.session.add(transporte)
        db.session.commit()
        return comida.id, transporte.id


def _add_accounts(client, headers):
    client.post('/api/banks/', json={'name': 'Banco Filtros'}, headers=headers)
    first = client.post(
        '/api/banks/accounts',
        json={'bank_id': 1, 'account_number': 'F1', 'current_balance': 1000},
        headers=headers,
    ).get_json()['id']
    second = client.post(
        '/api/banks/accounts',
        json={'bank_id': 1, 'account_number': 'F2', 'current_balance': 500},
        headers=headers,
    ).get_json()['id']
    return first, second


def _add_expenses(client, headers, category_ids):
    comida_id, transporte_id = category_ids
    client.post('/api/expenses/', json={
        'description': 'Mercado', 'amount': 100, 'category_id': comida_id,
        'payment_method': 'Efectivo', 'expense_date': '2026-08-10',
    }, headers=headers)
    client.post('/api/expenses/', json={
        'description': 'Mercado grande', 'amount': 200, 'category_id': comida_id,
        'payment_method': 'Efectivo', 'expense_date': '2026-09-01',
    }, headers=headers)
    client.post('/api/expenses/', json={
        'description': 'Taxi', 'amount': 50, 'category_id': transporte_id,
        'payment_method': 'Banca Móvil', 'expense_date': '2026-09-03',
    }, headers=headers)


class TestExpenseFilters:
    def _seed(self, client, headers, app):
        return _add_categories(app)

    def test_date_range_and_category(self, client, member_headers, app):
        comida_id, transporte_id = _add_categories(app)
        _add_expenses(client, member_headers, (comida_id, transporte_id))

        response = client.get(
            '/api/expenses/?from=2026-09-01&to=2026-09-30', headers=member_headers
        )
        assert response.status_code == 200
        assert len(response.get_json()) == 2

        by_category = client.get(
            '/api/expenses/?category_id={}'.format(comida_id), headers=member_headers
        ).get_json()
        assert len(by_category) == 2

        by_method = client.get(
            '/api/expenses/?payment_method=Banca%20M%C3%B3vil', headers=member_headers
        ).get_json()
        assert len(by_method) == 1

    def test_search_by_description_and_category_name(self, client, member_headers, app):
        comida_id, transporte_id = _add_categories(app)
        _add_expenses(client, member_headers, (comida_id, transporte_id))

        by_description = client.get(
            '/api/expenses/?search=taxi', headers=member_headers
        ).get_json()
        assert len(by_description) == 1
        assert by_description[0]['description'] == 'Taxi'

        by_category = client.get(
            '/api/expenses/?search=comida', headers=member_headers
        ).get_json()
        assert len(by_category) == 2


class TestPagination:
    def test_expenses_pagination_metadata(self, client, member_headers, app):
        comida_id, transporte_id = _add_categories(app)
        _add_expenses(client, member_headers, (comida_id, transporte_id))

        plain = client.get('/api/expenses/', headers=member_headers).get_json()
        assert isinstance(plain, list)
        assert len(plain) == 3

        response = client.get('/api/expenses/?page=1&per_page=2', headers=member_headers)
        assert response.status_code == 200
        data = response.get_json()
        assert data['total'] == 3
        assert data['per_page'] == 2
        assert data['pages'] == 2
        assert data['page'] == 1
        assert isinstance(data['items'], list)
        assert len(data['items']) == 2

        empty_page = client.get('/api/expenses/?page=99', headers=member_headers).get_json()
        assert empty_page['items'] == []
        assert empty_page['total'] == 3

    def test_income_and_transfer_pagination(self, client, member_headers, app):
        comida_id, transporte_id = _add_categories(app)
        first, second = _add_accounts(client, member_headers)
        client.post('/api/assets_income/income', json={
            'amount': 500, 'source': 'Venta', 'income_date': '2026-09-01',
        }, headers=member_headers)
        client.post('/api/assets_income/income', json={
            'amount': 300, 'source': 'Salario', 'income_date': '2026-09-02',
        }, headers=member_headers)
        client.post('/api/transfers/', json={
            'from_account_id': first, 'to_account_id': second,
            'amount': 50, 'transfer_date': '2026-09-03',
        }, headers=member_headers)
        client.post('/api/transfers/', json={
            'from_account_id': second, 'to_account_id': first,
            'amount': 20, 'transfer_date': '2026-09-04',
        }, headers=member_headers)

        income = client.get('/api/assets_income/income?page=1&per_page=1', headers=member_headers).get_json()
        assert income['total'] == 2
        assert len(income['items']) == 1
        assert income['pages'] == 2

        transfers = client.get('/api/transfers/?page=1&per_page=1', headers=member_headers).get_json()
        assert transfers['total'] == 2
        assert transfers['pages'] == 2

        by_source = client.get(
            '/api/assets_income/income?search=salario', headers=member_headers
        ).get_json()
        assert len(by_source) == 1
        assert by_source[0]['source'] == 'Salario'


class TestDebtorFilters:
    def test_status_filter_and_pagination(self, client, member_headers, app):
        client.post('/api/debtors/', json={
            'name': 'Pendiente', 'amount_owed': 100, 'status': 'pendiente',
        }, headers=member_headers)
        created = client.post('/api/debtors/', json={
            'name': 'Pagado', 'amount_owed': 200, 'status': 'pendiente',
        }, headers=member_headers).get_json()['id']
        client.put('/api/debtors/{}'.format(created), json={'status': 'pagado'}, headers=member_headers)

        pending = client.get('/api/debtors/?status=pendiente', headers=member_headers).get_json()
        assert len(pending) == 1
        assert pending[0]['name'] == 'Pendiente'

        all_debtors = client.get('/api/debtors/', headers=member_headers).get_json()
        assert len(all_debtors) == 2

        searched = client.get('/api/debtors/?search=pendi', headers=member_headers).get_json()
        assert len(searched) == 1

        paginated = client.get('/api/debtors/?page=1&per_page=1', headers=member_headers).get_json()
        assert paginated['total'] == 2


class TestAccountFilters:
    def test_bank_filter_search_and_pagination(self, client, member_headers, app):
        _add_accounts(client, member_headers)

        accounts = client.get('/api/banks/accounts', headers=member_headers).get_json()
        assert isinstance(accounts, list)
        assert len(accounts) == 2

        by_bank = client.get('/api/banks/accounts?bank_id=1', headers=member_headers).get_json()
        assert len(by_bank) == 2

        searched = client.get('/api/banks/accounts?search=F1', headers=member_headers).get_json()
        assert len(searched) == 1

        paginated = client.get('/api/banks/accounts?page=1&per_page=1', headers=member_headers).get_json()
        assert paginated['total'] == 2
        assert len(paginated['items']) == 1


class TestCardsLoansFilters:
    def test_card_search_and_type_filter(self, client, member_headers, app):
        first, _ = _add_accounts(client, member_headers)
        client.post('/api/cards_loans/cards', json={
            'bank_id': 1, 'card_name': 'Visa Oro', 'card_type': 'Crédito',
            'credit_limit': 5000, 'current_debt': 0, 'available_balance': 5000,
        }, headers=member_headers)
        client.post('/api/cards_loans/cards', json={
            'bank_id': 1, 'bank_account_id': first, 'card_name': 'Master Débito', 'card_type': 'Débito',
            'credit_limit': 0, 'current_debt': 0, 'available_balance': 0,
        }, headers=member_headers)

        tagged = client.get('/api/cards_loans/cards?card_type=D%C3%A9bito', headers=member_headers).get_json()
        assert len(tagged) == 1
        assert tagged[0]['card_name'] == 'Master Débito'

        searched = client.get('/api/cards_loans/cards?search=visa', headers=member_headers).get_json()
        assert len(searched) == 1
        assert searched[0]['card_name'] == 'Visa Oro'

        paginated = client.get('/api/cards_loans/cards?page=1&per_page=1', headers=member_headers).get_json()
        assert paginated['total'] == 2