from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity

try:
    from backend.models import db, User
except ModuleNotFoundError:
    from models import db, User

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    
    if not data or not data.get('email') or not data.get('password'):
        return jsonify({"msg": "Email and password are required"}), 400
    
    if User.query.filter_by(email=data['email']).first():
        return jsonify({"msg": "User already exists"}), 400
    
    new_user = User(
        full_name=data.get('full_name'),
        email=data['email'],
        role=data.get('role', 'member')
    )
    new_user.set_password(data['password'])
    
    db.session.add(new_user)
    db.session.commit()
    
    return jsonify({"msg": "User created successfully"}), 201

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    
    if not data or not data.get('email') or not data.get('password'):
        return jsonify({"msg": "Email and password are required"}), 400
    
    user = User.query.filter_by(email=data['email']).first()
    
    if user and user.check_password(data['password']):
        # Asegurar que la identidad sea una cadena para evitar problemas de serialización
        access_token = create_access_token(identity=str(user.id))
        return jsonify({
            "access_token": access_token,
            "user": {
                "id": user.id,
                "full_name": user.full_name,
                "email": user.email,
                "role": user.role
            }
        }), 200
    
    return jsonify({"msg": "Bad email or password"}), 401

@auth_bp.route('/users', methods=['GET'])
@jwt_required()
def get_users():
    admin_id = get_jwt_identity()
    admin = db.session.get(User, int(admin_id))
    if admin.role != 'admin':
        return jsonify({"msg": "Admin privilege required"}), 403
    
    users = User.query.all()
    return jsonify([{
        "id": u.id,
        "full_name": u.full_name,
        "email": u.email,
        "role": u.role,
        "created_at": u.created_at
    } for u in users]), 200

@auth_bp.route('/users', methods=['POST'])
@jwt_required()
def admin_create_user():
    admin_id = get_jwt_identity()
    admin = db.session.get(User, int(admin_id))
    if admin.role != 'admin':
        return jsonify({"msg": "Admin privilege required"}), 403
    
    data = request.get_json()
    if not data or not data.get('email') or not data.get('password'):
        return jsonify({"msg": "Email and password are required"}), 400
    
    if User.query.filter_by(email=data['email']).first():
        return jsonify({"msg": "User already exists"}), 400
    
    new_user = User(
        full_name=data.get('full_name'),
        email=data['email'],
        role=data.get('role', 'member')
    )
    new_user.set_password(data['password'])
    
    db.session.add(new_user)
    db.session.commit()
    return jsonify({"msg": "User created successfully", "id": new_user.id}), 201

@auth_bp.route('/me', methods=['GET'])
@jwt_required()
def get_me():
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if not user:
        return jsonify({"msg": "User not found"}), 404
    return jsonify({
        "id": user.id,
        "full_name": user.full_name,
        "email": user.email,
        "role": user.role
    }), 200
