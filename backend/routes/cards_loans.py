from datetime import datetime, date
from calendar import monthrange
from decimal import Decimal

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.orm import joinedload

try:
    from backend.models import (
        db,
        Card,
        Loan,
        Bank,
        BankAccount,
        User,
        CardPayment,
        LoanPayment,
    )
except ModuleNotFoundError:
    from models import db, Card, Loan, Bank, BankAccount, User, CardPayment, LoanPayment

try:
    from backend.query_helpers import apply_date_range, apply_search, paginate_or_plain
except ModuleNotFoundError:
    from query_helpers import apply_date_range, apply_search, paginate_or_plain

try:
    from backend.ledger import (
        cancel_movements_for,
        record_audit,
        record_movement,
        serialize_model,
    )
except ModuleNotFoundError:
    from ledger import cancel_movements_for, record_audit, record_movement, serialize_model

cards_loans_bp = Blueprint('cards_loans', __name__)


def _to_int(value, field_name, required=False):
    if value in [None, '']:
        if required:
            raise ValueError(f"{field_name} is required")
        return None
    return int(value)


def _to_float(value, default=0.0):
    if value in [None, '']:
        return default
    return float(value)


def _resolve_card_account(bank_id, card_type, bank_account_id, available_balance):
    normalized_card_type = (card_type or 'Débito').strip()
    account_id = _to_int(bank_account_id, 'bank_account_id') if bank_account_id not in [None, ''] else None

    if normalized_card_type == 'Débito':
        if not account_id:
            raise ValueError('bank_account_id is required for debit cards')
        account = db.session.get(BankAccount, account_id)
        if not account:
            raise ValueError('Bank account not found')
        if account.bank_id != bank_id:
            raise ValueError('Debit card bank account must belong to the selected bank')
        return account_id, float(account.current_balance or 0)

    return None, _to_float(available_balance)

# --- Rutas para Tarjetas ---

@cards_loans_bp.route('/cards', methods=['GET'])
@jwt_required()
def get_cards():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    query = Card.query.options(
        joinedload(Card.bank),
        joinedload(Card.bank_account).joinedload(BankAccount.bank),
        joinedload(Card.user),
    )
    if user.role != 'admin':
        query = query.filter(Card.user_id == user_id)
    if request.args.get('bank_id'):
        query = query.filter(Card.bank_id == int(request.args.get('bank_id')))
    if request.args.get('card_type'):
        query = query.filter(Card.card_type == request.args.get('card_type'))
    query = apply_search(query, Card.card_name, Card.owner)
    query = query.order_by(Card.created_at.desc())

    items, meta = paginate_or_plain(query, lambda cards: [{
        "id": c.id,
        "bank_id": c.bank_id,
        "bank_account_id": c.bank_account_id,
        "bank_name": c.bank.name if c.bank else None,
        "bank_account_name": (
            f"{c.bank_account.bank.name if c.bank_account and c.bank_account.bank else 'Banco'} - {c.bank_account.account_number}"
            if c.bank_account else None
        ),
        "user_name": c.user.full_name if c.user else None,
        "card_name": c.card_name,
        "owner": c.owner,
        "last_four_digits": c.last_four_digits,
        "card_type": c.card_type,
        "credit_limit": float(c.credit_limit),
        "current_debt": float(c.current_debt),
        "available_balance": float(c.available_balance)
    } for c in cards])
    if meta is None:
        return jsonify(items), 200
    return jsonify({"items": items, **meta}), 200

@cards_loans_bp.route('/cards', methods=['POST'])
@jwt_required()
def create_card():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}
    if not data.get('bank_id') or not data.get('card_name'):
        return jsonify({"msg": "bank_id and card_name are required"}), 400

    try:
        bank_id = _to_int(data.get('bank_id'), 'bank_id', required=True)
        bank_account_id, available_balance = _resolve_card_account(
            bank_id,
            data.get('card_type', 'Débito'),
            data.get('bank_account_id'),
            data.get('available_balance'),
        )
    except (TypeError, ValueError) as exc:
        return jsonify({"msg": str(exc)}), 400
    
    new_card = Card(
        bank_id=bank_id,
        bank_account_id=bank_account_id,
        user_id=user_id, # Usar el ID del usuario autenticado
        card_name=data['card_name'],
        owner=data.get('owner'),
        last_four_digits=data.get('last_four_digits'),
        card_type=data.get('card_type', 'Débito'),
        credit_limit=_to_float(data.get('credit_limit')),
        current_debt=_to_float(data.get('current_debt')),
        available_balance=available_balance
    )
    db.session.add(new_card)
    db.session.commit()
    return jsonify({"msg": "Card created successfully", "id": new_card.id}), 201


@cards_loans_bp.route('/cards/<int:card_id>', methods=['PUT'])
@jwt_required()
def update_card(card_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    card = db.session.get(Card, card_id)

    if not card:
        return jsonify({"msg": "Card not found"}), 404

    if user.role != 'admin' and card.user_id != user_id:
        return jsonify({"msg": "No autorizado para editar esta tarjeta"}), 403

    data = request.get_json() or {}
    if not data.get('bank_id') or not data.get('card_name'):
        return jsonify({"msg": "bank_id and card_name are required"}), 400

    try:
        card.bank_id = _to_int(data.get('bank_id'), 'bank_id', required=True)
        card.bank_account_id, card.available_balance = _resolve_card_account(
            card.bank_id,
            data.get('card_type', 'Débito'),
            data.get('bank_account_id'),
            data.get('available_balance'),
        )
    except (TypeError, ValueError) as exc:
        return jsonify({"msg": str(exc)}), 400
    card.card_name = data['card_name']
    card.owner = data.get('owner')
    card.last_four_digits = data.get('last_four_digits')
    card.card_type = data.get('card_type', 'Débito')
    card.credit_limit = _to_float(data.get('credit_limit'))
    card.current_debt = _to_float(data.get('current_debt'))
    db.session.commit()

    return jsonify({"msg": "Card updated successfully"}), 200


@cards_loans_bp.route('/cards/<int:card_id>', methods=['DELETE'])
@jwt_required()
def delete_card(card_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    card = db.session.get(Card, card_id)

    if not card:
        return jsonify({"msg": "Card not found"}), 404

    if user.role != 'admin' and card.user_id != user_id:
        return jsonify({"msg": "No autorizado para eliminar esta tarjeta"}), 403

    if card.expenses:
        return jsonify({
            "msg": "No se puede eliminar la tarjeta porque tiene gastos asociados"
        }), 400

    db.session.delete(card)
    db.session.commit()
    return jsonify({"msg": "Card deleted successfully"}), 200

# --- Rutas para Préstamos ---

@cards_loans_bp.route('/loans', methods=['GET'])
@jwt_required()
def get_loans():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    query = Loan.query.options(joinedload(Loan.bank), joinedload(Loan.user))
    if user.role != 'admin':
        query = query.filter(Loan.user_id == user_id)
    if request.args.get('bank_id'):
        query = query.filter(Loan.bank_id == int(request.args.get('bank_id')))
    query = apply_search(query, Loan.description, Loan.owner)
    query = query.order_by(Loan.created_at.desc())

    items, meta = paginate_or_plain(query, lambda loans: [{
        "id": l.id,
        "bank_id": l.bank_id,
        "bank_name": l.bank.name if l.bank else None,
        "description": l.description,
        "owner": l.owner,
        "initial_amount": float(l.initial_amount),
        "total_installments": l.total_installments,
        "pending_installments": l.pending_installments,
        "monthly_payment": float(l.monthly_payment),
        "interest_rate": float(l.interest_rate) if l.interest_rate else 0,
        "start_date": l.start_date.strftime('%Y-%m-%d') if l.start_date else None
    } for l in loans])
    if meta is None:
        return jsonify(items), 200
    return jsonify({"items": items, **meta}), 200

@cards_loans_bp.route('/loans', methods=['POST'])
@jwt_required()
def create_loan():
    user_id = int(get_jwt_identity())
    data = request.get_json() or {}
    if not data.get('description') or data.get('initial_amount') in [None, '']:
        return jsonify({"msg": "description and initial_amount are required"}), 400

    try:
        bank_id = _to_int(data.get('bank_id'), 'bank_id')
        total_installments = _to_int(data.get('total_installments'), 'total_installments') or 1
        pending_installments = _to_int(data.get('pending_installments'), 'pending_installments') or 1
    except (TypeError, ValueError) as exc:
        return jsonify({"msg": str(exc)}), 400
    
    new_loan = Loan(
        user_id=user_id, # Usar el ID del usuario autenticado
        bank_id=bank_id,
        description=data['description'],
        owner=data.get('owner'),
        initial_amount=_to_float(data['initial_amount']),
        total_installments=total_installments,
        pending_installments=pending_installments,
        monthly_payment=_to_float(data.get('monthly_payment')),
        interest_rate=_to_float(data.get('interest_rate'), default=None),
        start_date=datetime.strptime(data['start_date'], '%Y-%m-%d') if data.get('start_date') else None
    )
    db.session.add(new_loan)
    db.session.commit()
    return jsonify({"msg": "Loan created successfully", "id": new_loan.id}), 201


@cards_loans_bp.route('/loans/<int:loan_id>', methods=['PUT'])
@jwt_required()
def update_loan(loan_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    loan = db.session.get(Loan, loan_id)

    if not loan:
        return jsonify({"msg": "Loan not found"}), 404

    if user.role != 'admin' and loan.user_id != user_id:
        return jsonify({"msg": "No autorizado para editar este préstamo"}), 403

    data = request.get_json() or {}
    if not data.get('description') or data.get('initial_amount') in [None, '']:
        return jsonify({"msg": "description and initial_amount are required"}), 400

    try:
        loan.bank_id = _to_int(data.get('bank_id'), 'bank_id')
        loan.initial_amount = _to_float(data.get('initial_amount'))
        loan.total_installments = _to_int(data.get('total_installments'), 'total_installments') or 1
        loan.pending_installments = _to_int(data.get('pending_installments'), 'pending_installments') or 1
        loan.monthly_payment = _to_float(data.get('monthly_payment'))
        loan.interest_rate = _to_float(data.get('interest_rate'), default=None)
    except (TypeError, ValueError) as exc:
        return jsonify({"msg": str(exc)}), 400

    loan.description = data['description']
    loan.owner = data.get('owner')
    loan.start_date = datetime.strptime(data['start_date'], '%Y-%m-%d') if data.get('start_date') else None
    db.session.commit()
    return jsonify({"msg": "Loan updated successfully"}), 200


@cards_loans_bp.route('/loans/<int:loan_id>', methods=['DELETE'])
@jwt_required()
def delete_loan(loan_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    loan = db.session.get(Loan, loan_id)

    if not loan:
        return jsonify({"msg": "Loan not found"}), 404

    if user.role != 'admin' and loan.user_id != user_id:
        return jsonify({"msg": "No autorizado para eliminar este préstamo"}), 403

    db.session.delete(loan)
    db.session.commit()
    return jsonify({"msg": "Loan deleted successfully"}), 200


# --- Rutas para Pagos de Tarjetas ---

def _card_response(payment):
    return {
        "id": payment.id,
        "user_id": payment.user_id,
        "user_name": payment.user.full_name if payment.user else None,
        "card_id": payment.card_id,
        "card_name": payment.card.card_name if payment.card else None,
        "account_id": payment.account_id,
        "account_name": (
            f"{payment.account.bank.name if payment.account and payment.account.bank else 'Banco'} - "
            f"{payment.account.account_number}"
            if payment.account else None
        ),
        "amount": float(payment.amount),
        "payment_date": payment.payment_date.strftime('%Y-%m-%d'),
        "description": payment.description,
        "status": payment.status,
        "cancelled_at": payment.cancelled_at.isoformat() if payment.cancelled_at else None,
        "cancellation_reason": payment.cancellation_reason,
        "created_at": payment.created_at.isoformat() if payment.created_at else None,
    }


def _assert_owns(user_id, resource, resource_name):
    if not resource:
        return jsonify({"msg": f"{resource_name} not found"}), 404
    if resource.user_id != user_id:
        return jsonify({"msg": f"No autorizado para operar sobre este {resource_name.lower()}"}), 403
    return None


def _apply_card_payment(card, account, amount, sign=1):
    amount_decimal = Decimal(str(amount))
    card.current_debt = max(Decimal('0.00'), Decimal(str(card.current_debt or 0)) - (amount_decimal * sign))
    card.available_balance = max(
        Decimal('0.00'),
        Decimal(str(card.credit_limit or 0)) - Decimal(str(card.current_debt or 0)),
    )
    if account:
        account.current_balance = Decimal(str(account.current_balance or 0)) - (amount_decimal * sign)


@cards_loans_bp.route('/cards/<int:card_id>/payments', methods=['POST'])
@jwt_required()
def create_card_payment(card_id):
    user_id = int(get_jwt_identity())
    card = db.session.get(Card, card_id)
    not_authorized = _assert_owns(user_id, card, 'Tarjeta')
    if not_authorized:
        return not_authorized

    if card.card_type != 'Crédito':
        return jsonify({"msg": "Solo las tarjetas de crédito admiten pagos"}), 400

    data = request.get_json() or {}
    if data.get('amount') in [None, ''] or not data.get('payment_date'):
        return jsonify({"msg": "amount and payment_date are required"}), 400

    amount = float(data['amount'])
    if amount <= 0:
        return jsonify({"msg": "El monto debe ser mayor a 0"}), 400

    account_id = data.get('account_id')
    account = None
    if account_id:
        account = db.session.get(BankAccount, int(account_id))
        if not account or account.user_id != user_id:
            return jsonify({"msg": "La cuenta no existe o no te pertenece"}), 400
        if Decimal(str(account.current_balance or 0)) < Decimal(str(amount)):
            return jsonify({"msg": "Saldo insuficiente en la cuenta"}), 400

    payment = CardPayment(
        user_id=user_id,
        card_id=card_id,
        account_id=account.id if account else None,
        amount=amount,
        payment_date=datetime.strptime(data['payment_date'], '%Y-%m-%d'),
        description=data.get('description'),
    )
    db.session.add(payment)
    _apply_card_payment(card, account, amount, sign=1)
    try:
        db.session.flush()
        record_movement(
            user_id=user_id,
            movement_type='PAGO_TARJETA',
            source_type='CARD_PAYMENT',
            source_id=payment.id,
            amount=amount,
            direction='OUT',
            movement_date=payment.payment_date,
            account_id=account.id if account else None,
            card_id=card_id,
            description=data.get('description') or f'Pago tarjeta {card.card_name}',
        )
        record_audit(
            'CREATE',
            'card_payment',
            payment.id,
            old_values=None,
            new_values=serialize_model(payment),
            user_id=user_id,
        )
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise
    return jsonify({"msg": "Card payment created successfully", "id": payment.id}), 201


@cards_loans_bp.route('/cards/payments', methods=['GET'])
@jwt_required()
def get_card_payments():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)

    query = CardPayment.query.options(
        joinedload(CardPayment.user),
        joinedload(CardPayment.card),
        joinedload(CardPayment.account).joinedload(BankAccount.bank),
    )
    if user.role != 'admin':
        query = query.filter(CardPayment.user_id == user_id)
    if request.args.get('card_id'):
        query = query.filter(CardPayment.card_id == int(request.args.get('card_id')))
    if request.args.get('include_cancelled', '').lower() not in ('true', '1'):
        query = query.filter(CardPayment.status != 'ANULADO')

    query = apply_date_range(query, CardPayment.payment_date)
    query = query.order_by(CardPayment.payment_date.desc(), CardPayment.created_at.desc())

    items, meta = paginate_or_plain(query, lambda payments: [_card_response(p) for p in payments])
    if meta is None:
        return jsonify(items), 200
    return jsonify({"items": items, **meta}), 200


@cards_loans_bp.route('/cards/payments/<int:payment_id>', methods=['DELETE'])
@jwt_required()
def delete_card_payment(payment_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    payment = db.session.get(CardPayment, payment_id)

    if not payment:
        return jsonify({"msg": "Card payment not found"}), 404
    if user.role != 'admin' and payment.user_id != user_id:
        return jsonify({"msg": "No autorizado para anular este pago"}), 403
    if payment.status != 'ACTIVO':
        return jsonify({"msg": "El pago ya fue anulado"}), 400

    data = request.get_json(silent=True) or {}
    reason = (data.get('reason') or '').strip() or None

    card = db.session.get(Card, payment.card_id) if payment.card_id else None
    account = db.session.get(BankAccount, payment.account_id) if payment.account_id else None

    old_values = serialize_model(payment)
    if card:
        _apply_card_payment(card, account, payment.amount, sign=-1)
    cancel_movements_for(user_id, 'CARD_PAYMENT', payment_id)

    now = datetime.utcnow()
    payment.status = 'ANULADO'
    payment.cancelled_at = now
    payment.cancelled_by = user_id
    payment.cancellation_reason = reason

    record_movement(
        user_id=user_id,
        movement_type='REVERSION',
        source_type='CARD_PAYMENT',
        source_id=payment_id,
        amount=payment.amount,
        direction='IN',
        movement_date=payment.payment_date,
        account_id=payment.account_id,
        card_id=payment.card_id,
        description=reason or f'Anulación del pago de tarjeta {payment_id}',
        status='REVERSADO',
    )
    record_audit(
        'CANCEL',
        'card_payment',
        payment_id,
        old_values=old_values,
        new_values={
            'status': 'ANULADO',
            'reason': reason,
            'cancelled_at': now.isoformat(),
            'cancelled_by': user_id,
        },
        user_id=user_id,
    )
    db.session.commit()
    return jsonify({"msg": "Card payment cancelled successfully"}), 200


# --- Rutas para Pagos y Amortización de Préstamos ---

def _loan_payment_response(payment):
    return {
        "id": payment.id,
        "user_id": payment.user_id,
        "user_name": payment.user.full_name if payment.user else None,
        "loan_id": payment.loan_id,
        "loan_description": payment.loan.description if payment.loan else None,
        "account_id": payment.account_id,
        "amount": float(payment.amount),
        "principal_paid": float(payment.principal_paid),
        "interest_paid": float(payment.interest_paid),
        "balance_after": float(payment.balance_after),
        "payment_date": payment.payment_date.strftime('%Y-%m-%d'),
        "description": payment.description,
        "status": payment.status,
        "cancelled_at": payment.cancelled_at.isoformat() if payment.cancelled_at else None,
        "cancellation_reason": payment.cancellation_reason,
        "created_at": payment.created_at.isoformat() if payment.created_at else None,
    }


def _loan_remaining_balance(loan):
    active_principal = sum(
        float(p.principal_paid) for p in LoanPayment.query.filter_by(
            loan_id=loan.id, status='ACTIVO'
        ).all()
    )
    return max(0.0, float(loan.initial_amount) - active_principal)


def _monthly_rate(loan):
    if not loan.interest_rate:
        return 0.0
    return float(loan.interest_rate) / 100.0 / 12.0


def _amortization_schedule(loan):
    rate = _monthly_rate(loan)
    payment = float(loan.monthly_payment or 0)
    balance = float(loan.initial_amount or 0)
    start = loan.start_date or datetime.utcnow().date()
    active_payments = LoanPayment.query.filter_by(loan_id=loan.id, status='ACTIVO').count()

    schedule = []
    for number in range(1, int(loan.total_installments or 1) + 1):
        if balance <= 0.000001:
            break
        interest = balance * rate
        if payment <= 0:
            principal = 0.0
            payment_due = interest
        else:
            principal = min(balance, max(0.0, payment - interest))
            payment_due = payment
        balance = max(0.0, balance - principal)
        due_date = _add_months(start, number)
        schedule.append({
            "number": number,
            "due_date": due_date.strftime('%Y-%m-%d'),
            "payment": round(payment_due, 2),
            "interest": round(interest, 2),
            "principal": round(principal, 2),
            "balance": round(balance, 2),
            "paid": active_payments >= number,
        })
    return schedule


def _add_months(base_date, months):
    month_index = base_date.month - 1 + months
    year = base_date.year + month_index // 12
    month = month_index % 12 + 1
    day = min(base_date.day, monthrange(year, month)[1])
    return date(year, month, day)


@cards_loans_bp.route('/loans/<int:loan_id>/payments', methods=['POST'])
@jwt_required()
def create_loan_payment(loan_id):
    user_id = int(get_jwt_identity())
    loan = db.session.get(Loan, loan_id)
    not_authorized = _assert_owns(user_id, loan, 'Préstamo')
    if not_authorized:
        return not_authorized

    data = request.get_json() or {}
    if not data.get('payment_date'):
        return jsonify({"msg": "payment_date is required"}), 400

    amount = float(data.get('amount') or 0)
    if amount <= 0:
        amount = float(loan.monthly_payment or 0)
    if amount <= 0:
        return jsonify({"msg": "Debe indicar un monto de pago"}), 400

    if int(loan.pending_installments or 0) <= 0:
        return jsonify({"msg": "El préstamo no tiene cuotas pendientes"}), 400

    account_id = data.get('account_id')
    account = None
    if account_id:
        account = db.session.get(BankAccount, int(account_id))
        if not account or account.user_id != user_id:
            return jsonify({"msg": "La cuenta no existe o no te pertenece"}), 400
        if Decimal(str(account.current_balance or 0)) < Decimal(str(amount)):
            return jsonify({"msg": "Saldo insuficiente en la cuenta"}), 400

    remaining = _loan_remaining_balance(loan)
    rate = _monthly_rate(loan)
    interest = min(amount, remaining * rate)
    principal = amount - interest
    new_balance = max(0.0, remaining - principal)

    payment = LoanPayment(
        user_id=user_id,
        loan_id=loan_id,
        account_id=account.id if account else None,
        amount=amount,
        principal_paid=principal,
        interest_paid=interest,
        balance_after=new_balance,
        payment_date=datetime.strptime(data['payment_date'], '%Y-%m-%d'),
        description=data.get('description'),
    )
    db.session.add(payment)
    loan.pending_installments = max(0, int(loan.pending_installments or 1) - 1)
    if account:
        account.current_balance = Decimal(str(account.current_balance or 0)) - Decimal(str(amount))
    try:
        db.session.flush()
        record_movement(
            user_id=user_id,
            movement_type='PAGO_PRESTAMO',
            source_type='LOAN_PAYMENT',
            source_id=payment.id,
            amount=amount,
            direction='OUT',
            movement_date=payment.payment_date,
            account_id=account.id if account else None,
            description=data.get('description') or f'Pago préstamo {loan.description}',
        )
        record_audit(
            'CREATE',
            'loan_payment',
            payment.id,
            old_values=None,
            new_values=serialize_model(payment),
            user_id=user_id,
        )
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise
    return jsonify({
        "msg": "Loan payment registered successfully",
        "id": payment.id,
        "principal_paid": round(principal, 2),
        "interest_paid": round(interest, 2),
        "balance_after": round(new_balance, 2),
    }), 201


@cards_loans_bp.route('/loans/<int:loan_id>/payments', methods=['GET'])
@jwt_required()
def get_loan_payments(loan_id):
    user_id = int(get_jwt_identity())
    loan = db.session.get(Loan, loan_id)
    not_authorized = _assert_owns(user_id, loan, 'Préstamo')
    if not_authorized:
        return not_authorized
    if request.args.get('include_cancelled', '').lower() not in ('true', '1'):
        query = LoanPayment.query.filter_by(loan_id=loan_id).filter(LoanPayment.status != 'ANULADO')
    else:
        query = LoanPayment.query.filter_by(loan_id=loan_id)
    query = apply_date_range(query, LoanPayment.payment_date)
    query = query.options(
        joinedload(LoanPayment.loan),
        joinedload(LoanPayment.account).joinedload(BankAccount.bank),
        joinedload(LoanPayment.user),
    ).order_by(LoanPayment.payment_date.desc())

    items, meta = paginate_or_plain(query, lambda payments: [_loan_payment_response(p) for p in payments])
    if meta is None:
        return jsonify(items), 200
    return jsonify({"items": items, **meta}), 200


@cards_loans_bp.route('/loans/<int:loan_id>/amortization', methods=['GET'])
@jwt_required()
def get_loan_amortization(loan_id):
    user_id = int(get_jwt_identity())
    loan = db.session.get(Loan, loan_id)
    not_authorized = _assert_owns(user_id, loan, 'Préstamo')
    if not_authorized:
        return not_authorized

    schedule = _amortization_schedule(loan)
    total_payment = round(sum(row['payment'] for row in schedule), 2)
    total_interest = round(sum(row['interest'] for row in schedule), 2)
    total_principal = round(sum(row['principal'] for row in schedule), 2)
    return jsonify({
        "loan_id": loan.id,
        "description": loan.description,
        "initial_amount": float(loan.initial_amount),
        "interest_rate": float(loan.interest_rate) if loan.interest_rate else 0,
        "monthly_payment": float(loan.monthly_payment or 0),
        "pending_installments": loan.pending_installments,
        "remaining_balance": round(_loan_remaining_balance(loan), 2),
        "total_payment": total_payment,
        "total_interest": total_interest,
        "total_principal": total_principal,
        "schedule": schedule,
    }), 200


@cards_loans_bp.route('/loans/payments/<int:payment_id>', methods=['DELETE'])
@jwt_required()
def delete_loan_payment(payment_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    payment = db.session.get(LoanPayment, payment_id)

    if not payment:
        return jsonify({"msg": "Loan payment not found"}), 404
    if user.role != 'admin' and payment.user_id != user_id:
        return jsonify({"msg": "No autorizado para anular este pago"}), 403
    if payment.status != 'ACTIVO':
        return jsonify({"msg": "El pago ya fue anulado"}), 400

    data = request.get_json(silent=True) or {}
    reason = (data.get('reason') or '').strip() or None

    loan = db.session.get(Loan, payment.loan_id) if payment.loan_id else None
    account = db.session.get(BankAccount, payment.account_id) if payment.account_id else None

    old_values = serialize_model(payment)
    if loan:
        loan.pending_installments = min(int(loan.total_installments or 0), int(loan.pending_installments or 0) + 1)
    if account:
        account.current_balance = Decimal(str(account.current_balance or 0)) + Decimal(str(payment.amount))
    cancel_movements_for(user_id, 'LOAN_PAYMENT', payment_id)

    now = datetime.utcnow()
    payment.status = 'ANULADO'
    payment.cancelled_at = now
    payment.cancelled_by = user_id
    payment.cancellation_reason = reason

    record_movement(
        user_id=user_id,
        movement_type='REVERSION',
        source_type='LOAN_PAYMENT',
        source_id=payment_id,
        amount=payment.amount,
        direction='IN',
        movement_date=payment.payment_date,
        account_id=payment.account_id,
        description=reason or f'Anulación del pago de préstamo {payment_id}',
        status='REVERSADO',
    )
    record_audit(
        'CANCEL',
        'loan_payment',
        payment_id,
        old_values=old_values,
        new_values={
            'status': 'ANULADO',
            'reason': reason,
            'cancelled_at': now.isoformat(),
            'cancelled_by': user_id,
        },
        user_id=user_id,
    )
    db.session.commit()
    return jsonify({"msg": "Loan payment cancelled successfully"}), 200
