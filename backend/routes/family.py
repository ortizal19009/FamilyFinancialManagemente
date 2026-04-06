from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required

try:
    from backend.models import db, FamilyMember
except ModuleNotFoundError:
    from models import db, FamilyMember

family_bp = Blueprint('family', __name__)

@family_bp.route('/', methods=['GET'])
@jwt_required()
def get_family_members():
    members = FamilyMember.query.all()
    return jsonify([{
        "id": m.id,
        "name": m.name,
        "relationship": m.relationship,
        "created_at": m.created_at
    } for m in members]), 200

@family_bp.route('/', methods=['POST'])
@jwt_required()
def create_family_member():
    data = request.get_json()
    if not data or not data.get('name'):
        return jsonify({"msg": "Name is required"}), 400
    
    new_member = FamilyMember(
        name=data['name'],
        relationship=data.get('relationship')
    )
    db.session.add(new_member)
    db.session.commit()
    return jsonify({"msg": "Family member added", "id": new_member.id}), 201

@family_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_family_member(id):
    data = request.get_json()
    member = db.session.get(FamilyMember, id)
    if not member:
        return jsonify({"msg": "Member not found"}), 404
    
    member.name = data.get('name', member.name)
    member.relationship = data.get('relationship', member.relationship)
    
    db.session.commit()
    return jsonify({"msg": "Member updated"}), 200

@family_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_family_member(id):
    member = db.session.get(FamilyMember, id)
    if not member:
        return jsonify({"msg": "Member not found"}), 404
    
    db.session.delete(member)
    db.session.commit()
    return jsonify({"msg": "Member deleted"}), 200
