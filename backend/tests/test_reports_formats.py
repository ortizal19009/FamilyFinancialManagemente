from datetime import date
from io import BytesIO
import zipfile

import pytest

from backend.models import (
    Asset,
    AuditLog,
    Bank,
    BankAccount,
    Card,
    CardPayment,
    Category,
    Debtor,
    Expense,
    Income,
    Investment,
    Loan,
    LoanPayment,
    SmallDebt,
    db,
)

NEW_REPORT_TYPES = [
    'expenses-category',
    'cards',
    'loans',
    'investments',
    'assets',
    'debts',
    'net-worth',
]
ALL_FORMATS = ['pdf', 'xml', 'csv', 'xlsx']
FORMAT_MIMETYPES = {
    'pdf': 'application/pdf',
    'xml': 'application/xml',
    'csv': 'text/csv',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
}
LEGACY_REPORT_TYPES = ['summary', 'movements', 'accounts', 'expenses', 'planning']


def _seed_member_data(app, user_id=1):
    with app.app_context():
        bank = Bank(name='Banco Reporte')
        db.session.add(bank)
        db.session.flush()

        account = BankAccount(
            user_id=user_id,
            bank_id=bank.id,
            account_number='RPT1',
            account_type='corriente',
            owner='Miembro Uno',
            current_balance=2000,
        )
        db.session.add(account)
        db.session.flush()

        card = Card(
            bank_id=bank.id,
            bank_account_id=account.id,
            user_id=user_id,
            card_name='Visa Reporte',
            owner='Miembro Uno',
            card_type='Credito',
            credit_limit=5000,
            current_debt=500,
            available_balance=4500,
        )
        db.session.add(card)
        db.session.flush()

        loan = Loan(
            user_id=user_id,
            bank_id=bank.id,
            description='Prestamo auto',
            owner='Miembro Uno',
            initial_amount=10000,
            total_installments=24,
            pending_installments=10,
            monthly_payment=450,
            interest_rate=12.5,
            start_date=date(2026, 1, 1),
        )
        db.session.add(loan)
        db.session.flush()

        db.session.add(LoanPayment(
            user_id=user_id,
            loan_id=loan.id,
            account_id=account.id,
            amount=450,
            principal_paid=250,
            interest_paid=200,
            balance_after=9750,
            payment_date=date(2026, 8, 1),
            status='ACTIVO',
        ))
        db.session.add(CardPayment(
            user_id=user_id,
            card_id=card.id,
            account_id=account.id,
            amount=200,
            payment_date=date(2026, 8, 5),
            status='ACTIVO',
        ))

        db.session.add(Investment(
            user_id=user_id,
            institution='CETES',
            investment_type='Fondo',
            title='Fondo A',
            owner='Miembro Uno',
            invested_amount=1000,
            current_value=1100,
            expected_return_rate=10.0,
            start_date=date(2026, 1, 1),
            status='activa',
        ))
        db.session.add(Asset(
            user_id=user_id,
            name='Auto',
            value=15000,
            owner='Miembro Uno',
            purchase_date=date(2025, 1, 1),
        ))
        db.session.add(Debtor(
            user_id=user_id,
            name='Juan',
            amount_owed=300,
            status='pendiente',
            due_date=date(2026, 9, 15),
        ))
        db.session.add(SmallDebt(
            user_id=user_id,
            lender_name='Pedro',
            amount=120,
            status='pendiente',
            due_date=date(2026, 9, 20),
        ))

        category = Category(name='Comida')
        db.session.add(category)
        db.session.flush()

        expense = Expense(
            user_id=user_id,
            category_id=category.id,
            amount=150,
            payment_method='Efectivo',
            expense_date=date(2026, 8, 12),
            status='ACTIVO',
        )
        db.session.add(expense)
        db.session.flush()

        db.session.add(Income(
            user_id=user_id,
            amount=800,
            source='Sueldo',
            income_date=date(2026, 8, 1),
            destination_type='cash',
            status='ACTIVO',
        ))
        db.session.add(AuditLog(
            user_id=user_id,
            action='CREATE',
            entity='expense',
            entity_id=expense.id,
            ip_address='127.0.0.1',
        ))
        db.session.commit()


def _export(client, headers, report_type, output_format, extra=''):
    return client.get(
        f'/api/reports/export?type={report_type}&format={output_format}{extra}',
        headers=headers,
    )


class TestNewReportTypesExports:
    @pytest.mark.parametrize('report_type', NEW_REPORT_TYPES)
    @pytest.mark.parametrize('output_format', ALL_FORMATS)
    def test_new_types_export_ok(self, client, member_headers, app, report_type, output_format):
        _seed_member_data(app)

        response = _export(client, member_headers, report_type, output_format)

        assert response.status_code == 200, response.get_data(as_text=True)
        assert response.headers['Content-Type'].startswith(FORMAT_MIMETYPES[output_format])
        disposition = response.headers['Content-Disposition']
        assert disposition.startswith('attachment; filename=reporte_')
        assert f'reporte_{report_type}_' in disposition
        assert disposition.endswith(f'.{output_format}')
        assert response.data[:2] != b'{'


class TestCsvContent:
    @pytest.mark.parametrize('report_type,markers', [
        ('expenses-category', ['Totales por Categoría', 'Comida', '150.0']),
        ('cards', ['Tarjetas', 'Visa Reporte', 'Pagos de Tarjetas']),
        ('loans', ['Préstamos', 'Amortización', 'Prestamo auto', '9750.0']),
        ('investments', ['Inversiones', 'Fondo A', '100.0']),
        ('assets', ['Activos', 'Auto', '15000.0']),
        ('debts', ['Cuentas por Cobrar', 'Micro Deudas por Pagar', 'Juan', 'Pedro']),
        ('net-worth', ['Composición del Patrimonio', 'Patrimonio neto', '7730.0']),
    ])
    def test_csv_contains_expected_tables(self, client, member_headers, app, report_type, markers):
        _seed_member_data(app)

        response = _export(client, member_headers, report_type, 'csv')

        assert response.status_code == 200, response.get_data(as_text=True)
        content = response.get_data(as_text=True)
        assert content.startswith('\ufeff')
        for marker in markers:
            assert marker in content, f'{marker!r} not in CSV for {report_type}'


class TestXlsxStructure:
    def test_xlsx_is_valid_zip_with_worksheets(self, client, member_headers, app):
        _seed_member_data(app)

        response = _export(client, member_headers, 'loans', 'xlsx')

        assert response.status_code == 200, response.get_data(as_text=True)
        assert response.headers['Content-Type'].startswith('application/vnd.openxmlformats')
        assert response.headers['Content-Disposition'].endswith('.xlsx')

        with zipfile.ZipFile(BytesIO(response.data)) as archive:
            names = archive.namelist()
            assert '[Content_Types].xml' in names
            assert 'xl/workbook.xml' in names
            assert 'xl/_rels/workbook.xml.rels' in names
            assert 'xl/worksheets/sheet1.xml' in names

            workbook_xml = archive.read('xl/workbook.xml').decode('utf-8')
            sheet1_xml = archive.read('xl/worksheets/sheet1.xml').decode('utf-8')

        assert 'sheet name="Préstamos"' in workbook_xml
        assert 'Prestamo auto' in sheet1_xml
        assert '<v>9750.0</v>' in sheet1_xml


class TestAuditReport:
    def test_member_cannot_export_audit(self, client, member_headers, app):
        _seed_member_data(app)

        response = _export(client, member_headers, 'audit', 'csv')

        assert response.status_code == 400
        assert 'requiere rol de administrador' in response.get_json()['msg']

    def test_admin_exports_audit(self, client, admin_headers, app):
        _seed_member_data(app)

        response = _export(client, admin_headers, 'audit', 'csv')

        assert response.status_code == 200, response.get_data(as_text=True)
        content = response.get_data(as_text=True)
        assert 'Registro de Auditoría' in content
        assert 'CREATE' in content
        assert 'expense' in content


class TestLegacyReportTypesCsv:
    @pytest.mark.parametrize('report_type,markers', [
        ('summary', ['Indicadores', 'Registros']),
        ('movements', ['Movimientos', 'Sueldo']),
        ('accounts', ['Cuentas bancarias', 'Tarjetas', 'Préstamos', 'RPT1']),
        ('expenses', ['Totales por categoría', 'Comida']),
        ('planning', ['Detalle de planificación']),
    ])
    def test_legacy_types_csv(self, client, member_headers, app, report_type, markers):
        _seed_member_data(app)

        response = _export(client, member_headers, report_type, 'csv')

        assert response.status_code == 200, response.get_data(as_text=True)
        content = response.get_data(as_text=True)
        for marker in markers:
            assert marker in content, f'{marker!r} not in CSV for {report_type}'


class TestInvalidReportParams:
    def test_unknown_report_type(self, client, member_headers):
        response = _export(client, member_headers, 'unknown-type', 'csv')

        assert response.status_code == 400
        assert 'Tipo de reporte no soportado' in response.get_json()['msg']

    def test_unknown_format(self, client, member_headers):
        response = _export(client, member_headers, 'summary', 'txt')

        assert response.status_code == 400
        assert 'Formato de reporte no soportado' in response.get_json()['msg']