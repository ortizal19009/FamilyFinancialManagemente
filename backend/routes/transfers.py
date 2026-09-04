from datetime import datetime
from decimal import Decimal

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.orm import joinedload

try:
    from backend.models import db, User, BankAccount, Transfer
except ModuleNotFoundError:
    from models import db, User, BankAccount, Transfer

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

transfers_bp = Blueprint('transfers', __name__)


def _user_accounts(user_id):
    return {
        account.id: account for account in
        BankAccount.query.filter_by(user_id=user_id).all()
    }


def _validate_accounts(user_id, from_account_id, to_account_id):
    if not from_account_id or not to_account_id:
        return None, 'Debe seleccionar la cuenta origen y destino'
    if from_account_id == to_account_id:
        return None, 'La cuenta origen y destino no pueden ser la misma'

    accounts = _user_accounts(user_id)
    from_account = accounts.get(int(from_account_id))
    to_account = accounts.get(int(to_account_id))
    if not from_account or not to_account:
        return None, 'Una de las cuentas no existe o no te pertenece'
    return accounts, None


def _serialize_transfer(transfer):
    return {
        "id": transfer.id,
        "user_id": transfer.user_id,
        "user_name": transfer.user.full_name if transfer.user else None,
        "from_account_id": transfer.from_account_id,
        "from_account_name": (
            f"{transfer.from_account.bank.name if transfer.from_account.bank else 'Banco'} - "
            f"{transfer.from_account.account_number}"
            if transfer.from_account else None
        ),
        "to_account_id": transfer.to_account_id,
        "to_account_name": (
            f"{transfer.to_account.bank.name if transfer.to_account.bank else 'Banco'} - "
            f"{transfer.to_account.account_number}"
            if transfer.to_account else None
        ),
        "amount": float(transfer.amount),
        "transfer_date": transfer.transfer_date.strftime('%Y-%m-%d'),
        "description": transfer.description,
        "status": transfer.status,
        "cancelled_at": transfer.cancelled_at.isoformat() if transfer.cancelled_at else None,
        "cancellation_reason": transfer.cancellation_reason,
        "created_at": transfer.created_at.isoformat() if transfer.created_at else None,
    }


def _apply_transfer_effect(from_account, to_account, amount, sign=1):
    from_account.current_balance = Decimal(str(from_account.current_balance or 0)) - (Decimal(str(amount)) * sign)
    to_account.current_balance = Decimal(str(to_account.current_balance or 0)) + (Decimal(str(amount)) * sign)


def _record_transfer_movements(user_id, transfer, sign=1):
    description = transfer.description or f'Transferencia {transfer.id}'
    if sign == 1:
        movement_type = 'TRANSFERENCIA'
    else:
        movement_type = 'REVERSION'
    record_movement(
        user_id=user_id,
        movement_type=movement_type,
        source_type='TRANSFER',
        source_id=transfer.id,
        amount=transfer.amount,
        direction='OUT',
        movement_date=transfer.transfer_date,
        account_id=transfer.from_account_id,
        description=f'{description} (origen)',
        status='REVERSADO' if sign == -1 else 'ACTIVO',
    )
    record_movement(
        user_id=user_id,
        movement_type=movement_type,
        source_type='TRANSFER',
        source_id=transfer.id,
        amount=transfer.amount,
        direction='IN',
        movement_date=transfer.transfer_date,
        account_id=transfer.to_account_id,
        description=f'{description} (destino)',
        status='REVERSADO' if sign == -1 else 'ACTIVO',
    )


@transfers_bp.route('/', methods=['GET'])
@jwt_required()
def get_transfers():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)

    query = Transfer.query.options(
        joinedload(Transfer.user),
        joinedload(Transfer.from_account).joinedload(BankAccount.bank),
        joinedload(Transfer.to_account).joinedload(BankAccount.bank),
    )
    if user.role != 'admin':
        query = query.filter(Transfer.user_id == user_id)
    if request.args.get('include_cancelled', '').lower() not in ('true', '1'):
        query = query.filter(Transfer.status != 'ANULADO')

    query = apply_date_range(query, Transfer.transfer_date)
    query = apply_search(query, Transfer.description)
    query = query.order_by(Transfer.transfer_date.desc(), Transfer.created_at.desc())

    items, meta = paginate_or_plain(query, lambda transfers: [_serialize_transfer(t) for t in transfers])
    if meta is None:
        return jsonify(items), 200
    return jsonify({"items": items, **meta}), 200


@transfers_bp.route('/', methods=['POST'])
@jwt_required()
def create_transfer():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}

    if data.get('amount') in [None, ''] or not data.get('transfer_date'):
        return jsonify({"msg": "amount and transfer_date are required"}), 400

    amount = float(data['amount'])
    if amount <= 0:
        return jsonify({"msg": "El monto debe ser mayor a 0"}), 400

    accounts, error = _validate_accounts(
        user_id, data.get('from_account_id'), data.get('to_account_id')
    )
    if error:
        return jsonify({"msg": error}), 400
    from_account = accounts[int(data['from_account_id'])]
    to_account = accounts[int(data['to_account_id'])]

    if Decimal(str(from_account.current_balance or 0)) < Decimal(str(amount)):
        return jsonify({"msg": "Saldo insuficiente en la cuenta origen"}), 400

    transfer = Transfer(
        user_id=user_id,
        from_account_id=data['from_account_id'],
        to_account_id=data['to_account_id'],
        amount=amount,
        transfer_date=datetime.strptime(data['transfer_date'], '%Y-%m-%d'),
        description=data.get('description'),
    )
    db.session.add(transfer)
    _apply_transfer_effect(from_account, to_account, amount, sign=1)
    try:
        db.session.flush()
        _record_transfer_movements(user_id, transfer, sign=1)
        record_audit(
            'CREATE',
            'transfer',
            transfer.id,
            old_values=None,
            new_values=serialize_model(transfer),
            user_id=user_id,
        )
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise
    return jsonify({"msg": "Transfer registered successfully", "id": transfer.id}), 201


@transfers_bp.route('/<int:transfer_id>', methods=['DELETE'])
@jwt_required()
def delete_transfer(transfer_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    transfer = db.session.get(Transfer, transfer_id)

    if not transfer:
        return jsonify({"msg": "Transfer not found"}), 404
    if user.role != 'admin' and transfer.user_id != user_id:
        return jsonify({"msg": "No autorizado para anular esta transferencia"}), 403
    if transfer.status != 'ACTIVO':
        return jsonify({"msg": "La transferencia ya fue anulada"}), 400

    data = request.get_json(silent=True) or {}
    reason = (data.get('reason') or '').strip() or None

    from_account = db.session.get(BankAccount, transfer.from_account_id)
    to_account = db.session.get(BankAccount, transfer.to_account_id)

    old_values = serialize_model(transfer)
    if from_account and to_account:
        _apply_transfer_effect(from_account, to_account, transfer.amount, sign=-1)
    cancel_movements_for(user_id, 'TRANSFER', transfer_id)

    now = datetime.utcnow()
    transfer.status = 'ANULADO'
    transfer.cancelled_at = now
    transfer.cancelled_by = user_id
    transfer.cancellation_reason = reason

    _record_transfer_movements(user_id, transfer, sign=-1)
    record_audit(
        'CANCEL',
        'transfer',
        transfer_id,
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
    return jsonify({"msg": "Transfer cancelled successfully"}), 200