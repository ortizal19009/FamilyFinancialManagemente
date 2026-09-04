from datetime import date, datetime
from decimal import Decimal
from io import BytesIO, StringIO
import csv
import unicodedata
import xml.etree.ElementTree as ET
import zipfile

from flask import Blueprint, jsonify, request, send_file
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy import func
from sqlalchemy.orm import joinedload

try:
    from backend.models import (
        Asset,
        AuditLog,
        Bank,
        BankAccount,
        Card,
        CardPayment,
        Category,
        Expense,
        Income,
        Investment,
        Loan,
        LoanPayment,
        MonthlyPlanning,
        SmallDebt,
        Debtor,
        User,
        db,
    )
except ModuleNotFoundError:
    from models import (
        Asset,
        AuditLog,
        Bank,
        BankAccount,
        Card,
        CardPayment,
        Category,
        Expense,
        Income,
        Investment,
        Loan,
        LoanPayment,
        MonthlyPlanning,
        SmallDebt,
        Debtor,
        User,
        db,
    )

reports_bp = Blueprint('reports', __name__)

SUPPORTED_REPORTS = {
    'summary',
    'movements',
    'accounts',
    'expenses',
    'planning',
    'expenses-category',
    'cards',
    'loans',
    'investments',
    'assets',
    'debts',
    'net-worth',
    'audit',
}
SUPPORTED_FORMATS = {'pdf', 'xml', 'csv', 'xlsx'}
TABULAR_REPORTS = {
    'expenses-category',
    'cards',
    'loans',
    'investments',
    'assets',
    'debts',
    'net-worth',
    'audit',
}


def _parse_iso_date(raw_value, field_name):
    if not raw_value:
        return None
    try:
        return datetime.strptime(raw_value, '%Y-%m-%d').date()
    except ValueError:
        raise ValueError(f'{field_name} debe tener formato YYYY-MM-DD')


def _to_float(value):
    if value in [None, '']:
        return 0.0
    return float(value)


def _format_money(value):
    return f'{_to_float(value):,.2f}'


def _format_date(value):
    if not value:
        return ''
    if isinstance(value, datetime):
        return value.strftime('%Y-%m-%d %H:%M')
    if isinstance(value, date):
        return value.strftime('%Y-%m-%d')
    return str(value)


def _build_filename(report_type, output_format):
    timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
    return f'reporte_{report_type}_{timestamp}.{output_format}'


def _get_request_context():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    if not user:
        return None, None

    report_type = (request.args.get('type') or 'summary').strip().lower()
    output_format = (request.args.get('format') or 'pdf').strip().lower()
    if report_type not in SUPPORTED_REPORTS:
        raise ValueError('Tipo de reporte no soportado')
    if output_format not in SUPPORTED_FORMATS:
        raise ValueError('Formato de reporte no soportado')

    filters = {
        'date_from': _parse_iso_date(request.args.get('date_from'), 'date_from'),
        'date_to': _parse_iso_date(request.args.get('date_to'), 'date_to'),
        'month': request.args.get('month', type=int),
        'year': request.args.get('year', type=int),
    }

    if filters['date_from'] and filters['date_to'] and filters['date_from'] > filters['date_to']:
        raise ValueError('date_from no puede ser mayor que date_to')

    return user, {
        'report_type': report_type,
        'output_format': output_format,
        'filters': filters,
    }


def _expense_query_for_user(user):
    query = Expense.query.options(
        joinedload(Expense.user),
        joinedload(Expense.category),
        joinedload(Expense.card),
        joinedload(Expense.bank_account).joinedload(BankAccount.bank),
    )
    if user.role != 'admin':
        query = query.filter(Expense.user_id == user.id)
    return query


def _income_query_for_user(user):
    query = Income.query.options(joinedload(Income.user))
    if user.role != 'admin':
        query = query.filter(Income.user_id == user.id)
    return query


def _card_query_for_user(user):
    query = Card.query.options(
        joinedload(Card.bank),
        joinedload(Card.bank_account).joinedload(BankAccount.bank),
        joinedload(Card.user),
    )
    if user.role != 'admin':
        query = query.filter(Card.user_id == user.id)
    return query


def _account_query_for_user(user):
    query = BankAccount.query.options(joinedload(BankAccount.bank))
    if user.role != 'admin':
        query = query.filter(BankAccount.user_id == user.id)
    return query


def _asset_query_for_user(user):
    query = Asset.query
    if user.role != 'admin':
        query = query.filter(Asset.user_id == user.id)
    return query


def _loan_query_for_user(user):
    query = Loan.query.options(joinedload(Loan.bank), joinedload(Loan.user))
    if user.role != 'admin':
        query = query.filter(Loan.user_id == user.id)
    return query


def _investment_query_for_user(user):
    query = Investment.query.options(joinedload(Investment.user))
    if user.role != 'admin':
        query = query.filter(Investment.user_id == user.id)
    return query


def _debtor_query_for_user(user):
    query = Debtor.query.options(joinedload(Debtor.user))
    if user.role != 'admin':
        query = query.filter(Debtor.user_id == user.id)
    return query


def _small_debt_query_for_user(user):
    query = SmallDebt.query.options(joinedload(SmallDebt.user))
    if user.role != 'admin':
        query = query.filter(SmallDebt.user_id == user.id)
    return query


def _card_payment_query_for_user(user):
    query = CardPayment.query.options(
        joinedload(CardPayment.user),
        joinedload(CardPayment.card),
        joinedload(CardPayment.account),
    )
    if user.role != 'admin':
        query = query.filter(CardPayment.user_id == user.id)
    return query


def _loan_payment_query_for_user(user):
    query = LoanPayment.query.options(
        joinedload(LoanPayment.user),
        joinedload(LoanPayment.loan),
        joinedload(LoanPayment.account),
    )
    if user.role != 'admin':
        query = query.filter(LoanPayment.user_id == user.id)
    return query


def _apply_date_range(query, column, filters):
    if filters.get('date_from'):
        query = query.filter(column >= filters['date_from'])
    if filters.get('date_to'):
        query = query.filter(column <= filters['date_to'])
    return query


def _build_summary_report(user, filters):
    today = date.today()
    account_balance = _account_query_for_user(user).with_entities(
        func.coalesce(func.sum(BankAccount.current_balance), 0)
    ).scalar() or 0
    total_assets = _asset_query_for_user(user).with_entities(
        func.coalesce(func.sum(Asset.value), 0)
    ).scalar() or 0
    total_debt = _card_query_for_user(user).with_entities(func.coalesce(func.sum(Card.current_debt), 0)).scalar() or 0
    investments_aggregate = _investment_query_for_user(user).with_entities(
        func.coalesce(func.sum(Investment.invested_amount), 0),
        func.coalesce(func.sum(Investment.current_value), 0),
    ).first()
    monthly_expenses = _expense_query_for_user(user).with_entities(
        func.coalesce(func.sum(Expense.amount), 0)
    ).filter(
        func.extract('month', Expense.expense_date) == today.month,
        func.extract('year', Expense.expense_date) == today.year,
    ).scalar() or 0

    recent_expenses = _expense_query_for_user(user).order_by(
        Expense.expense_date.desc(),
        Expense.created_at.desc(),
    ).limit(10).all()

    data = {
        'title': 'Reporte General',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'stats': {
            'available_balance': _to_float(account_balance),
            'total_debt': _to_float(total_debt),
            'monthly_expenses': _to_float(monthly_expenses),
            'total_assets': _to_float(total_assets),
            'investments_invested_amount': _to_float(investments_aggregate[0] if investments_aggregate else 0),
            'investments_current_value': _to_float(investments_aggregate[1] if investments_aggregate else 0),
        },
        'counts': {
            'banks': Bank.query.count(),
            'accounts': _account_query_for_user(user).count(),
            'cards': _card_query_for_user(user).count(),
            'loans': _loan_query_for_user(user).count(),
            'assets': _asset_query_for_user(user).count(),
            'income_records': _income_query_for_user(user).count(),
            'expenses': _expense_query_for_user(user).count(),
            'plans': MonthlyPlanning.query.count(),
            'debtors': _debtor_query_for_user(user).count(),
            'small_debts': _small_debt_query_for_user(user).count(),
            'investments': _investment_query_for_user(user).count(),
        },
        'recent_expenses': [
            {
                'date': _format_date(item.expense_date),
                'user_name': item.user.full_name if item.user else None,
                'description': item.description,
                'category': item.category.name if item.category else None,
                'payment_method': item.payment_method,
                'amount': _to_float(item.amount),
            }
            for item in recent_expenses
        ],
        'filters': filters,
    }
    return data


def _build_movements_report(user, filters):
    expenses = _apply_date_range(
        _expense_query_for_user(user),
        Expense.expense_date,
        filters,
    ).order_by(Expense.expense_date.desc(), Expense.created_at.desc()).all()
    income_records = _apply_date_range(
        _income_query_for_user(user),
        Income.income_date,
        filters,
    ).order_by(Income.income_date.desc(), Income.created_at.desc()).all()

    items = []
    for expense in expenses:
        items.append({
            'date': _format_date(expense.expense_date),
            'movement_type': 'Gasto',
            'detail': expense.description or 'Gasto registrado',
            'reference': expense.category.name if expense.category else '',
            'user_name': expense.user.full_name if expense.user else None,
            'amount_in': 0.0,
            'amount_out': _to_float(expense.amount),
            'net_amount': -_to_float(expense.amount),
        })

    for income in income_records:
        items.append({
            'date': _format_date(income.income_date),
            'movement_type': 'Ingreso',
            'detail': income.source,
            'reference': income.description or '',
            'user_name': income.user.full_name if income.user else None,
            'amount_in': _to_float(income.amount),
            'amount_out': 0.0,
            'net_amount': _to_float(income.amount),
        })

    items.sort(key=lambda item: item['date'], reverse=True)
    total_in = sum(item['amount_in'] for item in items)
    total_out = sum(item['amount_out'] for item in items)

    return {
        'title': 'Reporte de Movimientos',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'filters': filters,
        'totals': {
            'total_in': total_in,
            'total_out': total_out,
            'net_total': total_in - total_out,
            'records': len(items),
        },
        'items': items,
    }


def _build_accounts_report(user, filters):
    banks = Bank.query.order_by(Bank.name.asc()).all()
    accounts = _account_query_for_user(user).order_by(BankAccount.created_at.desc()).all()
    cards = _card_query_for_user(user).order_by(Card.created_at.desc()).all()
    loans = _loan_query_for_user(user).order_by(Loan.created_at.desc()).all()

    return {
        'title': 'Reporte de Cuentas y Productos',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'filters': filters,
        'banks': [
            {
                'name': bank.name,
                'description': bank.description,
            }
            for bank in banks
        ],
        'accounts': [
            {
                'bank_name': account.bank.name if account.bank else None,
                'account_number': account.account_number,
                'account_type': account.account_type,
                'owner': account.owner,
                'current_balance': _to_float(account.current_balance),
            }
            for account in accounts
        ],
        'cards': [
            {
                'bank_name': card.bank.name if card.bank else None,
                'bank_account_name': (
                    f"{card.bank_account.bank.name} - {card.bank_account.account_number}"
                    if card.bank_account and card.bank_account.bank
                    else None
                ),
                'user_name': card.user.full_name if card.user else None,
                'card_name': card.card_name,
                'owner': card.owner,
                'last_four_digits': card.last_four_digits,
                'card_type': card.card_type,
                'credit_limit': _to_float(card.credit_limit),
                'current_debt': _to_float(card.current_debt),
                'available_balance': _to_float(card.available_balance),
            }
            for card in cards
        ],
        'loans': [
            {
                'bank_name': loan.bank.name if loan.bank else None,
                'user_name': loan.user.full_name if loan.user else None,
                'description': loan.description,
                'owner': loan.owner,
                'initial_amount': _to_float(loan.initial_amount),
                'monthly_payment': _to_float(loan.monthly_payment),
                'pending_installments': loan.pending_installments,
                'total_installments': loan.total_installments,
                'start_date': _format_date(loan.start_date),
            }
            for loan in loans
        ],
    }


def _build_expenses_report(user, filters):
    expenses = _apply_date_range(
        _expense_query_for_user(user),
        Expense.expense_date,
        filters,
    ).order_by(Expense.expense_date.desc(), Expense.created_at.desc()).all()

    totals_by_category_query = db.session.query(
        Category.name,
        func.coalesce(func.sum(Expense.amount), 0),
    ).join(Category, Category.id == Expense.category_id).group_by(Category.name)

    if user.role != 'admin':
        totals_by_category_query = totals_by_category_query.filter(Expense.user_id == user.id)
    if filters.get('date_from'):
        totals_by_category_query = totals_by_category_query.filter(Expense.expense_date >= filters['date_from'])
    if filters.get('date_to'):
        totals_by_category_query = totals_by_category_query.filter(Expense.expense_date <= filters['date_to'])

    totals_by_category = [
        {'category': category_name, 'amount': _to_float(amount)}
        for category_name, amount in totals_by_category_query.order_by(func.sum(Expense.amount).desc()).all()
    ]

    return {
        'title': 'Reporte de Gastos',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'filters': filters,
        'summary': {
            'records': len(expenses),
            'total_amount': sum(_to_float(item.amount) for item in expenses),
        },
        'totals_by_category': totals_by_category,
        'items': [
            {
                'date': _format_date(item.expense_date),
                'user_name': item.user.full_name if item.user else None,
                'description': item.description,
                'category': item.category.name if item.category else None,
                'payment_method': item.payment_method,
                'amount': _to_float(item.amount),
                'card_name': item.card.card_name if item.card else None,
                'bank_account': (
                    f"{item.bank_account.bank.name} - {item.bank_account.account_number}"
                    if item.bank_account and item.bank_account.bank
                    else None
                ),
            }
            for item in expenses
        ],
    }


def _build_planning_report(user, filters):
    month = filters.get('month') or date.today().month
    year = filters.get('year') or date.today().year

    plans = MonthlyPlanning.query.options(joinedload(MonthlyPlanning.category)).filter_by(
        month=month,
        year=year,
    ).all()

    expense_totals = db.session.query(
        Expense.category_id,
        func.coalesce(func.sum(Expense.amount), 0),
    ).filter(
        func.extract('month', Expense.expense_date) == month,
        func.extract('year', Expense.expense_date) == year,
    )

    if user.role != 'admin':
        expense_totals = expense_totals.filter(Expense.user_id == user.id)

    expense_totals = {
        category_id: _to_float(total)
        for category_id, total in expense_totals.group_by(Expense.category_id).all()
    }

    items = []
    for plan in plans:
        actual_amount = expense_totals.get(plan.category_id, 0.0)
        planned_amount = _to_float(plan.planned_amount)
        items.append({
            'category': plan.category.name if plan.category else 'Sin categoría',
            'planned_amount': planned_amount,
            'actual_amount': actual_amount,
            'remaining_amount': planned_amount - actual_amount,
        })

    return {
        'title': 'Reporte de Planificacion',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'filters': {
            **filters,
            'month': month,
            'year': year,
        },
        'summary': {
            'planned_total': sum(item['planned_amount'] for item in items),
            'actual_total': sum(item['actual_amount'] for item in items),
            'remaining_total': sum(item['remaining_amount'] for item in items),
            'records': len(items),
        },
        'items': items,
    }


def _table(name, columns, rows):
    return {'name': name, 'columns': columns, 'rows': rows}


def _build_expenses_category_report(user, filters):
    expenses = _apply_date_range(
        _expense_query_for_user(user),
        Expense.expense_date,
        filters,
    ).order_by(Expense.expense_date.desc(), Expense.created_at.desc()).all()

    totals_by_category = {}
    for item in expenses:
        category_name = item.category.name if item.category else 'Sin categoría'
        totals_by_category[category_name] = totals_by_category.get(category_name, 0.0) + _to_float(item.amount)

    ordered = sorted(totals_by_category.items(), key=lambda entry: entry[1], reverse=True)
    grand_total = sum(amount for _, amount in ordered)
    category_rows = [
        [
            category_name,
            amount,
            f'{((amount / grand_total) * 100) if grand_total else 0.0:.2f}%',
        ]
        for category_name, amount in ordered
    ]
    detail_rows = [
        [
            _format_date(item.expense_date),
            item.category.name if item.category else 'Sin categoría',
            item.description or '',
            item.payment_method,
            _to_float(item.amount),
        ]
        for item in expenses
    ]

    return {
        'title': 'Reporte de Gastos por Categoría',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'filters': filters,
        'summary': {
            'records': len(expenses),
            'total_amount': grand_total,
        },
        'tables': [
            _table('Totales por Categoría', ['Categoría', 'Monto', 'Porcentaje'], category_rows),
            _table('Detalle de Gastos', ['Fecha', 'Categoría', 'Descripción', 'Método de pago', 'Monto'], detail_rows),
        ],
    }


def _build_cards_report(user, filters):
    cards = _card_query_for_user(user).order_by(Card.created_at.desc()).all()
    total_debt = sum(_to_float(card.current_debt) for card in cards)
    total_available = sum(_to_float(card.available_balance) for card in cards)

    card_rows = [
        [
            card.card_name or '',
            card.card_type or '',
            card.owner or '',
            card.bank.name if card.bank else '',
            (
                f"{card.bank_account.bank.name} - {card.bank_account.account_number}"
                if card.bank_account and card.bank_account.bank
                else ''
            ),
            _to_float(card.credit_limit),
            _to_float(card.current_debt),
            _to_float(card.available_balance),
        ]
        for card in cards
    ]

    payments = _apply_date_range(
        _card_payment_query_for_user(user),
        CardPayment.payment_date,
        filters,
    ).order_by(CardPayment.payment_date.desc(), CardPayment.created_at.desc()).all()
    payment_rows = [
        [
            _format_date(payment.payment_date),
            payment.card.card_name if payment.card else '',
            payment.user.full_name if payment.user else '',
            _to_float(payment.amount),
            payment.status or '',
        ]
        for payment in payments
    ]

    return {
        'title': 'Reporte de Tarjetas',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'filters': filters,
        'summary': {
            'total_debt': total_debt,
            'total_available': total_available,
        },
        'tables': [
            _table(
                'Tarjetas',
                ['Tarjeta', 'Tipo', 'Titular', 'Banco', 'Cuenta', 'Límite', 'Deuda', 'Disponible'],
                card_rows,
            ),
            _table(
                'Pagos de Tarjetas',
                ['Fecha', 'Tarjeta', 'Usuario', 'Monto', 'Estado'],
                payment_rows,
            ),
        ],
    }


def _loan_remaining_balance(loan):
    paid_principal = LoanPayment.query.with_entities(
        func.coalesce(func.sum(LoanPayment.principal_paid), 0),
    ).filter(
        LoanPayment.loan_id == loan.id,
        LoanPayment.status == 'ACTIVO',
    ).scalar() or 0
    return max(0.0, _to_float(loan.initial_amount) - _to_float(paid_principal))


def _build_loans_report(user, filters):
    loans = _loan_query_for_user(user).order_by(Loan.created_at.desc()).all()
    total_remaining = 0.0
    loan_rows = []
    for loan in loans:
        remaining = _loan_remaining_balance(loan)
        total_remaining += remaining
        loan_rows.append([
            loan.description or '',
            loan.owner or '',
            loan.bank.name if loan.bank else '',
            _to_float(loan.initial_amount),
            _to_float(loan.monthly_payment),
            loan.pending_installments,
            loan.total_installments,
            remaining,
            _format_date(loan.start_date),
        ])

    payments = _apply_date_range(
        _loan_payment_query_for_user(user),
        LoanPayment.payment_date,
        filters,
    ).order_by(LoanPayment.payment_date.desc(), LoanPayment.created_at.desc()).all()
    payment_rows = [
        [
            _format_date(payment.payment_date),
            payment.loan.description if payment.loan else '',
            _to_float(payment.principal_paid),
            _to_float(payment.interest_paid),
            _to_float(payment.amount),
            _to_float(payment.balance_after),
            payment.status or '',
        ]
        for payment in payments
    ]

    return {
        'title': 'Reporte de Préstamos',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'filters': filters,
        'summary': {
            'total_remaining': total_remaining,
            'records': len(loans),
        },
        'tables': [
            _table(
                'Préstamos',
                ['Descripción', 'Titular', 'Banco', 'Monto inicial', 'Cuota mensual', 'Pendientes', 'Total cuotas', 'Saldo restante', 'Inicio'],
                loan_rows,
            ),
            _table(
                'Amortización',
                ['Fecha', 'Préstamo', 'Capital', 'Interés', 'Pago', 'Saldo después', 'Estado'],
                payment_rows,
            ),
        ],
    }


def _build_investments_report(user, filters):
    investments = _investment_query_for_user(user).order_by(Investment.created_at.desc()).all()
    total_invested = sum(_to_float(item.invested_amount) for item in investments)
    total_current = sum(_to_float(item.current_value) for item in investments)

    investment_rows = [
        [
            item.institution or '',
            item.investment_type or '',
            item.title or '',
            item.owner or '',
            _to_float(item.invested_amount),
            _to_float(item.current_value),
            _to_float(item.current_value) - _to_float(item.invested_amount),
            (
                f'{((_to_float(item.current_value) - _to_float(item.invested_amount)) / _to_float(item.invested_amount) * 100):.2f}%'
                if _to_float(item.invested_amount)
                else '0.00%'
            ),
            item.status or '',
            _format_date(item.start_date),
            _format_date(item.end_date),
        ]
        for item in investments
    ]

    return {
        'title': 'Reporte de Inversiones',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'filters': filters,
        'summary': {
            'total_invested': total_invested,
            'total_current': total_current,
            'total_profit': total_current - total_invested,
        },
        'tables': [
            _table(
                'Inversiones',
                ['Institución', 'Tipo', 'Título', 'Titular', 'Invertido', 'Valor actual', 'Ganancia', 'Rentabilidad', 'Estado', 'Inicio', 'Vencimiento'],
                investment_rows,
            ),
        ],
    }


def _build_assets_report(user, filters):
    assets = _asset_query_for_user(user).order_by(Asset.created_at.desc()).all()
    total_value = sum(_to_float(asset.value) for asset in assets)

    asset_rows = [
        [
            asset.name or '',
            _to_float(asset.value),
            asset.owner or '',
            asset.description or '',
            _format_date(asset.purchase_date),
        ]
        for asset in assets
    ]

    return {
        'title': 'Reporte de Activos',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'filters': filters,
        'summary': {
            'total_value': total_value,
            'records': len(assets),
        },
        'tables': [
            _table('Activos', ['Nombre', 'Valor', 'Titular', 'Descripción', 'Fecha de compra'], asset_rows),
        ],
    }


def _build_debts_report(user, filters):
    debtors = _debtor_query_for_user(user).filter_by(status='pendiente').order_by(Debtor.due_date.asc()).all()
    small_debts = _small_debt_query_for_user(user).filter_by(status='pendiente').order_by(SmallDebt.due_date.asc()).all()
    cards = _card_query_for_user(user).order_by(Card.created_at.desc()).all()
    loans = _loan_query_for_user(user).order_by(Loan.created_at.desc()).all()

    debtor_rows = [
        [debtor.name or '', _to_float(debtor.amount_owed), _format_date(debtor.due_date), debtor.description or '']
        for debtor in debtors
    ]
    small_debt_rows = [
        [debt.lender_name or '', _to_float(debt.amount), _format_date(debt.due_date), debt.description or '']
        for debt in small_debts
    ]
    card_rows = [
        [
            card.card_name or '',
            card.card_type or '',
            card.owner or '',
            _to_float(card.current_debt),
        ]
        for card in cards
        if _to_float(card.current_debt) > 0
    ]
    loan_rows = [
        [
            loan.description or '',
            loan.owner or '',
            _to_float(loan.monthly_payment),
            loan.pending_installments,
            _loan_remaining_balance(loan),
        ]
        for loan in loans
    ]

    total_to_collect = sum(_to_float(debtor.amount_owed) for debtor in debtors)
    total_to_pay = (
        sum(_to_float(debt.amount) for debt in small_debts)
        + sum(_to_float(card.current_debt) for card in cards)
        + sum(_loan_remaining_balance(loan) for loan in loans)
    )

    return {
        'title': 'Reporte de Deudas',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'filters': filters,
        'summary': {
            'total_to_collect': total_to_collect,
            'total_to_pay': total_to_pay,
        },
        'tables': [
            _table('Cuentas por Cobrar (Deudores)', ['Deudor', 'Monto', 'Vence', 'Descripción'], debtor_rows),
            _table('Micro Deudas por Pagar', ['Prestamista', 'Monto', 'Vence', 'Descripción'], small_debt_rows),
            _table('Deuda de Tarjetas', ['Tarjeta', 'Tipo', 'Titular', 'Deuda'], card_rows),
            _table('Deuda de Préstamos', ['Préstamo', 'Titular', 'Cuota mensual', 'Pendientes', 'Saldo restante'], loan_rows),
        ],
    }


def _build_net_worth_report(user, filters):
    account_balance = _account_query_for_user(user).with_entities(
        func.coalesce(func.sum(BankAccount.current_balance), 0),
    ).scalar() or 0
    total_assets = _asset_query_for_user(user).with_entities(
        func.coalesce(func.sum(Asset.value), 0),
    ).scalar() or 0
    investments_current = _investment_query_for_user(user).with_entities(
        func.coalesce(func.sum(Investment.current_value), 0),
    ).scalar() or 0
    total_card_debt = _card_query_for_user(user).with_entities(
        func.coalesce(func.sum(Card.current_debt), 0),
    ).scalar() or 0
    loans = _loan_query_for_user(user).all()
    total_loan_debt = sum(_loan_remaining_balance(loan) for loan in loans)
    small_debt_total = _small_debt_query_for_user(user).with_entities(
        func.coalesce(func.sum(SmallDebt.amount), 0),
    ).filter_by(status='pendiente').scalar() or 0

    assets_total = _to_float(account_balance) + _to_float(total_assets) + _to_float(investments_current)
    debts_total = _to_float(total_card_debt) + _to_float(total_loan_debt) + _to_float(small_debt_total)
    net_worth = assets_total - debts_total

    return {
        'title': 'Reporte de Patrimonio',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'filters': filters,
        'composition': [
            ['Saldo de cuentas bancarias', _to_float(account_balance)],
            ['Activos', _to_float(total_assets)],
            ['Inversiones (valor actual)', _to_float(investments_current)],
            ['Deuda de tarjetas', _to_float(total_card_debt)],
            ['Deuda de préstamos', _to_float(total_loan_debt)],
            ['Micro deudas por pagar', _to_float(small_debt_total)],
        ],
        'summary': {
            'total_assets': assets_total,
            'total_debt': debts_total,
            'net_worth': net_worth,
        },
        'tables': [
            _table(
                'Composición del Patrimonio',
                ['Concepto', 'Monto'],
                [
                    ['Saldo de cuentas bancarias', _to_float(account_balance)],
                    ['Activos', _to_float(total_assets)],
                    ['Inversiones (valor actual)', _to_float(investments_current)],
                    ['Deuda de tarjetas', _to_float(total_card_debt)],
                    ['Deuda de préstamos', _to_float(total_loan_debt)],
                    ['Micro deudas por pagar', _to_float(small_debt_total)],
                ],
            ),
            _table(
                'Resumen de Patrimonio',
                ['Concepto', 'Monto'],
                [
                    ['Total activos', assets_total],
                    ['Total deudas', debts_total],
                    ['Patrimonio neto', net_worth],
                ],
            ),
        ],
    }


def _build_audit_report(user, filters):
    if user.role != 'admin':
        raise ValueError('El reporte de auditoría requiere rol de administrador')

    query = AuditLog.query.options(joinedload(AuditLog.user))
    if filters.get('date_from'):
        date_from = datetime.combine(filters['date_from'], datetime.min.time())
        query = query.filter(AuditLog.created_at >= date_from)
    if filters.get('date_to'):
        date_to = datetime.combine(filters['date_to'], datetime.max.time())
        query = query.filter(AuditLog.created_at <= date_to)

    entries = query.order_by(AuditLog.created_at.desc()).all()
    rows = [
        [
            _format_date(entry.created_at),
            entry.user.full_name if entry.user else '',
            entry.action or '',
            entry.entity or '',
            entry.entity_id or '',
            entry.ip_address or '',
        ]
        for entry in entries
    ]

    return {
        'title': 'Reporte de Auditoría',
        'generated_at': datetime.utcnow().isoformat(),
        'scope_user': user.full_name,
        'scope_role': user.role,
        'filters': filters,
        'summary': {
            'records': len(entries),
        },
        'tables': [
            _table('Registro de Auditoría', ['Fecha', 'Usuario', 'Acción', 'Entidad', 'ID', 'IP'], rows),
        ],
    }


def _build_report_payload(user, report_type, filters):
    builders = {
        'summary': _build_summary_report,
        'movements': _build_movements_report,
        'accounts': _build_accounts_report,
        'expenses': _build_expenses_report,
        'planning': _build_planning_report,
        'expenses-category': _build_expenses_category_report,
        'cards': _build_cards_report,
        'loans': _build_loans_report,
        'investments': _build_investments_report,
        'assets': _build_assets_report,
        'debts': _build_debts_report,
        'net-worth': _build_net_worth_report,
        'audit': _build_audit_report,
    }
    return builders[report_type](user, filters)


def _append_xml(parent, key, value):
    if isinstance(value, dict):
        node = ET.SubElement(parent, key)
        for child_key, child_value in value.items():
            _append_xml(node, child_key, child_value)
        return

    if isinstance(value, list):
        node = ET.SubElement(parent, key)
        for item in value:
            item_node = ET.SubElement(node, 'item')
            if isinstance(item, dict):
                for child_key, child_value in item.items():
                    _append_xml(item_node, child_key, child_value)
            else:
                item_node.text = '' if item is None else str(item)
        return

    node = ET.SubElement(parent, key)
    node.text = '' if value is None else str(value)


def _render_xml_report(report_type, payload):
    root = ET.Element(
        'family_finance_report',
        attrib={
            'type': report_type,
            'generated_at': payload.get('generated_at', ''),
            'format_version': '1',
        },
    )
    for key, value in payload.items():
        _append_xml(root, key, value)

    ET.indent(root, space='  ')
    xml_content = ET.tostring(root, encoding='utf-8', xml_declaration=True)
    return BytesIO(xml_content)


def _payload_tables(report_type, payload):
    tables = payload.get('tables')
    if tables:
        return tables

    if report_type == 'summary':
        return [
            _table('Indicadores', ['Concepto', 'Valor'], [[key, value] for key, value in (payload.get('stats') or {}).items()]),
            _table('Registros', ['Concepto', 'Cantidad'], [[key, value] for key, value in (payload.get('counts') or {}).items()]),
            _table(
                'Gastos recientes',
                ['Fecha', 'Usuario', 'Descripción', 'Categoría', 'Método de pago', 'Monto'],
                [
                    [
                        item['date'],
                        item.get('user_name'),
                        item.get('description'),
                        item.get('category'),
                        item.get('payment_method'),
                        item.get('amount'),
                    ]
                    for item in (payload.get('recent_expenses') or [])
                ],
            ),
        ]

    if report_type == 'movements':
        totals = payload.get('totals') or {}
        return [
            _table(
                'Totales',
                ['Ingresos', 'Gastos', 'Neto', 'Registros'],
                [[totals.get('total_in'), totals.get('total_out'), totals.get('net_total'), totals.get('records')]],
            ),
            _table(
                'Movimientos',
                ['Fecha', 'Tipo', 'Detalle', 'Referencia', 'Usuario', 'Ingreso', 'Egreso', 'Neto'],
                [
                    [
                        item['date'],
                        item['movement_type'],
                        item['detail'],
                        item['reference'],
                        item['user_name'],
                        item['amount_in'],
                        item['amount_out'],
                        item['net_amount'],
                    ]
                    for item in (payload.get('items') or [])
                ],
            ),
        ]

    if report_type == 'accounts':
        return [
            _table('Bancos', ['Nombre', 'Descripción'], [[bank.get('name'), bank.get('description')] for bank in (payload.get('banks') or [])]),
            _table(
                'Cuentas bancarias',
                ['Banco', 'Número', 'Tipo', 'Titular', 'Saldo'],
                [
                    [
                        account.get('bank_name'),
                        account.get('account_number'),
                        account.get('account_type'),
                        account.get('owner'),
                        account.get('current_balance'),
                    ]
                    for account in (payload.get('accounts') or [])
                ],
            ),
            _table(
                'Tarjetas',
                ['Tarjeta', 'Tipo', 'Titular', 'Banco', 'Cuenta', 'Límite', 'Deuda', 'Disponible'],
                [
                    [
                        card.get('card_name'),
                        card.get('card_type'),
                        card.get('owner'),
                        card.get('bank_name'),
                        card.get('bank_account_name'),
                        card.get('credit_limit'),
                        card.get('current_debt'),
                        card.get('available_balance'),
                    ]
                    for card in (payload.get('cards') or [])
                ],
            ),
            _table(
                'Préstamos',
                ['Descripción', 'Banco', 'Titular', 'Monto inicial', 'Cuota mensual', 'Pendientes', 'Total cuotas', 'Inicio'],
                [
                    [
                        loan.get('description'),
                        loan.get('bank_name'),
                        loan.get('owner'),
                        loan.get('initial_amount'),
                        loan.get('monthly_payment'),
                        loan.get('pending_installments'),
                        loan.get('total_installments'),
                        loan.get('start_date'),
                    ]
                    for loan in (payload.get('loans') or [])
                ],
            ),
        ]

    if report_type == 'expenses':
        summary = payload.get('summary') or {}
        return [
            _table(
                'Resumen',
                ['Registros', 'Total'],
                [[summary.get('records'), summary.get('total_amount')]],
            ),
            _table(
                'Totales por categoría',
                ['Categoría', 'Monto'],
                [[item.get('category'), item.get('amount')] for item in (payload.get('totals_by_category') or [])],
            ),
            _table(
                'Detalle de gastos',
                ['Fecha', 'Usuario', 'Descripción', 'Categoría', 'Método de pago', 'Monto', 'Tarjeta', 'Cuenta'],
                [
                    [
                        item.get('date'),
                        item.get('user_name'),
                        item.get('description'),
                        item.get('category'),
                        item.get('payment_method'),
                        item.get('amount'),
                        item.get('card_name'),
                        item.get('bank_account'),
                    ]
                    for item in (payload.get('items') or [])
                ],
            ),
        ]

    if report_type == 'planning':
        summary = payload.get('summary') or {}
        return [
            _table(
                'Resumen',
                ['Presupuestado', 'Ejecutado', 'Restante', 'Registros'],
                [[summary.get('planned_total'), summary.get('actual_total'), summary.get('remaining_total'), summary.get('records')]],
            ),
            _table(
                'Detalle de planificación',
                ['Categoría', 'Plan', 'Real', 'Restante'],
                [
                    [item.get('category'), item.get('planned_amount'), item.get('actual_amount'), item.get('remaining_amount')]
                    for item in (payload.get('items') or [])
                ],
            ),
        ]

    return []


def _render_csv_report(report_type, payload):
    buffer = StringIO()
    writer = csv.writer(buffer)
    for table in _payload_tables(report_type, payload):
        writer.writerow([f'# {table["name"]}'])
        writer.writerow(table['columns'])
        for row in table['rows']:
            writer.writerow([cell if cell is not None else '' for cell in row])
        writer.writerow([])
    content = '\ufeff' + buffer.getvalue()
    return BytesIO(content.encode('utf-8'))


XLSX_COL_LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'


def _xlsx_col_ref(index):
    letters = ''
    value = index
    while value > 0:
        value, remainder = divmod(value - 1, 26)
        letters = XLSX_COL_LETTERS[remainder] + letters
    return letters


def _xlsx_escape(value):
    return str(value).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def _render_xlsx_sheet_xml(table):
    header = table['columns']
    cell_rows = []
    for row_index, row in enumerate([header] + [[cell if cell is not None else '' for cell in r] for r in table['rows']], start=1):
        cells_xml = []
        for col_index, cell in enumerate(row, start=1):
            ref = f'{_xlsx_col_ref(col_index)}{row_index}'
            if isinstance(cell, (int, float)) and not isinstance(cell, bool):
                cells_xml.append(f'<c r="{ref}"><v>{cell}</v></c>')
            else:
                cells_xml.append(f'<c r="{ref}" t="inlineStr"><is><t>{_xlsx_escape(cell)}</t></is></c>')
        cell_rows.append(f'<row r="{row_index}">{"".join(cells_xml)}</row>')
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        f'<sheetData>{"".join(cell_rows)}</sheetData></worksheet>'
    )


def _render_xlsx_report(report_type, payload):
    tables = _payload_tables(report_type, payload)
    seen_names = {}

    def make_sheet_name(index, raw_name):
        sanitized = ''.join(char for char in raw_name if char not in '[]:*?/\\')
        sanitized = (sanitized or f'Hoja{index}')[:31]
        count = seen_names.get(sanitized, 0)
        seen_names[sanitized] = count + 1
        if count:
            suffix = f'_{count}'
            sanitized = f'{sanitized[:31 - len(suffix)]}{suffix}'
        return sanitized

    sheet_names = []
    worksheets = []
    for index, table in enumerate(tables, start=1):
        sheet_name = make_sheet_name(index, table['name'])
        sheet_names.append(sheet_name)
        worksheets.append(f'xl/worksheets/sheet{index}.xml')

    output = BytesIO()
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        content_types = [
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
            '<Default Extension="xml" ContentType="application/xml"/>',
            f'<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
        ]
        for index in range(1, len(tables) + 1):
            content_types.append(
                f'<Override PartName="/xl/worksheets/sheet{index}.xml" '
                'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
            )
        content_types.append('</Types>')
        archive.writestr('[Content_Types].xml', ''.join(content_types))

        archive.writestr(
            '_rels/.rels',
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
            '</Relationships>',
        )

        sheets_xml = []
        for index, sheet_name in enumerate(sheet_names, start=1):
            sheets_xml.append(f'<sheet name="{_xlsx_escape(sheet_name)}" sheetId="{index}" r:id="rId{index}"/>')
        archive.writestr(
            'xl/workbook.xml',
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            f'<sheets>{"".join(sheets_xml)}</sheets></workbook>',
        )

        rels_xml = []
        for index in range(1, len(tables) + 1):
            rels_xml.append(
                f'<Relationship Id="rId{index}" '
                'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
                f'Target="worksheets/sheet{index}.xml"/>'
            )
        archive.writestr(
            'xl/_rels/workbook.xml.rels',
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            f'{"".join(rels_xml)}</Relationships>',
        )

        for index, table in enumerate(tables, start=1):
            archive.writestr(
                f'xl/worksheets/sheet{index}.xml',
                _render_xlsx_sheet_xml(table),
            )

    output.seek(0)
    return output


def _pdf_text(value):
    normalized = unicodedata.normalize('NFKD', str(value or ''))
    ascii_text = normalized.encode('ascii', 'ignore').decode('ascii')
    return ascii_text.replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')


def _paginate_pdf_lines(lines, lines_per_page=46):
    return [lines[index:index + lines_per_page] for index in range(0, len(lines), lines_per_page)] or [[]]


def _render_simple_pdf(lines):
    pages = _paginate_pdf_lines(lines)
    objects = []

    def add_object(content):
        objects.append(content)
        return len(objects)

    font_id = add_object('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    page_ids = []
    content_ids = []

    for page_lines in pages:
        stream_commands = ['BT', '/F1 10 Tf', '40 770 Td', '14 TL']
        first_line = True
        for line in page_lines:
            safe_line = _pdf_text(line)
            if first_line:
                stream_commands.append(f'({safe_line}) Tj')
                first_line = False
            else:
                stream_commands.append('T*')
                stream_commands.append(f'({safe_line}) Tj')
        stream_commands.append('ET')
        stream = '\n'.join(stream_commands).encode('latin-1', 'ignore')
        content_id = add_object(
            f'<< /Length {len(stream)} >>\nstream\n{stream.decode("latin-1")}\nendstream'
        )
        content_ids.append(content_id)
        page_ids.append(None)

    pages_id = add_object('')
    for index, content_id in enumerate(content_ids):
        page_id = add_object(
            f'<< /Type /Page /Parent {pages_id} 0 R /MediaBox [0 0 612 792] '
            f'/Resources << /Font << /F1 {font_id} 0 R >> >> /Contents {content_id} 0 R >>'
        )
        page_ids[index] = page_id

    objects[pages_id - 1] = f'<< /Type /Pages /Count {len(page_ids)} /Kids [{" ".join(f"{page_id} 0 R" for page_id in page_ids)}] >>'
    catalog_id = add_object(f'<< /Type /Catalog /Pages {pages_id} 0 R >>')

    output = BytesIO()
    output.write(b'%PDF-1.4\n%\xe2\xe3\xcf\xd3\n')
    offsets = [0]
    for object_id, content in enumerate(objects, start=1):
        offsets.append(output.tell())
        output.write(f'{object_id} 0 obj\n'.encode('latin-1'))
        output.write(content.encode('latin-1'))
        output.write(b'\nendobj\n')

    xref_position = output.tell()
    output.write(f'xref\n0 {len(objects) + 1}\n'.encode('latin-1'))
    output.write(b'0000000000 65535 f \n')
    for offset in offsets[1:]:
        output.write(f'{offset:010d} 00000 n \n'.encode('latin-1'))
    output.write(
        f'trailer\n<< /Size {len(objects) + 1} /Root {catalog_id} 0 R >>\nstartxref\n{xref_position}\n%%EOF'.encode('latin-1')
    )
    output.seek(0)
    return output


def _payload_to_pdf_lines(report_type, payload):
    lines = [
        payload.get('title', 'Reporte'),
        f'Generado: {_format_date(payload.get("generated_at"))}',
        f'Usuario: {payload.get("scope_user", "")} ({payload.get("scope_role", "")})',
        '',
    ]

    filters = payload.get('filters') or {}
    if filters:
        lines.append('Filtros aplicados:')
        for key, value in filters.items():
            if value not in [None, '']:
                lines.append(f'- {key}: {_format_date(value)}')
        lines.append('')

    if report_type == 'summary':
        lines.append('Indicadores:')
        for key, value in (payload.get('stats') or {}).items():
            lines.append(f'- {key}: {_format_money(value)}')
        lines.append('')
        lines.append('Totales de registros:')
        for key, value in (payload.get('counts') or {}).items():
            lines.append(f'- {key}: {value}')
        lines.append('')
        lines.append('Gastos recientes:')
        for item in payload.get('recent_expenses') or []:
            lines.append(
                f'- {item["date"]} | {item.get("category") or "Sin categoría"} | '
                f'{item.get("description") or "Sin descripcion"} | {_format_money(item["amount"])}'
            )

    if report_type == 'movements':
        totals = payload.get('totals') or {}
        lines.extend([
            'Totales:',
            f'- Ingresos: {_format_money(totals.get("total_in"))}',
            f'- Gastos: {_format_money(totals.get("total_out"))}',
            f'- Neto: {_format_money(totals.get("net_total"))}',
            f'- Registros: {totals.get("records", 0)}',
            '',
            'Detalle de movimientos:',
        ])
        for item in payload.get('items') or []:
            lines.append(
                f'- {item["date"]} | {item["movement_type"]} | {item["detail"]} | '
                f'+{_format_money(item["amount_in"])} / -{_format_money(item["amount_out"])}'
            )

    if report_type == 'accounts':
        lines.append('Bancos:')
        for bank in payload.get('banks') or []:
            lines.append(f'- {bank.get("name")} | {bank.get("description") or ""}')
        lines.append('')
        lines.append('Cuentas bancarias:')
        for account in payload.get('accounts') or []:
            lines.append(
                f'- {account.get("bank_name") or "Sin banco"} | {account.get("account_number") or ""} | '
                f'{account.get("owner") or ""} | {_format_money(account.get("current_balance"))}'
            )
        lines.append('')
        lines.append('Tarjetas:')
        for card in payload.get('cards') or []:
            lines.append(
                f'- {card.get("card_name") or ""} | {card.get("card_type") or ""} | '
                f'{card.get("bank_account_name") or ""} | '
                f'deuda {_format_money(card.get("current_debt"))} | disponible {_format_money(card.get("available_balance"))}'
            )
        lines.append('')
        lines.append('Prestamos:')
        for loan in payload.get('loans') or []:
            lines.append(
                f'- {loan.get("description") or ""} | cuota {_format_money(loan.get("monthly_payment"))} | '
                f'{loan.get("pending_installments", 0)}/{loan.get("total_installments", 0)} pendientes'
            )

    if report_type == 'expenses':
        summary = payload.get('summary') or {}
        lines.extend([
            'Resumen:',
            f'- Registros: {summary.get("records", 0)}',
            f'- Total: {_format_money(summary.get("total_amount"))}',
            '',
            'Totales por categoría:',
        ])
        for item in payload.get('totals_by_category') or []:
            lines.append(f'- {item.get("category")}: {_format_money(item.get("amount"))}')
        lines.append('')
        lines.append('Detalle de gastos:')
        for item in payload.get('items') or []:
            lines.append(
                f'- {item["date"]} | {item.get("category") or "Sin categoría"} | '
                f'{item.get("description") or "Sin descripcion"} | {_format_money(item.get("amount"))}'
            )

    if report_type == 'planning':
        summary = payload.get('summary') or {}
        lines.extend([
            'Resumen:',
            f'- Presupuestado: {_format_money(summary.get("planned_total"))}',
            f'- Ejecutado: {_format_money(summary.get("actual_total"))}',
            f'- Restante: {_format_money(summary.get("remaining_total"))}',
            f'- Registros: {summary.get("records", 0)}',
            '',
            'Detalle de planificacion:',
        ])
        for item in payload.get('items') or []:
            lines.append(
                f'- {item.get("category")}: plan {_format_money(item.get("planned_amount"))}, '
                f'real {_format_money(item.get("actual_amount"))}, restante {_format_money(item.get("remaining_amount"))}'
            )

    if report_type in TABULAR_REPORTS:
        for table in payload.get('tables') or []:
            lines.append('')
            lines.append(f'{table["name"]}:')
            lines.append(' | '.join(table['columns']))
            for row in table['rows']:
                cells = [
                    _format_money(cell) if isinstance(cell, (int, float)) and not isinstance(cell, bool) else str(cell or '')
                    for cell in row
                ]
                lines.append(' | '.join(cells))

    return lines


def _render_pdf_report(report_type, payload):
    lines = _payload_to_pdf_lines(report_type, payload)
    return _render_simple_pdf(lines)


@reports_bp.route('/export', methods=['GET'])
@jwt_required()
def export_report():
    try:
        user, context = _get_request_context()
        if not user:
            return jsonify({'msg': 'User not found'}), 404

        payload = _build_report_payload(user, context['report_type'], context['filters'])
        filename = _build_filename(context['report_type'], context['output_format'])

        if context['output_format'] == 'xml':
            file_obj = _render_xml_report(context['report_type'], payload)
            mimetype = 'application/xml'
        elif context['output_format'] == 'csv':
            file_obj = _render_csv_report(context['report_type'], payload)
            mimetype = 'text/csv'
        elif context['output_format'] == 'xlsx':
            file_obj = _render_xlsx_report(context['report_type'], payload)
            mimetype = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        else:
            file_obj = _render_pdf_report(context['report_type'], payload)
            mimetype = 'application/pdf'

        return send_file(
            file_obj,
            mimetype=mimetype,
            as_attachment=True,
            download_name=filename,
        )
    except ValueError as error:
        return jsonify({'msg': str(error)}), 400
