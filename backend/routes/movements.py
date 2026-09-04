from datetime import datetime

from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.orm import joinedload

try:
    from backend.models import db, User, FinancialMovement, BankAccount
except ModuleNotFoundError:
    from models import db, User, FinancialMovement, BankAccount

movements_bp = Blueprint('movements', __name__)


def _parse_date(value):
    if not value:
        return None
    try:
        return datetime.strptime(value, '%Y-%m-%d').date()
    except ValueError:
        return None


@movements_bp.route('/', methods=['GET'])
@jwt_required()
def get_movements():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    query = FinancialMovement.query.options(
        joinedload(FinancialMovement.user),
        joinedload(FinancialMovement.creator),
        joinedload(FinancialMovement.bank_account).joinedload(BankAccount.bank),
        joinedload(FinancialMovement.card),
    )

    if user.role != 'admin':
        query = query.filter(FinancialMovement.user_id == user_id)

    movement_type = request.args.get('movement_type')
    if movement_type:
        query = query.filter(FinancialMovement.movement_type == movement_type)

    status = request.args.get('status')
    if status:
        query = query.filter(FinancialMovement.status == status)
    else:
        query = query.filter(FinancialMovement.status != 'ANULADO')

    account_id = request.args.get('account_id')
    if account_id:
        query = query.filter(FinancialMovement.account_id == int(account_id))

    card_id = request.args.get('card_id')
    if card_id:
        query = query.filter(FinancialMovement.card_id == int(card_id))

    date_from = _parse_date(request.args.get('from'))
    if date_from:
        query = query.filter(FinancialMovement.movement_date >= date_from)

    date_to = _parse_date(request.args.get('to'))
    if date_to:
        query = query.filter(FinancialMovement.movement_date <= date_to)

    query = query.order_by(
        FinancialMovement.movement_date.desc(),
        FinancialMovement.created_at.desc(),
    )

    per_page = min(int(request.args.get('per_page', 50)), 200)
    page = int(request.args.get('page', 1))
    pagination = query.paginate(page=page, per_page=per_page, error_out=False)

    items = [{
        "id": m.id,
        "user_id": m.user_id,
        "user_name": m.user.full_name if m.user else None,
        "movement_type": m.movement_type,
        "source_type": m.source_type,
        "source_id": m.source_id,
        "account_id": m.account_id,
        "account_name": (
            f'{m.bank_account.bank.name if m.bank_account.bank else "Banco"} - {m.bank_account.account_number}'
            if m.bank_account else None
        ),
        "card_id": m.card_id,
        "card_name": m.card.card_name if m.card else None,
        "amount": float(m.amount),
        "direction": m.direction,
        "movement_date": m.movement_date.strftime('%Y-%m-%d'),
        "status": m.status,
        "description": m.description,
        "created_at": m.created_at.isoformat() if m.created_at else None,
        "created_by": m.created_by,
        "creator_name": m.creator.full_name if m.creator else None,
    } for m in pagination.items]

    return jsonify({
        "items": items,
        "page": pagination.page,
        "per_page": pagination.per_page,
        "total": pagination.total,
        "pages": pagination.pages,
    }), 200