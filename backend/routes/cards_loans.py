from datetime import datetime

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.orm import joinedload

try:
    from backend.models import db, Card, Loan, Bank, User
except ModuleNotFoundError:
    from models import db, Card, Loan, Bank, User

cards_loans_bp = Blueprint('cards_loans', __name__)

# --- Rutas para Tarjetas ---

@cards_loans_bp.route('/cards', methods=['GET'])
@jwt_required()
def get_cards():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    if user.role == 'admin':
        cards = Card.query.options(joinedload(Card.bank), joinedload(Card.user)).all()
    else:
        cards = Card.query.options(joinedload(Card.bank), joinedload(Card.user)).filter_by(user_id=user_id).all()
        
    return jsonify([{
        "id": c.id,
        "bank_id": c.bank_id,
        "bank_name": c.bank.name if c.bank else None,
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
    data = request.get_json()
    if not data or not data.get('bank_id') or not data.get('card_name'):
        return jsonify({"msg": "bank_id and card_name are required"}), 400
    
    new_card = Card(
        bank_id=data['bank_id'],
        user_id=user_id, # Usar el ID del usuario autenticado
        card_name=data['card_name'],
        owner=data.get('owner'),
        last_four_digits=data.get('last_four_digits'),
        card_type=data.get('card_type', 'Débito'),
        credit_limit=data.get('credit_limit', 0.00),
        current_debt=data.get('current_debt', 0.00),
        available_balance=data.get('available_balance', 0.00)
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

    card.bank_id = data['bank_id']
    card.card_name = data['card_name']
    card.owner = data.get('owner')
    card.last_four_digits = data.get('last_four_digits')
    card.card_type = data.get('card_type', 'Débito')
    card.credit_limit = data.get('credit_limit', 0.00)
    card.current_debt = data.get('current_debt', 0.00)
    card.available_balance = data.get('available_balance', 0.00)
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
    data = request.get_json()
    if not data or not data.get('description') or not data.get('initial_amount'):
        return jsonify({"msg": "description and initial_amount are required"}), 400
    
    new_loan = Loan(
        user_id=user_id, # Usar el ID del usuario autenticado
        bank_id=data.get('bank_id'),
        description=data['description'],
        owner=data.get('owner'),
        initial_amount=data['initial_amount'],
        total_installments=data.get('total_installments', 1),
        pending_installments=data.get('pending_installments', 1),
        monthly_payment=data.get('monthly_payment', 0.00),
        interest_rate=data.get('interest_rate'),
        start_date=datetime.strptime(data['start_date'], '%Y-%m-%d') if data.get('start_date') else None
    )
    db.session.add(new_loan)
    db.session.commit()
    return jsonify({"msg": "Loan created successfully", "id": new_loan.id}), 201
