from datetime import datetime

from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.orm import joinedload

try:
    from backend.models import db, User, AuditLog
except ModuleNotFoundError:
    from models import db, User, AuditLog

audit_bp = Blueprint('audit', __name__)


def _parse_date(value):
    if not value:
        return None
    try:
        return datetime.strptime(value, '%Y-%m-%d').date()
    except ValueError:
        return None


@audit_bp.route('/', methods=['GET'])
@jwt_required()
def get_audit_log():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    if user.role != 'admin':
        return jsonify({"msg": "Acceso restringido a administradores"}), 403

    query = AuditLog.query.options(joinedload(AuditLog.user))

    target_user = request.args.get('user_id')
    if target_user:
        query = query.filter(AuditLog.user_id == int(target_user))

    entity = request.args.get('entity')
    if entity:
        query = query.filter(AuditLog.entity == entity)

    action = request.args.get('action')
    if action:
        query = query.filter(AuditLog.action == action)

    entity_id = request.args.get('entity_id')
    if entity_id:
        query = query.filter(AuditLog.entity_id == int(entity_id))

    date_from = _parse_date(request.args.get('from'))
    if date_from:
        query = query.filter(AuditLog.created_at >= datetime.combine(date_from, datetime.min.time()))

    date_to = _parse_date(request.args.get('to'))
    if date_to:
        query = query.filter(AuditLog.created_at <= datetime.combine(date_to, datetime.max.time()))

    query = query.order_by(AuditLog.created_at.desc())

    per_page = min(int(request.args.get('per_page', 50)), 200)
    page = int(request.args.get('page', 1))
    pagination = query.paginate(page=page, per_page=per_page, error_out=False)

    items = [{
        "id": log.id,
        "user_id": log.user_id,
        "user_name": log.user.full_name if log.user else None,
        "action": log.action,
        "entity": log.entity,
        "entity_id": log.entity_id,
        "old_values": log.old_values,
        "new_values": log.new_values,
        "ip_address": log.ip_address,
        "created_at": log.created_at.isoformat() if log.created_at else None,
    } for log in pagination.items]

    return jsonify({
        "items": items,
        "page": pagination.page,
        "per_page": pagination.per_page,
        "total": pagination.total,
        "pages": pagination.pages,
    }), 200