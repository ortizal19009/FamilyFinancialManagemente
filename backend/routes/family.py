from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

try:
    from backend.models import FamilyMember, FamilyRelationship, User, db
except ModuleNotFoundError:
    from models import FamilyMember, FamilyRelationship, User, db

family_bp = Blueprint('family', __name__)

INVERSE_RELATIONSHIPS = {
    'esposa': 'esposo',
    'esposo': 'esposa',
    'pareja': 'pareja',
    'hijo': 'padre/madre',
    'hija': 'padre/madre',
    'hijo/a': 'padre/madre',
    'padre': 'hijo/a',
    'madre': 'hijo/a',
    'padre/madre': 'hijo/a',
    'hermano': 'hermano',
    'hermana': 'hermana',
    'hermano/a': 'hermano/a',
    'abuelo': 'nieto/a',
    'abuela': 'nieto/a',
    'nieto': 'abuelo/a',
    'nieta': 'abuelo/a',
}


def normalize_relationship(value):
    return (value or '').strip()


def inverse_relationship(value):
    relationship = normalize_relationship(value)
    if not relationship:
        return ''

    return INVERSE_RELATIONSHIPS.get(relationship.lower(), '')


def ensure_user_member(user):
    member = FamilyMember.query.filter_by(user_id=user.id).first()
    if member:
        if member.name != user.full_name:
            member.name = user.full_name
            db.session.commit()
        return member

    member = FamilyMember(
        user_id=user.id,
        name=user.full_name,
        relationship='Yo',
    )
    db.session.add(member)
    db.session.commit()
    return member


def upsert_relationship(source_member_id, target_member_id, relationship):
    relation = FamilyRelationship.query.filter_by(
        source_member_id=source_member_id,
        target_member_id=target_member_id,
    ).first()

    if relation:
        relation.relationship = relationship
        return relation

    relation = FamilyRelationship(
        source_member_id=source_member_id,
        target_member_id=target_member_id,
        relationship=relationship,
    )
    db.session.add(relation)
    return relation


def get_current_user_and_member():
    user_id = get_jwt_identity()
    user = db.session.get(User, int(user_id))
    if not user:
        return None, None
    return user, ensure_user_member(user)


def serialize_member(member, current_member):
    if member.id == current_member.id:
        relationship = 'Yo'
    else:
        direct = FamilyRelationship.query.filter_by(
            source_member_id=current_member.id,
            target_member_id=member.id,
        ).first()
        if direct:
            relationship = direct.relationship
        else:
            reverse = FamilyRelationship.query.filter_by(
                source_member_id=member.id,
                target_member_id=current_member.id,
            ).first()
            relationship = inverse_relationship(reverse.relationship if reverse else '') or (
                member.relationship or ''
            )

    return {
        'id': member.id,
        'user_id': member.user_id,
        'name': member.name,
        'relationship': relationship,
        'linked_user_email': member.user.email if member.user else None,
        'created_at': member.created_at,
    }


@family_bp.route('/', methods=['GET'])
@jwt_required()
def get_family_members():
    user, current_member = get_current_user_and_member()
    if not user:
        return jsonify({'msg': 'User not found'}), 404

    members = FamilyMember.query.order_by(FamilyMember.name.asc()).all()
    return jsonify([serialize_member(member, current_member) for member in members]), 200


@family_bp.route('/', methods=['POST'])
@jwt_required()
def create_family_member():
    user, current_member = get_current_user_and_member()
    if not user:
        return jsonify({'msg': 'User not found'}), 404

    data = request.get_json() or {}
    name = (data.get('name') or '').strip()
    relationship = normalize_relationship(data.get('relationship'))
    linked_user_email = (data.get('linked_user_email') or '').strip().lower()

    if not name:
        return jsonify({'msg': 'Name is required'}), 400

    linked_user = User.query.filter_by(email=linked_user_email).first() if linked_user_email else None
    member = FamilyMember.query.filter_by(user_id=linked_user.id).first() if linked_user else None

    if member and member.id == current_member.id:
        return jsonify({'msg': 'No puedes agregarte como otro integrante'}), 400

    if member is None:
        member = FamilyMember(
            user_id=linked_user.id if linked_user else None,
            name=linked_user.full_name if linked_user else name,
            relationship=relationship,
        )
        db.session.add(member)
        db.session.flush()
    else:
        member.name = linked_user.full_name if linked_user else name
        member.relationship = relationship

    upsert_relationship(current_member.id, member.id, relationship)

    inverse = inverse_relationship(relationship)
    if inverse:
        upsert_relationship(member.id, current_member.id, inverse)

    db.session.commit()
    return jsonify({
        'msg': 'Family member added',
        'member': serialize_member(member, current_member),
    }), 201


@family_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_family_member(id):
    user, current_member = get_current_user_and_member()
    if not user:
        return jsonify({'msg': 'User not found'}), 404

    data = request.get_json() or {}
    member = db.session.get(FamilyMember, id)
    if not member:
        return jsonify({'msg': 'Member not found'}), 404

    linked_user_email = (data.get('linked_user_email') or '').strip().lower()
    linked_user = User.query.filter_by(email=linked_user_email).first() if linked_user_email else None
    relationship = normalize_relationship(data.get('relationship'))

    member.name = (linked_user.full_name if linked_user else data.get('name') or member.name).strip()
    member.user_id = linked_user.id if linked_user else member.user_id
    member.relationship = relationship or member.relationship

    if member.id != current_member.id and relationship:
        upsert_relationship(current_member.id, member.id, relationship)
        inverse = inverse_relationship(relationship)
        if inverse:
            upsert_relationship(member.id, current_member.id, inverse)

    db.session.commit()
    return jsonify({
        'msg': 'Member updated',
        'member': serialize_member(member, current_member),
    }), 200


@family_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_family_member(id):
    member = db.session.get(FamilyMember, id)
    if not member:
        return jsonify({'msg': 'Member not found'}), 404

    db.session.delete(member)
    db.session.commit()
    return jsonify({'msg': 'Member deleted'}), 200
