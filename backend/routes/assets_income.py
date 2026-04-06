from datetime import datetime

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.orm import joinedload

try:
    from backend.models import db, Asset, Income, User
except ModuleNotFoundError:
    from models import db, Asset, Income, User

assets_income_bp = Blueprint('assets_income', __name__)

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

# --- Rutas para Ingresos ---

@assets_income_bp.route('/income', methods=['GET'])
@jwt_required()
def get_income():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    if user.role == 'admin':
        income_records = Income.query.options(joinedload(Income.user)).order_by(Income.income_date.desc()).all()
    else:
        income_records = Income.query.options(joinedload(Income.user)).filter_by(user_id=user_id).order_by(Income.income_date.desc()).all()
        
    return jsonify([{
        "id": i.id,
        "user_name": i.user.full_name if i.user else None,
        "amount": float(i.amount),
        "source": i.source,
        "income_date": i.income_date.strftime('%Y-%m-%d'),
        "description": i.description
    } for i in income_records]), 200

@assets_income_bp.route('/income', methods=['POST'])
@jwt_required()
def create_income():
    user_id = int(get_jwt_identity())
    data = request.get_json()
    
    if not data or not data.get('amount') or not data.get('source') or not data.get('income_date'):
        return jsonify({"msg": "Amount, source and income_date are required"}), 400
    
    new_income = Income(
        user_id=user_id,
        amount=data['amount'],
        source=data['source'],
        income_date=datetime.strptime(data['income_date'], '%Y-%m-%d'),
        description=data.get('description')
    )
    db.session.add(new_income)
    db.session.commit()
    return jsonify({"msg": "Income registered successfully", "id": new_income.id}), 201
