from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.orm import joinedload

try:
    from backend.models import db, Bank, BankAccount, Card, Loan, User
except ModuleNotFoundError:
    from models import db, Bank, BankAccount, Card, Loan, User

try:
    from backend.query_helpers import apply_search, paginate_or_plain
except ModuleNotFoundError:
    from query_helpers import apply_search, paginate_or_plain

banks_bp = Blueprint('banks', __name__)


def _normalize_account_number(value):
    return (value or '').strip()


def _normalize_bank_id(value):
    if value in [None, '']:
        return None
    return int(value)


def _find_duplicate_account(bank_id, account_number, exclude_id=None):
    normalized_bank_id = _normalize_bank_id(bank_id)
    normalized_number = _normalize_account_number(account_number)
    if not normalized_bank_id or not normalized_number:
        return None

    query = BankAccount.query.filter_by(
        bank_id=normalized_bank_id,
        account_number=normalized_number
    )
    if exclude_id is not None:
        query = query.filter(BankAccount.id != exclude_id)

    return query.first()

# --- Rutas para Bancos ---

@banks_bp.route('/', methods=['GET'])
@jwt_required()
def get_banks():
    banks = Bank.query.all()
    return jsonify([{
        "id": b.id,
        "name": b.name,
        "description": b.description,
        "created_at": b.created_at
    } for b in banks]), 200

@banks_bp.route('/', methods=['POST'])
@jwt_required()
def create_bank():
    data = request.get_json()
    if not data or not data.get('name'):
        return jsonify({"msg": "Bank name is required"}), 400
    
    new_bank = Bank(
        name=data['name'],
        description=data.get('description')
    )
    db.session.add(new_bank)
    db.session.commit()
    return jsonify({"msg": "Bank created successfully", "id": new_bank.id}), 201

@banks_bp.route('/<int:bank_id>', methods=['PUT'])
@jwt_required()
def update_bank(bank_id):
    bank = db.session.get(Bank, bank_id)
    if not bank:
        return jsonify({"msg": "Bank not found"}), 404

    data = request.get_json() or {}
    name = (data.get('name') or '').strip()
    if not name:
        return jsonify({"msg": "Bank name is required"}), 400

    bank.name = name
    bank.description = data.get('description')
    db.session.commit()

    return jsonify({"msg": "Bank updated successfully"}), 200

@banks_bp.route('/<int:bank_id>', methods=['DELETE'])
@jwt_required()
def delete_bank(bank_id):
    bank = db.session.get(Bank, bank_id)
    if not bank:
        return jsonify({"msg": "Bank not found"}), 404

    related_accounts = BankAccount.query.filter_by(bank_id=bank_id).count()
    related_cards = Card.query.filter_by(bank_id=bank_id).count()
    related_loans = Loan.query.filter_by(bank_id=bank_id).count()

    if related_accounts or related_cards or related_loans:
        return jsonify({
            "msg": "No se puede eliminar el banco porque tiene registros asociados"
        }), 400

    db.session.delete(bank)
    db.session.commit()
    return jsonify({"msg": "Bank deleted successfully"}), 200

# --- Rutas para Cuentas Bancarias ---

@banks_bp.route('/accounts', methods=['GET'])
@jwt_required()
def get_accounts():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    if not user:
        return jsonify({"msg": "User not found"}), 404

    query = BankAccount.query.options(joinedload(BankAccount.bank))
    if user.role != 'admin':
        query = query.filter(BankAccount.user_id == user_id)
    if request.args.get('bank_id'):
        query = query.filter(BankAccount.bank_id == int(request.args.get('bank_id')))
    if request.args.get('account_type'):
        query = query.filter(BankAccount.account_type == request.args.get('account_type'))
    query = apply_search(query, BankAccount.account_number, BankAccount.owner)
    query = query.order_by(BankAccount.created_at.desc())

    items, meta = paginate_or_plain(query, lambda accounts: [{
        "id": a.id,
        "user_id": a.user_id,
        "bank_id": a.bank_id,
        "bank_name": a.bank.name if a.bank else None,
        "account_number": a.account_number,
        "account_type": a.account_type,
        "owner": a.owner,
        "current_balance": float(a.current_balance)
    } for a in accounts])
    if meta is None:
        return jsonify(items), 200
    return jsonify({"items": items, **meta}), 200

@banks_bp.route('/accounts', methods=['POST'])
@jwt_required()
def create_account():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    data = request.get_json()
    if not data or not data.get('bank_id') or not data.get('account_number'):
        return jsonify({"msg": "bank_id and account_number are required"}), 400

    bank_id = _normalize_bank_id(data['bank_id'])
    
    existing_account = _find_duplicate_account(bank_id, data['account_number'])
    if existing_account:
        existing_account.account_type = data.get('account_type') or existing_account.account_type
        existing_account.owner = data.get('owner') or existing_account.owner
        existing_account.current_balance = data.get('current_balance', existing_account.current_balance)
        existing_account.user_id = existing_account.user_id or user_id
        db.session.commit()
        return jsonify({
            "msg": "Account merged successfully",
            "id": existing_account.id,
            "merged": True
        }), 200

    new_account = BankAccount(
        user_id=user_id,
        bank_id=bank_id,
        account_number=_normalize_account_number(data['account_number']),
        account_type=data.get('account_type'),
        owner=data.get('owner'),
        current_balance=data.get('current_balance', 0.00)
    )
    db.session.add(new_account)
    db.session.commit()
    return jsonify({"msg": "Account created successfully", "id": new_account.id}), 201

@banks_bp.route('/accounts/<int:account_id>', methods=['PUT'])
@jwt_required()
def update_account(account_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    account = db.session.get(BankAccount, account_id)
    if not account:
        return jsonify({"msg": "Account not found"}), 404

    if user.role != 'admin' and account.user_id not in (None, user_id):
        return jsonify({"msg": "No autorizado para editar esta cuenta"}), 403

    data = request.get_json() or {}
    if not data.get('bank_id') or not data.get('account_number'):
        return jsonify({"msg": "bank_id and account_number are required"}), 400

    bank_id = _normalize_bank_id(data['bank_id'])

    duplicate = _find_duplicate_account(
        bank_id,
        data['account_number'],
        exclude_id=account.id,
    )

    if duplicate:
        duplicate.account_type = data.get('account_type') or duplicate.account_type
        duplicate.owner = data.get('owner') or duplicate.owner
        duplicate.current_balance = data.get('current_balance', duplicate.current_balance)
        duplicate.user_id = duplicate.user_id or account.user_id or user_id

        for expense in account.expenses:
            expense.bank_account_id = duplicate.id
        for card in account.cards:
            card.bank_account_id = duplicate.id

        db.session.delete(account)
        db.session.commit()
        return jsonify({
            "msg": "Account merged successfully",
            "id": duplicate.id,
            "merged": True
        }), 200

    account.user_id = account.user_id or user_id
    account.bank_id = bank_id
    account.account_number = _normalize_account_number(data['account_number'])
    account.account_type = data.get('account_type')
    account.owner = data.get('owner')
    account.current_balance = data.get('current_balance', 0.00)
    db.session.commit()

    return jsonify({"msg": "Account updated successfully"}), 200

@banks_bp.route('/accounts/<int:account_id>', methods=['DELETE'])
@jwt_required()
def delete_account(account_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"msg": "User not found"}), 404

    account = db.session.get(BankAccount, account_id)
    if not account:
        return jsonify({"msg": "Account not found"}), 404

    if user.role != 'admin' and account.user_id not in (None, user_id):
        return jsonify({"msg": "No autorizado para eliminar esta cuenta"}), 403

    if account.expenses:
        return jsonify({
            "msg": "No se puede cerrar la cuenta porque tiene gastos asociados"
        }), 400
    if account.cards:
        return jsonify({
            "msg": "No se puede cerrar la cuenta porque tiene tarjetas debito asociadas"
        }), 400

    db.session.delete(account)
    db.session.commit()
    return jsonify({"msg": "Account deleted successfully"}), 200
