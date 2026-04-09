from datetime import datetime

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.orm import joinedload

try:
    from backend.models import db, Card, Loan, Bank, BankAccount, User
except ModuleNotFoundError:
    from models import db, Card, Loan, Bank, BankAccount, User

cards_loans_bp = Blueprint('cards_loans', __name__)


def _to_int(value, field_name, required=False):
    if value in [None, '']:
        if required:
            raise ValueError(f"{field_name} is required")
        return None
    return int(value)


def _to_float(value, default=0.0):
    if value in [None, '']:
        return default
    return float(value)


def _resolve_card_account(bank_id, card_type, bank_account_id, available_balance):
    normalized_card_type = (card_type or 'Débito').strip()
    account_id = _to_int(bank_account_id, 'bank_account_id') if bank_account_id not in [None, ''] else None

    if normalized_card_type == 'Débito':
        if not account_id:
            raise ValueError('bank_account_id is required for debit cards')
        account = db.session.get(BankAccount, account_id)
        if not account:
            raise ValueError('Bank account not found')
        if account.bank_id != bank_id:
            raise ValueError('Debit card bank account must belong to the selected bank')
        return account_id, float(account.current_balance or 0)

    return None, _to_float(available_balance)

# --- Rutas para Tarjetas ---

@cards_loans_bp.route('/cards', methods=['GET'])
@jwt_required()
def get_cards():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    if user.role == 'admin':
        cards = Card.query.options(joinedload(Card.bank), joinedload(Card.bank_account).joinedload(BankAccount.bank), joinedload(Card.user)).all()
    else:
        cards = Card.query.options(joinedload(Card.bank), joinedload(Card.bank_account).joinedload(BankAccount.bank), joinedload(Card.user)).filter_by(user_id=user_id).all()
        
    return jsonify([{
        "id": c.id,
        "bank_id": c.bank_id,
        "bank_account_id": c.bank_account_id,
        "bank_name": c.bank.name if c.bank else None,
        "bank_account_name": (
            f"{c.bank_account.bank.name if c.bank_account and c.bank_account.bank else 'Banco'} - {c.bank_account.account_number}"
            if c.bank_account else None
        ),
        "user_name": c.user.full_name if c.user else None,
        "card_name": c.card_name,
        "owner": c.owner,
        "last_four_digits": c.last_four_digits,
        "card_type": c.card_type,
        "credit_limit": float(c.credit_limit),
        "current_debt": float(c.current_debt),
        "available_balance": float(c.available_balance)
    } for c in cards]), 200

@cards_loans_bp.route('/cards', methods=['POST'])
@jwt_required()
def create_card():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}
    if not data.get('bank_id') or not data.get('card_name'):
        return jsonify({"msg": "bank_id and card_name are required"}), 400

    try:
        bank_id = _to_int(data.get('bank_id'), 'bank_id', required=True)
        bank_account_id, available_balance = _resolve_card_account(
            bank_id,
            data.get('card_type', 'Débito'),
            data.get('bank_account_id'),
            data.get('available_balance'),
        )
    except (TypeError, ValueError) as exc:
        return jsonify({"msg": str(exc)}), 400
    
    new_card = Card(
        bank_id=bank_id,
        bank_account_id=bank_account_id,
        user_id=user_id, # Usar el ID del usuario autenticado
        card_name=data['card_name'],
        owner=data.get('owner'),
        last_four_digits=data.get('last_four_digits'),
        card_type=data.get('card_type', 'Débito'),
        credit_limit=_to_float(data.get('credit_limit')),
        current_debt=_to_float(data.get('current_debt')),
        available_balance=available_balance
    )
    db.session.add(new_card)
    db.session.commit()
    return jsonify({"msg": "Card created successfully", "id": new_card.id}), 201


@cards_loans_bp.route('/cards/<int:card_id>', methods=['PUT'])
@jwt_required()
def update_card(card_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    card = db.session.get(Card, card_id)

    if not card:
        return jsonify({"msg": "Card not found"}), 404

    if user.role != 'admin' and card.user_id != user_id:
        return jsonify({"msg": "No autorizado para editar esta tarjeta"}), 403

    data = request.get_json() or {}
    if not data.get('bank_id') or not data.get('card_name'):
        return jsonify({"msg": "bank_id and card_name are required"}), 400

    try:
        card.bank_id = _to_int(data.get('bank_id'), 'bank_id', required=True)
        card.bank_account_id, card.available_balance = _resolve_card_account(
            card.bank_id,
            data.get('card_type', 'Débito'),
            data.get('bank_account_id'),
            data.get('available_balance'),
        )
    except (TypeError, ValueError) as exc:
        return jsonify({"msg": str(exc)}), 400
    card.card_name = data['card_name']
    card.owner = data.get('owner')
    card.last_four_digits = data.get('last_four_digits')
    card.card_type = data.get('card_type', 'Débito')
    card.credit_limit = _to_float(data.get('credit_limit'))
    card.current_debt = _to_float(data.get('current_debt'))
    db.session.commit()

    return jsonify({"msg": "Card updated successfully"}), 200


@cards_loans_bp.route('/cards/<int:card_id>', methods=['DELETE'])
@jwt_required()
def delete_card(card_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    card = db.session.get(Card, card_id)

    if not card:
        return jsonify({"msg": "Card not found"}), 404

    if user.role != 'admin' and card.user_id != user_id:
        return jsonify({"msg": "No autorizado para eliminar esta tarjeta"}), 403

    if card.expenses:
        return jsonify({
            "msg": "No se puede eliminar la tarjeta porque tiene gastos asociados"
        }), 400

    db.session.delete(card)
    db.session.commit()
    return jsonify({"msg": "Card deleted successfully"}), 200

# --- Rutas para Préstamos ---

@cards_loans_bp.route('/loans', methods=['GET'])
@jwt_required()
def get_loans():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    if user.role == 'admin':
        loans = Loan.query.options(joinedload(Loan.bank)).all()
    else:
        loans = Loan.query.options(joinedload(Loan.bank)).filter_by(user_id=user_id).all()
        
    return jsonify([{
        "id": l.id,
        "bank_id": l.bank_id,
        "bank_name": l.bank.name if l.bank else None,
        "description": l.description,
        "owner": l.owner,
        "initial_amount": float(l.initial_amount),
        "total_installments": l.total_installments,
        "pending_installments": l.pending_installments,
        "monthly_payment": float(l.monthly_payment),
        "interest_rate": float(l.interest_rate) if l.interest_rate else 0,
        "start_date": l.start_date.strftime('%Y-%m-%d') if l.start_date else None
    } for l in loans]), 200

@cards_loans_bp.route('/loans', methods=['POST'])
@jwt_required()
def create_loan():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}
    if not data.get('description') or data.get('initial_amount') in [None, '']:
        return jsonify({"msg": "description and initial_amount are required"}), 400

    try:
        bank_id = _to_int(data.get('bank_id'), 'bank_id')
        total_installments = _to_int(data.get('total_installments'), 'total_installments') or 1
        pending_installments = _to_int(data.get('pending_installments'), 'pending_installments') or 1
    except (TypeError, ValueError) as exc:
        return jsonify({"msg": str(exc)}), 400
    
    new_loan = Loan(
        user_id=user_id, # Usar el ID del usuario autenticado
        bank_id=bank_id,
        description=data['description'],
        owner=data.get('owner'),
        initial_amount=_to_float(data['initial_amount']),
        total_installments=total_installments,
        pending_installments=pending_installments,
        monthly_payment=_to_float(data.get('monthly_payment')),
        interest_rate=_to_float(data.get('interest_rate'), default=None),
        start_date=datetime.strptime(data['start_date'], '%Y-%m-%d') if data.get('start_date') else None
    )
    db.session.add(new_loan)
    db.session.commit()
    return jsonify({"msg": "Loan created successfully", "id": new_loan.id}), 201


@cards_loans_bp.route('/loans/<int:loan_id>', methods=['PUT'])
@jwt_required()
def update_loan(loan_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    loan = db.session.get(Loan, loan_id)

    if not loan:
        return jsonify({"msg": "Loan not found"}), 404

    if user.role != 'admin' and loan.user_id != user_id:
        return jsonify({"msg": "No autorizado para editar este préstamo"}), 403

    data = request.get_json() or {}
    if not data.get('description') or data.get('initial_amount') in [None, '']:
        return jsonify({"msg": "description and initial_amount are required"}), 400

    try:
        loan.bank_id = _to_int(data.get('bank_id'), 'bank_id')
        loan.initial_amount = _to_float(data.get('initial_amount'))
        loan.total_installments = _to_int(data.get('total_installments'), 'total_installments') or 1
        loan.pending_installments = _to_int(data.get('pending_installments'), 'pending_installments') or 1
        loan.monthly_payment = _to_float(data.get('monthly_payment'))
        loan.interest_rate = _to_float(data.get('interest_rate'), default=None)
    except (TypeError, ValueError) as exc:
        return jsonify({"msg": str(exc)}), 400

    loan.description = data['description']
    loan.owner = data.get('owner')
    loan.start_date = datetime.strptime(data['start_date'], '%Y-%m-%d') if data.get('start_date') else None
    db.session.commit()
    return jsonify({"msg": "Loan updated successfully"}), 200


@cards_loans_bp.route('/loans/<int:loan_id>', methods=['DELETE'])
@jwt_required()
def delete_loan(loan_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    loan = db.session.get(Loan, loan_id)

    if not loan:
        return jsonify({"msg": "Loan not found"}), 404

    if user.role != 'admin' and loan.user_id != user_id:
        return jsonify({"msg": "No autorizado para eliminar este préstamo"}), 403

    db.session.delete(loan)
    db.session.commit()
    return jsonify({"msg": "Loan deleted successfully"}), 200
