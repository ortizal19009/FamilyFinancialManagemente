from datetime import datetime, date
from decimal import Decimal

from flask import request

try:
    from backend.models import db, AuditLog, FinancialMovement
except ModuleNotFoundError:
    from models import db, AuditLog, FinancialMovement

SENSITIVE_FIELDS = {'password_hash', 'password'}


def _serialize_value(value):
    if isinstance(value, list):
        return [_serialize_value(item) for item in value]
    if isinstance(value, dict):
        return {key: _serialize_value(val) for key, val in value.items()}
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return value


def serialize_model(instance, exclude=()):
    """Serializa un modelo SQLAlchemy a dict, excluyendo campos sensibles."""
    if instance is None:
        return None
    data = {}
    for column in instance.__table__.columns:
        if column.name in SENSITIVE_FIELDS or column.name in exclude:
            continue
        value = getattr(instance, column.name)
        if hasattr(value, 'isoformat') or isinstance(value, Decimal):
            value = _serialize_value(value)
        data[column.name] = value
    return data


def serialize_values(value, exclude=()):
    """Serializa un modelo o una lista de modelos; deja dicts/valores tal cual."""
    if isinstance(value, list):
        return [serialize_values(item, exclude) for item in value]
    if isinstance(value, dict):
        return _serialize_value(value)
    if value is None:
        return None
    if hasattr(value, '__table__'):
        return serialize_model(value, exclude)
    return value


def client_ip():
    try:
        return request.headers.get('X-Forwarded-For', request.remote_addr or '')
    except RuntimeError:
        return None


def record_audit(action, entity, entity_id, old_values=None, new_values=None, user_id=None):
    """Registra un evento de auditoría. Idempotente a nivel de sesión."""
    log = AuditLog(
        action=action,
        entity=entity,
        entity_id=entity_id,
        old_values=serialize_values(old_values),
        new_values=_serialize_value(new_values),
        user_id=user_id,
        ip_address=client_ip(),
    )
    db.session.add(log)


def record_movement(
    user_id,
    movement_type,
    source_type,
    source_id,
    amount,
    direction,
    movement_date,
    account_id=None,
    card_id=None,
    description=None,
    status='ACTIVO',
    created_by=None,
):
    """Agrega un movimiento al libro financiero dentro de la transacción actual."""
    movement = FinancialMovement(
        user_id=user_id,
        movement_type=movement_type,
        source_type=source_type,
        source_id=source_id,
        account_id=account_id,
        card_id=card_id,
        amount=amount,
        direction=direction,
        movement_date=movement_date,
        status=status,
        description=description,
        created_by=created_by or user_id,
    )
    db.session.add(movement)
    return movement


def cancel_movements_for(user_id, source_type, source_id):
    """Marca como ANULADO los movimientos ACTIVO de la fuente indicada."""
    movements = FinancialMovement.query.filter_by(
        user_id=user_id,
        source_type=source_type,
        source_id=source_id,
    ).filter(FinancialMovement.status == 'ACTIVO').all()
    for movement in movements:
        movement.status = 'ANULADO'
    return movements