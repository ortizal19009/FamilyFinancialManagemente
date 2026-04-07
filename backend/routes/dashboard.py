from datetime import date

from flask import Blueprint, jsonify
from flask_jwt_extended import get_jwt_identity, jwt_required
from sqlalchemy import func, inspect
from sqlalchemy.orm import joinedload

try:
    from backend.models import BankAccount, Card, Expense, Asset, Investment, User, db
except ModuleNotFoundError:
    from models import BankAccount, Card, Expense, Asset, Investment, User, db

dashboard_bp = Blueprint('dashboard', __name__)


@dashboard_bp.route('/summary', methods=['GET'])
@jwt_required()
def get_dashboard_summary():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)

    if not user:
        return jsonify({"msg": "User not found"}), 404

    account_balance_query = BankAccount.query.with_entities(func.coalesce(func.sum(BankAccount.current_balance), 0))
    debt_query = Card.query.with_entities(func.coalesce(func.sum(Card.current_debt), 0))
    assets_query = Asset.query.with_entities(func.coalesce(func.sum(Asset.value), 0))
    has_investments_table = inspect(db.engine).has_table('investments')
    investments_current_value = 0.0
    investments_invested_amount = 0.0

    if has_investments_table:
        investments_query = Investment.query.with_entities(
            func.coalesce(func.sum(Investment.current_value), 0),
            func.coalesce(func.sum(Investment.invested_amount), 0),
        )

    if user.role != 'admin':
        debt_query = debt_query.filter(Card.user_id == user_id)
        if has_investments_table:
            investments_query = investments_query.filter(Investment.user_id == user_id)

    today = date.today()
    monthly_expenses_query = Expense.query.with_entities(func.coalesce(func.sum(Expense.amount), 0)).filter(
        func.extract('month', Expense.expense_date) == today.month,
        func.extract('year', Expense.expense_date) == today.year
    )

    recent_expenses_query = Expense.query.options(
        joinedload(Expense.user),
        joinedload(Expense.category)
    ).order_by(Expense.expense_date.desc())

    if user.role != 'admin':
        monthly_expenses_query = monthly_expenses_query.filter(Expense.user_id == user_id)
        recent_expenses_query = recent_expenses_query.filter(Expense.user_id == user_id)

    recent_expenses = recent_expenses_query.limit(5).all()
    if has_investments_table:
        investments_current_value, investments_invested_amount = investments_query.first()

    return jsonify({
        "stats": {
            "availableBalance": float(account_balance_query.scalar() or 0),
            "totalDebt": float(debt_query.scalar() or 0),
            "monthlyExpenses": float(monthly_expenses_query.scalar() or 0),
            "totalAssets": float(assets_query.scalar() or 0),
            "investmentsCurrentValue": float(investments_current_value or 0),
            "investmentsInvestedAmount": float(investments_invested_amount or 0)
        },
        "recentExpenses": [{
            "id": expense.id,
            "user_id": expense.user_id,
            "user_name": expense.user.full_name if expense.user else 'N/A',
            "category_name": expense.category.name if expense.category else None,
            "amount": float(expense.amount),
            "payment_method": expense.payment_method,
            "expense_date": expense.expense_date.strftime('%Y-%m-%d'),
            "description": expense.description
        } for expense in recent_expenses]
    }), 200
