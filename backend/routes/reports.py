from datetime import date, datetime
from decimal import Decimal
from io import BytesIO
import unicodedata
import xml.etree.ElementTree as ET

from flask import Blueprint, jsonify, request, send_file
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy import func
from sqlalchemy.orm import joinedload

try:
    from backend.models import (
        Asset,
        Bank,
        BankAccount,
        Card,
        Category,
        Expense,
        Income,
        Investment,
        Loan,
        MonthlyPlanning,
        SmallDebt,
        Debtor,
        User,
        db,
    )
except ModuleNotFoundError:
    from models import (
        Asset,
        Bank,
        BankAccount,
        Card,
        Category,
        Expense,
        Income,
        Investment,
        Loan,
        MonthlyPlanning,
        SmallDebt,
        Debtor,
        User,
        db,
    )

reports_bp = Blueprint('reports', __name__)

SUPPORTED_REPORTS = {'summary', 'movements', 'accounts', 'expenses', 'planning'}
SUPPORTED_FORMATS = {'pdf', 'xml'}


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
    query = Card.query.options(joinedload(Card.bank), joinedload(Card.user))
    if user.role != 'admin':
        query = query.filter(Card.user_id == user.id)
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


def _apply_date_range(query, column, filters):
    if filters.get('date_from'):
        query = query.filter(column >= filters['date_from'])
    if filters.get('date_to'):
        query = query.filter(column <= filters['date_to'])
    return query


def _build_summary_report(user, filters):
    today = date.today()
    account_balance = db.session.query(func.coalesce(func.sum(BankAccount.current_balance), 0)).scalar() or 0
    total_assets = db.session.query(func.coalesce(func.sum(Asset.value), 0)).scalar() or 0
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
            'accounts': BankAccount.query.count(),
            'cards': _card_query_for_user(user).count(),
            'loans': _loan_query_for_user(user).count(),
            'assets': Asset.query.count(),
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
    accounts = BankAccount.query.options(joinedload(BankAccount.bank)).order_by(BankAccount.created_at.desc()).all()
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


def _build_report_payload(user, report_type, filters):
    builders = {
        'summary': _build_summary_report,
        'movements': _build_movements_report,
        'accounts': _build_accounts_report,
        'expenses': _build_expenses_report,
        'planning': _build_planning_report,
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
                f'- {item["date"]} | {item.get("category") or "Sin categoria"} | '
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
            'Totales por categoria:',
        ])
        for item in payload.get('totals_by_category') or []:
            lines.append(f'- {item.get("category")}: {_format_money(item.get("amount"))}')
        lines.append('')
        lines.append('Detalle de gastos:')
        for item in payload.get('items') or []:
            lines.append(
                f'- {item["date"]} | {item.get("category") or "Sin categoria"} | '
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
