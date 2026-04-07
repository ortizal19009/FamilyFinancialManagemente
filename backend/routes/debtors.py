from datetime import datetime

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

try:
    from backend.models import db, Debtor, SmallDebt, User
except ModuleNotFoundError:
    from models import db, Debtor, SmallDebt, User

debtors_bp = Blueprint('debtors', __name__)


def _serialize_debtor(debtor):
    return {
        "id": debtor.id,
        "name": debtor.name,
        "amount_owed": float(debtor.amount_owed),
        "description": debtor.description,
        "due_date": debtor.due_date.strftime('%Y-%m-%d') if debtor.due_date else None,
        "status": debtor.status,
        "created_at": debtor.created_at
    }


def _serialize_small_debt(debt):
    return {
        "id": debt.id,
        "lender_name": debt.lender_name,
        "amount": float(debt.amount),
        "description": debt.description,
        "borrowed_date": debt.borrowed_date.strftime('%Y-%m-%d') if debt.borrowed_date else None,
        "due_date": debt.due_date.strftime('%Y-%m-%d') if debt.due_date else None,
        "status": debt.status,
        "created_at": debt.created_at
    }

@debtors_bp.route('/', methods=['GET'])
@jwt_required()
def get_debtors():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    if not user:
        return jsonify({"msg": "User not found"}), 404

    if user.role == 'admin':
        debtors = Debtor.query.order_by(Debtor.created_at.desc()).all()
    else:
        debtors = Debtor.query.filter_by(user_id=user_id).order_by(Debtor.created_at.desc()).all()

    return jsonify([_serialize_debtor(d) for d in debtors]), 200

@debtors_bp.route('/', methods=['POST'])
@jwt_required()
def create_debtor():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}
    if not data.get('name') or data.get('amount_owed') in [None, '']:
        return jsonify({"msg": "Name and amount_owed are required"}), 400
    
    new_debtor = Debtor(
        user_id=user_id,
        name=data['name'],
        amount_owed=data['amount_owed'],
        description=data.get('description'),
        due_date=datetime.strptime(data['due_date'], '%Y-%m-%d') if data.get('due_date') else None,
        status=data.get('status', 'pendiente')
    )
    db.session.add(new_debtor)
    db.session.commit()
    return jsonify({"msg": "Debtor registered successfully", "id": new_debtor.id}), 201

@debtors_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_debtor_status(id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    data = request.get_json() or {}
    debtor = Debtor.query.get_or_404(id)

    if user.role != 'admin' and debtor.user_id != user_id:
        return jsonify({"msg": "No autorizado para actualizar este deudor"}), 403
    
    if 'status' in data:
        debtor.status = data['status']
    if 'name' in data and data['name']:
        debtor.name = data['name']
    if 'amount_owed' in data:
        debtor.amount_owed = data['amount_owed']
    if 'description' in data:
        debtor.description = data['description']
    if 'due_date' in data:
        debtor.due_date = datetime.strptime(data['due_date'], '%Y-%m-%d') if data.get('due_date') else None
        
    db.session.commit()
    return jsonify({"msg": "Debtor updated successfully"}), 200


@debtors_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_debtor(id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    debtor = db.session.get(Debtor, id)
    if not debtor:
        return jsonify({"msg": "Debtor not found"}), 404

    if user.role != 'admin' and debtor.user_id != user_id:
        return jsonify({"msg": "No autorizado para eliminar este deudor"}), 403

    db.session.delete(debtor)
    db.session.commit()
    return jsonify({"msg": "Debtor deleted successfully"}), 200


@debtors_bp.route('/small-debts', methods=['GET'])
@jwt_required()
def get_small_debts():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)

    if not user:
        return jsonify({"msg": "User not found"}), 404

    if user.role == 'admin':
        debts = SmallDebt.query.order_by(SmallDebt.created_at.desc()).all()
    else:
        debts = SmallDebt.query.filter_by(user_id=user_id).order_by(SmallDebt.created_at.desc()).all()

    return jsonify([_serialize_small_debt(item) for item in debts]), 200


@debtors_bp.route('/small-debts', methods=['POST'])
@jwt_required()
def create_small_debt():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}
    if not data.get('lender_name') or data.get('amount') in [None, '']:
        return jsonify({"msg": "lender_name and amount are required"}), 400

    new_debt = SmallDebt(
        user_id=user_id,
        lender_name=data['lender_name'],
        amount=data['amount'],
        description=data.get('description'),
        borrowed_date=datetime.strptime(data['borrowed_date'], '%Y-%m-%d') if data.get('borrowed_date') else None,
        due_date=datetime.strptime(data['due_date'], '%Y-%m-%d') if data.get('due_date') else None,
        status=data.get('status', 'pendiente')
    )
    db.session.add(new_debt)
    db.session.commit()
    return jsonify({"msg": "Small debt created successfully", "id": new_debt.id}), 201


@debtors_bp.route('/small-debts/<int:id>', methods=['PUT'])
@jwt_required()
def update_small_debt(id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    data = request.get_json() or {}
    debt = SmallDebt.query.get_or_404(id)

    if user.role != 'admin' and debt.user_id != user_id:
        return jsonify({"msg": "No autorizado para actualizar esta deuda"}), 403

    if 'lender_name' in data and data['lender_name']:
        debt.lender_name = data['lender_name']
    if 'amount' in data and data['amount'] not in [None, '']:
        debt.amount = data['amount']
    if 'description' in data:
        debt.description = data['description']
    if 'borrowed_date' in data:
        debt.borrowed_date = datetime.strptime(data['borrowed_date'], '%Y-%m-%d') if data.get('borrowed_date') else None
    if 'due_date' in data:
        debt.due_date = datetime.strptime(data['due_date'], '%Y-%m-%d') if data.get('due_date') else None
    if 'status' in data and data['status']:
        debt.status = data['status']

    db.session.commit()
    return jsonify({"msg": "Small debt updated successfully"}), 200


@debtors_bp.route('/small-debts/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_small_debt(id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    debt = db.session.get(SmallDebt, id)
    if not debt:
        return jsonify({"msg": "Small debt not found"}), 404

    if user.role != 'admin' and debt.user_id != user_id:
        return jsonify({"msg": "No autorizado para eliminar esta deuda"}), 403

    db.session.delete(debt)
    db.session.commit()
    return jsonify({"msg": "Small debt deleted successfully"}), 200
