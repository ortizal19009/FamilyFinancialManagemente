from datetime import datetime
from decimal import Decimal

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.orm import joinedload

try:
    from backend.models import db, Asset, Income, User, BankAccount
except ModuleNotFoundError:
    from models import db, Asset, Income, User, BankAccount

assets_income_bp = Blueprint('assets_income', __name__)


def _apply_income_effect(destination_type, amount, bank_account_id=None, sign=1):
    if destination_type != 'bank_account' or not bank_account_id:
        return

    account = db.session.get(BankAccount, bank_account_id)
    if not account:
        return

    account.current_balance = Decimal(str(account.current_balance or 0)) + (Decimal(str(amount)) * sign)

# --- Rutas para Inventario de Bienes (Activos) ---

@assets_income_bp.route('/assets', methods=['GET'])
@jwt_required()
def get_assets():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    if not user:
        return jsonify({"msg": "User not found"}), 404

    assets = Asset.query.all()
        
    return jsonify([{
        "id": a.id,
        "name": a.name,
        "owner": a.owner,
        "value": float(a.value),
        "description": a.description,
        "purchase_date": a.purchase_date.strftime('%Y-%m-%d') if a.purchase_date else None,
        "created_at": a.created_at
    } for a in assets]), 200

@assets_income_bp.route('/assets', methods=['POST'])
@jwt_required()
def create_asset():
    data = request.get_json()
    if not data or not data.get('name') or not data.get('value'):
        return jsonify({"msg": "Name and value are required"}), 400
    
    new_asset = Asset(
        name=data['name'],
        value=data['value'],
        owner=data.get('owner'),
        description=data.get('description'),
        purchase_date=datetime.strptime(data['purchase_date'], '%Y-%m-%d') if data.get('purchase_date') else None
    )
    db.session.add(new_asset)
    db.session.commit()
    return jsonify({"msg": "Asset registered successfully", "id": new_asset.id}), 201


@assets_income_bp.route('/assets/<int:asset_id>', methods=['PUT'])
@jwt_required()
def update_asset(asset_id):
    asset = db.session.get(Asset, asset_id)
    if not asset:
        return jsonify({"msg": "Asset not found"}), 404

    data = request.get_json() or {}
    if not data.get('name') or data.get('value') in [None, '']:
        return jsonify({"msg": "Name and value are required"}), 400

    asset.name = data['name']
    asset.value = data['value']
    asset.owner = data.get('owner')
    asset.description = data.get('description')
    asset.purchase_date = datetime.strptime(data['purchase_date'], '%Y-%m-%d') if data.get('purchase_date') else None
    db.session.commit()
    return jsonify({"msg": "Asset updated successfully"}), 200


@assets_income_bp.route('/assets/<int:asset_id>', methods=['DELETE'])
@jwt_required()
def delete_asset(asset_id):
    asset = db.session.get(Asset, asset_id)
    if not asset:
        return jsonify({"msg": "Asset not found"}), 404

    db.session.delete(asset)
    db.session.commit()
    return jsonify({"msg": "Asset deleted successfully"}), 200

# --- Rutas para Ingresos ---

@assets_income_bp.route('/income', methods=['GET'])
@jwt_required()
def get_income():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    if user.role == 'admin':
        income_records = Income.query.options(
            joinedload(Income.user),
            joinedload(Income.bank_account).joinedload(BankAccount.bank),
        ).order_by(Income.income_date.desc()).all()
    else:
        income_records = Income.query.options(
            joinedload(Income.user),
            joinedload(Income.bank_account).joinedload(BankAccount.bank),
        ).filter_by(user_id=user_id).order_by(Income.income_date.desc()).all()
        
    return jsonify([{
        "id": i.id,
        "user_name": i.user.full_name if i.user else None,
        "amount": float(i.amount),
        "source": i.source,
        "income_date": i.income_date.strftime('%Y-%m-%d'),
        "destination_type": i.destination_type or 'cash',
        "bank_account_id": i.bank_account_id,
        "bank_account_name": (
            f'{i.bank_account.bank.name if i.bank_account.bank else "Banco"} - {i.bank_account.account_number}'
            if i.bank_account
            else None
        ),
        "description": i.description
    } for i in income_records]), 200

@assets_income_bp.route('/income', methods=['POST'])
@jwt_required()
def create_income():
    user_id = int(get_jwt_identity())
    data = request.get_json()
    
    if not data or not data.get('amount') or not data.get('source') or not data.get('income_date'):
        return jsonify({"msg": "Amount, source and income_date are required"}), 400
    
    destination_type = (data.get('destination_type') or 'cash').strip()
    if destination_type not in {'cash', 'bank_account'}:
        return jsonify({"msg": "destination_type invalido"}), 400

    bank_account_id = data.get('bank_account_id')
    if destination_type == 'bank_account':
        if not bank_account_id:
            return jsonify({"msg": "Debe seleccionar una cuenta para este ingreso"}), 400
        account = db.session.get(BankAccount, bank_account_id)
        if not account:
            return jsonify({"msg": "Cuenta bancaria no encontrada"}), 404
    else:
        bank_account_id = None

    new_income = Income(
        user_id=user_id,
        amount=data['amount'],
        source=data['source'],
        income_date=datetime.strptime(data['income_date'], '%Y-%m-%d'),
        destination_type=destination_type,
        bank_account_id=bank_account_id,
        description=data.get('description')
    )
    db.session.add(new_income)
    _apply_income_effect(destination_type, data['amount'], bank_account_id=bank_account_id, sign=1)
    db.session.commit()
    return jsonify({"msg": "Income registered successfully", "id": new_income.id}), 201


@assets_income_bp.route('/income/<int:income_id>', methods=['PUT'])
@jwt_required()
def update_income(income_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    income = db.session.get(Income, income_id)

    if not income:
        return jsonify({"msg": "Income not found"}), 404

    if user.role != 'admin' and income.user_id != user_id:
        return jsonify({"msg": "No autorizado para editar este ingreso"}), 403

    data = request.get_json() or {}
    if data.get('amount') in [None, ''] or not data.get('source') or not data.get('income_date'):
        return jsonify({"msg": "Amount, source and income_date are required"}), 400

    destination_type = (data.get('destination_type') or 'cash').strip()
    if destination_type not in {'cash', 'bank_account'}:
        return jsonify({"msg": "destination_type invalido"}), 400

    bank_account_id = data.get('bank_account_id')
    if destination_type == 'bank_account':
        if not bank_account_id:
            return jsonify({"msg": "Debe seleccionar una cuenta para este ingreso"}), 400
        account = db.session.get(BankAccount, bank_account_id)
        if not account:
            return jsonify({"msg": "Cuenta bancaria no encontrada"}), 404
    else:
        bank_account_id = None

    _apply_income_effect(
        income.destination_type or 'cash',
        income.amount,
        bank_account_id=income.bank_account_id,
        sign=-1,
    )
    income.amount = data['amount']
    income.source = data['source']
    income.income_date = datetime.strptime(data['income_date'], '%Y-%m-%d')
    income.destination_type = destination_type
    income.bank_account_id = bank_account_id
    income.description = data.get('description')
    _apply_income_effect(destination_type, data['amount'], bank_account_id=bank_account_id, sign=1)
    db.session.commit()
    return jsonify({"msg": "Income updated successfully"}), 200


@assets_income_bp.route('/income/<int:income_id>', methods=['DELETE'])
@jwt_required()
def delete_income(income_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    income = db.session.get(Income, income_id)

    if not income:
        return jsonify({"msg": "Income not found"}), 404

    if user.role != 'admin' and income.user_id != user_id:
        return jsonify({"msg": "No autorizado para eliminar este ingreso"}), 403

    _apply_income_effect(
        income.destination_type or 'cash',
        income.amount,
        bank_account_id=income.bank_account_id,
        sign=-1,
    )
    db.session.delete(income)
    db.session.commit()
    return jsonify({"msg": "Income deleted successfully"}), 200
