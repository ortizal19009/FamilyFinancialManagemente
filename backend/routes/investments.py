from datetime import datetime

from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

try:
    from backend.models import Investment, User, db
except ModuleNotFoundError:
    from models import Investment, User, db

investments_bp = Blueprint('investments', __name__)


def _serialize_investment(investment):
    invested_amount = float(investment.invested_amount or 0)
    current_value = float(investment.current_value or 0)
    profit_loss = current_value - invested_amount
    return {
        'id': investment.id,
        'user_id': investment.user_id,
        'user_name': investment.user.full_name if investment.user else None,
        'institution': investment.institution,
        'investment_type': investment.investment_type,
        'title': investment.title,
        'owner': investment.owner,
        'invested_amount': invested_amount,
        'current_value': current_value,
        'profit_loss': profit_loss,
        'expected_return_rate': float(investment.expected_return_rate) if investment.expected_return_rate is not None else None,
        'start_date': investment.start_date.strftime('%Y-%m-%d') if investment.start_date else None,
        'end_date': investment.end_date.strftime('%Y-%m-%d') if investment.end_date else None,
        'status': investment.status,
        'notes': investment.notes,
        'created_at': investment.created_at.isoformat() if investment.created_at else None,
    }


@investments_bp.route('/', methods=['GET'])
@jwt_required()
def get_investments():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)

    if not user:
      return jsonify({'msg': 'User not found'}), 404

    query = Investment.query.order_by(Investment.created_at.desc())
    if user.role != 'admin':
        query = query.filter_by(user_id=user_id)

    investments = query.all()
    return jsonify([_serialize_investment(item) for item in investments]), 200


@investments_bp.route('/', methods=['POST'])
@jwt_required()
def create_investment():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}

    required_fields = ['institution', 'investment_type', 'title', 'invested_amount']
    if not all(data.get(field) not in [None, ''] for field in required_fields):
        return jsonify({'msg': 'institution, investment_type, title and invested_amount are required'}), 400

    invested_amount = float(data['invested_amount'])
    current_value = float(data.get('current_value', invested_amount))

    new_investment = Investment(
        user_id=user_id,
        institution=data['institution'],
        investment_type=data['investment_type'],
        title=data['title'],
        owner=data.get('owner'),
        invested_amount=invested_amount,
        current_value=current_value,
        expected_return_rate=data.get('expected_return_rate'),
        start_date=datetime.strptime(data['start_date'], '%Y-%m-%d') if data.get('start_date') else None,
        end_date=datetime.strptime(data['end_date'], '%Y-%m-%d') if data.get('end_date') else None,
        status=data.get('status', 'activa'),
        notes=data.get('notes'),
    )
    db.session.add(new_investment)
    db.session.commit()
    return jsonify({'msg': 'Investment created successfully', 'id': new_investment.id}), 201


@investments_bp.route('/<int:investment_id>', methods=['PUT'])
@jwt_required()
def update_investment(investment_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    investment = db.session.get(Investment, investment_id)

    if not investment:
        return jsonify({'msg': 'Investment not found'}), 404

    if user.role != 'admin' and investment.user_id != user_id:
        return jsonify({'msg': 'No autorizado para editar esta inversion'}), 403

    data = request.get_json() or {}
    required_fields = ['institution', 'investment_type', 'title', 'invested_amount']
    if not all(data.get(field) not in [None, ''] for field in required_fields):
        return jsonify({'msg': 'institution, investment_type, title and invested_amount are required'}), 400

    investment.institution = data['institution']
    investment.investment_type = data['investment_type']
    investment.title = data['title']
    investment.owner = data.get('owner')
    investment.invested_amount = float(data['invested_amount'])
    investment.current_value = float(data.get('current_value', data['invested_amount']))
    investment.expected_return_rate = data.get('expected_return_rate')
    investment.start_date = datetime.strptime(data['start_date'], '%Y-%m-%d') if data.get('start_date') else None
    investment.end_date = datetime.strptime(data['end_date'], '%Y-%m-%d') if data.get('end_date') else None
    investment.status = data.get('status', investment.status)
    investment.notes = data.get('notes')
    db.session.commit()
    return jsonify({'msg': 'Investment updated successfully'}), 200


@investments_bp.route('/<int:investment_id>', methods=['DELETE'])
@jwt_required()
def delete_investment(investment_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    investment = db.session.get(Investment, investment_id)

    if not investment:
        return jsonify({'msg': 'Investment not found'}), 404

    if user.role != 'admin' and investment.user_id != user_id:
        return jsonify({'msg': 'No autorizado para eliminar esta inversion'}), 403

    db.session.delete(investment)
    db.session.commit()
    return jsonify({'msg': 'Investment deleted successfully'}), 200
