from datetime import datetime
from decimal import Decimal

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.orm import joinedload

try:
    from backend.models import db, Asset, Income, User, BankAccount
except ModuleNotFoundError:
    from models import db, Asset, Income, User, BankAccount

try:
    from backend.query_helpers import apply_date_range, apply_search, paginate_or_plain
except ModuleNotFoundError:
    from query_helpers import apply_date_range, apply_search, paginate_or_plain

try:
    from backend.ledger import (
        cancel_movements_for,
        record_audit,
        record_movement,
        serialize_model,
    )
except ModuleNotFoundError:
    from ledger import cancel_movements_for, record_audit, record_movement, serialize_model

assets_income_bp = Blueprint('assets_income', __name__)


def _apply_income_effect(destination_type, amount, bank_account_id=None, sign=1):
    if destination_type != 'bank_account' or not bank_account_id:
        return

    account = db.session.get(BankAccount, bank_account_id)
    if not account:
        return

    account.current_balance = Decimal(str(account.current_balance or 0)) + (Decimal(str(amount)) * sign)


def _income_movement_account(destination_type, bank_account_id):
    if destination_type == 'bank_account':
        return bank_account_id
    return None

# --- Rutas para Inventario de Bienes (Activos) ---

@assets_income_bp.route('/assets', methods=['GET'])
@jwt_required()
def get_assets():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    if not user:
        return jsonify({"msg": "User not found"}), 404

    query = Asset.query
    if user.role != 'admin':
        query = query.filter(Asset.user_id == user_id)
    query = apply_search(query, Asset.name, Asset.owner)
    query = query.order_by(Asset.created_at.desc())

    items, meta = paginate_or_plain(query, lambda assets: [{
        "id": a.id,
        "user_id": a.user_id,
        "name": a.name,
        "owner": a.owner,
        "value": float(a.value),
        "description": a.description,
        "purchase_date": a.purchase_date.strftime('%Y-%m-%d') if a.purchase_date else None,
        "created_at": a.created_at
    } for a in assets])
    if meta is None:
        return jsonify(items), 200
    return jsonify({"items": items, **meta}), 200

@assets_income_bp.route('/assets', methods=['POST'])
@jwt_required()
def create_asset():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    data = request.get_json()
    if not data or not data.get('name') or not data.get('value'):
        return jsonify({"msg": "Name and value are required"}), 400
    
    new_asset = Asset(
        user_id=user_id,
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
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    asset = db.session.get(Asset, asset_id)
    if not asset:
        return jsonify({"msg": "Asset not found"}), 404

    if user.role != 'admin' and asset.user_id not in (None, user_id):
        return jsonify({"msg": "No autorizado para editar este activo"}), 403

    data = request.get_json() or {}
    if not data.get('name') or data.get('value') in [None, '']:
        return jsonify({"msg": "Name and value are required"}), 400

    asset.user_id = asset.user_id or user_id
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
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    asset = db.session.get(Asset, asset_id)
    if not asset:
        return jsonify({"msg": "Asset not found"}), 404

    if user.role != 'admin' and asset.user_id not in (None, user_id):
        return jsonify({"msg": "No autorizado para eliminar este activo"}), 403

    db.session.delete(asset)
    db.session.commit()
    return jsonify({"msg": "Asset deleted successfully"}), 200

# --- Rutas para Ingresos ---

@assets_income_bp.route('/income', methods=['GET'])
@jwt_required()
def get_income():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    include_cancelled = request.args.get('include_cancelled', '').lower() in ('true', '1')

    query = Income.query.options(
        joinedload(Income.user),
        joinedload(Income.bank_account).joinedload(BankAccount.bank),
    )
    if user.role != 'admin':
        query = query.filter(Income.user_id == user_id)

    status = request.args.get('status')
    if status:
        query = query.filter(Income.status == status)
    elif not include_cancelled:
        query = query.filter(Income.status != 'ANULADO')

    query = apply_date_range(query, Income.income_date)
    if request.args.get('destination_type'):
        query = query.filter(Income.destination_type == request.args.get('destination_type'))
    query = apply_search(query, Income.source, Income.description)
    query = query.order_by(Income.income_date.desc(), Income.created_at.desc())

    items, meta = paginate_or_plain(query, lambda income_records: [{
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
        "description": i.description,
        "status": i.status,
        "cancelled_at": i.cancelled_at.isoformat() if i.cancelled_at else None,
        "cancellation_reason": i.cancellation_reason,
    } for i in income_records])
    if meta is None:
        return jsonify(items), 200
    return jsonify({"items": items, **meta}), 200

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
    try:
        db.session.flush()
        record_movement(
            user_id=user_id,
            movement_type='INGRESO',
            source_type='INCOME',
            source_id=new_income.id,
            amount=data['amount'],
            direction='IN',
            movement_date=datetime.strptime(data['income_date'], '%Y-%m-%d'),
            account_id=_income_movement_account(destination_type, bank_account_id),
            description=data.get('description'),
        )
        record_audit(
            'CREATE',
            'income',
            new_income.id,
            old_values=None,
            new_values={
                'amount': data['amount'],
                'source': data['source'],
                'income_date': data['income_date'],
                'destination_type': destination_type,
                'bank_account_id': bank_account_id,
                'description': data.get('description'),
            },
            user_id=user_id,
        )
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise
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
    old_values = serialize_model(income)
    cancel_movements_for(user_id, 'INCOME', income_id)

    income.amount = data['amount']
    income.source = data['source']
    income.income_date = datetime.strptime(data['income_date'], '%Y-%m-%d')
    income.destination_type = destination_type
    income.bank_account_id = bank_account_id
    income.description = data.get('description')
    _apply_income_effect(destination_type, data['amount'], bank_account_id=bank_account_id, sign=1)

    try:
        db.session.flush()
        record_movement(
            user_id=user_id,
            movement_type='INGRESO',
            source_type='INCOME',
            source_id=income_id,
            amount=data['amount'],
            direction='IN',
            movement_date=income.income_date,
            account_id=_income_movement_account(destination_type, bank_account_id),
            description=data.get('description'),
        )
        record_audit(
            'UPDATE',
            'income',
            income_id,
            old_values=old_values,
            new_values=serialize_model(income),
            user_id=user_id,
        )
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise
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
        return jsonify({"msg": "No autorizado para anular este ingreso"}), 403

    if income.status != 'ACTIVO':
        return jsonify({"msg": "El ingreso ya fue anulado"}), 400

    data = request.get_json(silent=True) or {}
    reason = (data.get('reason') or '').strip() or None

    old_values = serialize_model(income)

    _apply_income_effect(
        income.destination_type or 'cash',
        income.amount,
        bank_account_id=income.bank_account_id,
        sign=-1,
    )
    cancel_movements_for(user_id, 'INCOME', income_id)

    now = datetime.utcnow()
    income.status = 'ANULADO'
    income.cancelled_at = now
    income.cancelled_by = user_id
    income.cancellation_reason = reason

    record_movement(
        user_id=user_id,
        movement_type='REVERSION',
        source_type='INCOME',
        source_id=income_id,
        amount=income.amount,
        direction='OUT',
        movement_date=income.income_date,
        account_id=_income_movement_account(income.destination_type, income.bank_account_id),
        description=reason or f'Anulación del ingreso {income_id}',
        status='REVERSADO',
    )
    record_audit(
        'CANCEL',
        'income',
        income_id,
        old_values=old_values,
        new_values={
            'status': 'ANULADO',
            'reason': reason,
            'cancelled_at': now.isoformat(),
            'cancelled_by': user_id,
        },
        user_id=user_id,
    )

    db.session.commit()
    return jsonify({"msg": "Income cancelled successfully"}), 200
