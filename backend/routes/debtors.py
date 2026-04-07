from datetime import datetime

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

try:
    from backend.models import db, Debtor, User
except ModuleNotFoundError:
    from models import db, Debtor, User

debtors_bp = Blueprint('debtors', __name__)

@debtors_bp.route('/', methods=['GET'])
@jwt_required()
def get_debtors():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    if not user:
        return jsonify({"msg": "User not found"}), 404

    debtors = Debtor.query.all()
        
    return jsonify([{
        "id": d.id,
        "name": d.name,
        "amount_owed": float(d.amount_owed),
        "description": d.description,
        "due_date": d.due_date.strftime('%Y-%m-%d') if d.due_date else None,
        "status": d.status,
        "created_at": d.created_at
    } for d in debtors]), 200

@debtors_bp.route('/', methods=['POST'])
@jwt_required()
def create_debtor():
    data = request.get_json()
    if not data or not data.get('name') or not data.get('amount_owed'):
        return jsonify({"msg": "Name and amount_owed are required"}), 400
    
    new_debtor = Debtor(
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
    data = request.get_json()
    debtor = Debtor.query.get_or_404(id)
    
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
    debtor = db.session.get(Debtor, id)
    if not debtor:
        return jsonify({"msg": "Debtor not found"}), 404

    db.session.delete(debtor)
    db.session.commit()
    return jsonify({"msg": "Debtor deleted successfully"}), 200
