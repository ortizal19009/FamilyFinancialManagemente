from collections import defaultdict
from datetime import date, datetime

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy import func, inspect
from sqlalchemy.orm import joinedload

try:
    from backend.models import (
        Asset,
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
        MonthlyPlanning,
        SmallDebt,
        User,
        db,
    )
except ModuleNotFoundError:
    from models import (
        Asset,
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
        MonthlyPlanning,
        SmallDebt,
        User,
        db,
    )

dashboard_bp = Blueprint('dashboard', __name__)

_DATE_FMT = '%Y-%m-%d'


def _scoped(query, model, user_id, is_admin):
    if not is_admin:
        query = query.filter(model.user_id == user_id)
    return query


def _has_investments_table():
    return inspect(db.engine).has_table('investments')


def _month_key(value):
    return value.year, value.month


def _months_ago(n, ref):
    total = ref.year * 12 + (ref.month - 1) - n
    year, month = divmod(total, 12)
    return date(year, month + 1, 1)


def _period_bounds():
    ref = date.today()
    period = (request.args.get('range', 'month') or 'month').strip().lower()
    start_str, end_str = request.args.get('start'), request.args.get('end')
    if start_str:
        start = datetime.strptime(start_str, _DATE_FMT).date()
    elif period == 'year':
        start = _months_ago(11, ref)
    elif period == 'semester':
        start = _months_ago(5, ref)
    elif period == 'quarter':
        start = _months_ago(2, ref)
    else:
        start = _months_ago(0, ref)
    if end_str:
        end = datetime.strptime(end_str, _DATE_FMT).date()
    else:
        end = ref
    return start, end


def _month_buckets(start, end):
    buckets = []
    year, month = start.year, start.month
    while (year, month) <= (end.year, end.month):
        buckets.append((year, month))
        month += 1
        if month > 12:
            month = 1
            year += 1
    return buckets


def _expenses_in_range(user, start, end):
    query = Expense.query.options(joinedload(Expense.category)).filter(
        Expense.status == 'ACTIVO',
        Expense.expense_date >= start,
        Expense.expense_date <= end,
    )
    return _scoped(query, Expense, user.id, user.role == 'admin').all()


def _income_in_range(user, start, end):
    query = Income.query.filter(
        Income.status == 'ACTIVO',
        Income.income_date >= start,
        Income.income_date <= end,
    )
    return _scoped(query, Income, user.id, user.role == 'admin').all()


def _loan_outstanding(user, is_admin):
    query = Loan.query.with_entities(
        func.coalesce(func.sum(Loan.pending_installments * Loan.monthly_payment), 0)
    )
    return float(_scoped(query, Loan, user.id, is_admin).scalar() or 0)


@dashboard_bp.route('/summary', methods=['GET'])
@jwt_required()
def get_dashboard_summary():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    is_admin = user.role == 'admin'
    today = date.today()

    account_balance_query = _scoped(
        BankAccount.query.with_entities(func.coalesce(func.sum(BankAccount.current_balance), 0)),
        BankAccount, user_id, is_admin,
    )
    cards_debt_query = _scoped(
        Card.query.with_entities(func.coalesce(func.sum(Card.current_debt), 0)),
        Card, user_id, is_admin,
    )
    loans_query = _scoped(
        Loan.query.with_entities(func.coalesce(func.sum(Loan.pending_installments * Loan.monthly_payment), 0)),
        Loan, user_id, is_admin,
    )
    assets_query = _scoped(
        Asset.query.with_entities(func.coalesce(func.sum(Asset.value), 0)),
        Asset, user_id, is_admin,
    )
    receivable_query = _scoped(
        Debtor.query.with_entities(func.coalesce(func.sum(Debtor.amount_owed), 0)),
        Debtor, user_id, is_admin,
    )
    payable_query = _scoped(
        SmallDebt.query.with_entities(func.coalesce(func.sum(SmallDebt.amount), 0)),
        SmallDebt, user_id, is_admin,
    )

    monthly_expenses_query = _scoped(
        Expense.query.with_entities(func.coalesce(func.sum(Expense.amount), 0)).filter(
            Expense.status == 'ACTIVO',
            func.extract('month', Expense.expense_date) == today.month,
            func.extract('year', Expense.expense_date) == today.year,
        ),
        Expense, user_id, is_admin,
    )
    monthly_income_query = _scoped(
        Income.query.with_entities(func.coalesce(func.sum(Income.amount), 0)).filter(
            Income.status == 'ACTIVO',
            func.extract('month', Income.income_date) == today.month,
            func.extract('year', Income.income_date) == today.year,
        ),
        Income, user_id, is_admin,
    )

    recent_expenses = _scoped(
        Expense.query.options(joinedload(Expense.user), joinedload(Expense.category))
        .order_by(Expense.expense_date.desc()),
        Expense, user_id, is_admin,
    ).limit(5).all()

    available_balance = float(account_balance_query.scalar() or 0)
    credit_card_debt = float(cards_debt_query.scalar() or 0)
    loan_debt = float(loans_query.scalar() or 0)
    total_assets = float(assets_query.scalar() or 0)
    receivables = float(receivable_query.scalar() or 0)
    payables = float(payable_query.scalar() or 0)
    monthly_expenses = float(monthly_expenses_query.scalar() or 0)
    monthly_income = float(monthly_income_query.scalar() or 0)
    monthly_savings = round(monthly_income - monthly_expenses, 2)
    savings_rate = round((monthly_savings / monthly_income) * 100, 2) if monthly_income else 0.0

    investments_current_value = 0.0
    investments_invested_amount = 0.0
    if _has_investments_table():
        investments_query = Investment.query.with_entities(
            func.coalesce(func.sum(Investment.current_value), 0),
            func.coalesce(func.sum(Investment.invested_amount), 0),
        )
        if not is_admin:
            investments_query = investments_query.filter(Investment.user_id == user_id)
        investments_current_value, investments_invested_amount = investments_query.first()
        investments_current_value = float(investments_current_value or 0)
        investments_invested_amount = float(investments_invested_amount or 0)

    total_debt = credit_card_debt + loan_debt
    net_worth = available_balance + total_assets + investments_current_value - total_debt

    planning_rows = MonthlyPlanning.query.filter_by(
        month=today.month, year=today.year
    ).options(joinedload(MonthlyPlanning.category)).all()
    planned_categories = {row.category_id for row in planning_rows}
    planned_total = float(sum(float(row.planned_amount) or 0 for row in planning_rows))
    used_total = 0.0
    if planned_categories:
        budget_used_query = Expense.query.with_entities(
            func.coalesce(func.sum(Expense.amount), 0)
        ).filter(
            Expense.status == 'ACTIVO',
            Expense.category_id.in_(planned_categories),
            func.extract('month', Expense.expense_date) == today.month,
            func.extract('year', Expense.expense_date) == today.year,
        )
        if not is_admin:
            budget_used_query = budget_used_query.filter(Expense.user_id == user_id)
        used_total = float(budget_used_query.scalar() or 0)

    return jsonify({
        "stats": {
            "availableBalance": round(available_balance, 2),
            "totalDebt": round(total_debt, 2),
            "creditCardDebt": round(credit_card_debt, 2),
            "loanDebt": round(loan_debt, 2),
            "monthlyExpenses": round(monthly_expenses, 2),
            "monthlyIncome": round(monthly_income, 2),
            "monthlySavings": monthly_savings,
            "savingsRate": savings_rate,
            "totalAssets": round(total_assets, 2),
            "investmentsCurrentValue": round(investments_current_value, 2),
            "investmentsInvestedAmount": round(investments_invested_amount, 2),
            "receivables": round(receivables, 2),
            "payables": round(payables, 2),
            "netWorth": round(net_worth, 2),
            "budgetPlanned": round(planned_total, 2),
            "budgetUsed": round(used_total, 2),
            "budgetUsedPercent": round((used_total / planned_total) * 100, 2) if planned_total else 0.0,
        },
        "recentExpenses": [{
            "id": expense.id,
            "user_id": expense.user_id,
            "user_name": expense.user.full_name if expense.user else 'N/A',
            "category_name": expense.category.name if expense.category else None,
            "amount": float(expense.amount),
            "payment_method": expense.payment_method,
            "expense_date": expense.expense_date.strftime(_DATE_FMT),
            "description": expense.description,
        } for expense in recent_expenses],
    }), 200


@dashboard_bp.route('/income-vs-expenses', methods=['GET'])
@jwt_required()
def income_vs_expenses():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    start, end = _period_bounds()
    expenses = _expenses_in_range(user, start, end)
    incomes = _income_in_range(user, start, end)

    expense_by_month = defaultdict(float)
    for expense in expenses:
        expense_by_month[_month_key(expense.expense_date)] += float(expense.amount or 0)
    income_by_month = defaultdict(float)
    for income in incomes:
        income_by_month[_month_key(income.income_date)] += float(income.amount or 0)

    series = []
    for year, month in _month_buckets(start, end):
        income = round(income_by_month.get((year, month), 0.0), 2)
        expense = round(expense_by_month.get((year, month), 0.0), 2)
        series.append({
            "month": f"{year:04d}-{month:02d}",
            "income": income,
            "expenses": expense,
        })

    return jsonify({
        "start": start.strftime(_DATE_FMT),
        "end": end.strftime(_DATE_FMT),
        "series": series,
    }), 200


@dashboard_bp.route('/expenses-by-category', methods=['GET'])
@jwt_required()
def expenses_by_category():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    start, end = _period_bounds()
    expenses = _expenses_in_range(user, start, end)

    totals = defaultdict(float)
    for expense in expenses:
        name = expense.category.name if expense.category else 'Sin categoría'
        totals[name] += float(expense.amount or 0)

    total = round(sum(totals.values()), 2)
    return jsonify({
        "start": start.strftime(_DATE_FMT),
        "end": end.strftime(_DATE_FMT),
        "total": total,
        "categories": [
            {
                "name": name,
                "amount": round(amount, 2),
                "percentage": round((amount / total) * 100, 2) if total else 0.0,
            }
            for name, amount in sorted(totals.items(), key=lambda item: -item[1])
        ],
    }), 200


@dashboard_bp.route('/money-by-institution', methods=['GET'])
@jwt_required()
def money_by_institution():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    query = (
        db.session.query(Bank.name, BankAccount)
        .join(Bank, BankAccount.bank_id == Bank.id)
        .order_by(BankAccount.created_at.desc())
    )
    if user.role != 'admin':
        query = query.filter(BankAccount.user_id == user_id)

    institutions = defaultdict(list)
    for bank_name, account in query.all():
        institutions[bank_name or 'Sin banco'].append({
            "account_id": account.id,
            "account_number": account.account_number,
            "balance": round(float(account.current_balance or 0), 2),
        })

    def _institution_total(accounts):
        return round(sum(account['balance'] for account in accounts), 2)

    total = round(sum(_institution_total(accounts) for accounts in institutions.values()), 2)
    return jsonify({
        "total": total,
        "institutions": [
            {
                "name": name,
                "total": _institution_total(accounts),
                "accounts": accounts,
            }
            for name, accounts in sorted(institutions.items(), key=lambda item: -_institution_total(item[1]))
        ],
    }), 200


@dashboard_bp.route('/assets-distribution', methods=['GET'])
@jwt_required()
def assets_distribution():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    assets_query = _scoped(Asset.query, Asset, user_id, user.role == 'admin').all()
    total = float(sum(float(asset.value or 0) for asset in assets_query))
    return jsonify({
        "total": round(total, 2),
        "assets": [
            {
                "id": asset.id,
                "name": asset.name,
                "value": round(float(asset.value or 0), 2),
                "percentage": round((float(asset.value or 0) / total) * 100, 2) if total else 0.0,
            }
            for asset in sorted(assets_query, key=lambda item: -float(item.value or 0))
        ],
    }), 200


@dashboard_bp.route('/budget-vs-actual', methods=['GET'])
@jwt_required()
def budget_vs_actual():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    start, end = _period_bounds()
    month, year = end.month, end.year

    planning_rows = MonthlyPlanning.query.options(joinedload(MonthlyPlanning.category)).filter_by(
        month=month, year=year
    ).all()

    expenses = _scoped(
        Expense.query.filter(
            Expense.status == 'ACTIVO',
            func.extract('month', Expense.expense_date) == month,
            func.extract('year', Expense.expense_date) == year,
            Expense.category_id.isnot(None),
        ),
        Expense, user_id, user.role == 'admin',
    ).all()

    actual_by_category = defaultdict(float)
    for expense in expenses:
        actual_by_category[expense.category_id] += float(expense.amount or 0)

    rows = []
    planned_total = 0.0
    for row in planning_rows:
        planned = float(row.planned_amount or 0)
        planned_total += planned
        actual = round(actual_by_category.get(row.category_id, 0.0), 2)
        rows.append({
            "category_id": row.category_id,
            "category_name": row.category.name if row.category else 'Sin categoría',
            "planned": round(planned, 2),
            "actual": actual,
            "used_percent": round((actual / planned) * 100, 2) if planned else 0.0,
        })

    used_total = round(sum(row['actual'] for row in rows), 2)
    return jsonify({
        "start": start.strftime(_DATE_FMT),
        "end": end.strftime(_DATE_FMT),
        "month": f"{year:04d}-{month:02d}",
        "plannedTotal": round(planned_total, 2),
        "usedTotal": used_total,
        "usedPercent": round((used_total / planned_total) * 100, 2) if planned_total else 0.0,
        "rows": rows,
    }), 200


@dashboard_bp.route('/debt-evolution', methods=['GET'])
@jwt_required()
def debt_evolution():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    is_admin = user.role == 'admin'
    start, end = _period_bounds()

    monthly_reduction = defaultdict(float)
    card_payments = _scoped(
        CardPayment.query.filter(
            CardPayment.status == 'ACTIVO',
            CardPayment.payment_date >= start,
            CardPayment.payment_date <= end,
        ),
        CardPayment, user_id, is_admin,
    ).all()
    for payment in card_payments:
        monthly_reduction[_month_key(payment.payment_date)] += float(payment.amount or 0)

    loan_payments = _scoped(
        LoanPayment.query.filter(
            LoanPayment.status == 'ACTIVO',
            LoanPayment.payment_date >= start,
            LoanPayment.payment_date <= end,
        ),
        LoanPayment, user_id, is_admin,
    ).all()
    for payment in loan_payments:
        monthly_reduction[_month_key(payment.payment_date)] += float(payment.principal_paid or 0)

    current_outstanding = 0.0
    card_debt_query = _scoped(
        Card.query.with_entities(func.coalesce(func.sum(Card.current_debt), 0)),
        Card, user_id, is_admin,
    )
    current_outstanding += float(card_debt_query.scalar() or 0)
    current_outstanding += _loan_outstanding(user, is_admin)

    buckets = _month_buckets(start, end)
    suffix = 0.0
    reversed_series = []
    for index in range(len(buckets) - 1, -1, -1):
        if index < len(buckets) - 1:
            suffix += monthly_reduction.get(buckets[index + 1], 0.0)
        year, month = buckets[index]
        reversed_series.append({
            "month": f"{year:04d}-{month:02d}",
            "outstanding": round(current_outstanding + suffix, 2),
        })
    evolution = list(reversed(reversed_series))

    return jsonify({
        "start": start.strftime(_DATE_FMT),
        "end": end.strftime(_DATE_FMT),
        "currentOutstanding": round(current_outstanding, 2),
        "series": evolution,
    }), 200