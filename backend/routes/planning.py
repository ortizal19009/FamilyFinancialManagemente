from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy import func

try:
    from backend.models import db, MonthlyPlanning, Category, Expense, User
except ModuleNotFoundError:
    from models import db, MonthlyPlanning, Category, Expense, User

planning_bp = Blueprint('planning', __name__)

@planning_bp.route('/', methods=['GET'])
@jwt_required()
def get_planning():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    month = request.args.get('month', type=int)
    year = request.args.get('year', type=int)
    
    if not month or not year:
        return jsonify({"msg": "Month and year parameters are required"}), 400

    # Obtener presupuestos planeados
    if user.role == 'admin':
        plans = MonthlyPlanning.query.filter_by(month=month, year=year).all()
    else:
        # Aquí podrías filtrar por usuario si decides que cada uno tiene su plan,
        # pero normalmente la planificación familiar es compartida por el admin.
        plans = MonthlyPlanning.query.filter_by(month=month, year=year).all()
    
    # Obtener gastos reales por categoría para ese mes/año
    # Si no es admin, solo sumamos sus propios gastos
    query = db.session.query(
        Expense.category_id, 
        func.sum(Expense.amount).label('total')
    ).filter(
        func.extract('month', Expense.expense_date) == month,
        func.extract('year', Expense.expense_date) == year
    )
    
    if user.role != 'admin':
        query = query.filter(Expense.user_id == user_id)
        
    actual_expenses = query.group_by(Expense.category_id).all()
    
    expenses_dict = {category_id: float(total) for category_id, total in actual_expenses}

    result = []
    for p in plans:
        category_name = p.category.name if p.category else "Sin categoría"
        actual = expenses_dict.get(p.category_id, 0.0)
        result.append({
            "id": p.id,
            "category_id": p.category_id,
            "category_name": category_name,
            "planned_amount": float(p.planned_amount),
            "actual_amount": actual,
            "remaining": float(p.planned_amount) - actual,
            "month": p.month,
            "year": p.year
        })

    return jsonify(result), 200

@planning_bp.route('/', methods=['POST'])
@jwt_required()
def create_or_update_plan():
    data = request.get_json()
    
    if not data or not data.get('category_id') or not data.get('planned_amount'):
        return jsonify({"msg": "category_id, planned_amount, month and year are required"}), 400
    
    month = data.get('month')
    year = data.get('year')
    category_id = data.get('category_id')

    # Buscar si ya existe un plan para esa categoría/mes/año
    plan = MonthlyPlanning.query.filter_by(
        category_id=category_id, 
        month=month, 
        year=year
    ).first()

    if plan:
        plan.planned_amount = data['planned_amount']
    else:
        plan = MonthlyPlanning(
            category_id=category_id,
            planned_amount=data['planned_amount'],
            month=month,
            year=year
        )
        db.session.add(plan)
    
    db.session.commit()
    return jsonify({"msg": "Planning saved successfully", "id": plan.id}), 201
