from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import bcrypt

db = SQLAlchemy()


class FinancialMovement(db.Model):
    __tablename__ = 'financial_movements'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    movement_type = db.Column(db.String(50), nullable=False)  # GASTO, INGRESO, REVERSION, TRANSFERENCIA, PAGO_TARJETA, PAGO_PRESTAMO, ...
    source_type = db.Column(db.String(50), nullable=False)  # EXPENSE, INCOME, TRANSFER, CARD_PAYMENT, LOAN_PAYMENT, ...
    source_id = db.Column(db.Integer, nullable=False)
    account_id = db.Column(db.Integer, db.ForeignKey('bank_accounts.id', ondelete='SET NULL'))
    card_id = db.Column(db.Integer, db.ForeignKey('cards.id', ondelete='SET NULL'))
    amount = db.Column(db.Numeric(15, 2), nullable=False)
    direction = db.Column(db.String(4), nullable=False)  # IN / OUT (respecto al patrimonio del usuario)
    movement_date = db.Column(db.Date, nullable=False)
    status = db.Column(db.String(20), default='ACTIVO')  # ACTIVO, ANULADO, REVERSADO
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    created_by = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='SET NULL'))

    user = db.relationship('User', foreign_keys=[user_id], backref='financial_movements', lazy=True)
    creator = db.relationship('User', foreign_keys=[created_by], lazy=True)
    bank_account = db.relationship('BankAccount', backref='financial_movements', lazy=True)
    card = db.relationship('Card', backref='financial_movements', lazy=True)


class AuditLog(db.Model):
    __tablename__ = 'audit_log'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='SET NULL'))
    action = db.Column(db.String(30), nullable=False)  # CREATE, UPDATE, CANCEL, LOGIN, DELETE, ...
    entity = db.Column(db.String(50), nullable=False)
    entity_id = db.Column(db.Integer)
    old_values = db.Column(db.JSON)
    new_values = db.Column(db.JSON)
    ip_address = db.Column(db.String(64))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref='audit_logs', lazy=True)

class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), default='member')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def set_password(self, password):
        salt = bcrypt.gensalt()
        self.password_hash = bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

    def check_password(self, password):
        return bcrypt.checkpw(password.encode('utf-8'), self.password_hash.encode('utf-8'))

class FamilyMember(db.Model):
    __tablename__ = 'family_members'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='SET NULL'), unique=True)
    name = db.Column(db.String(100), nullable=False)
    relationship = db.Column(db.String(50))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref=db.backref('family_member', uselist=False), lazy=True)

class FamilyRelationship(db.Model):
    __tablename__ = 'family_relationships'
    id = db.Column(db.Integer, primary_key=True)
    source_member_id = db.Column(db.Integer, db.ForeignKey('family_members.id', ondelete='CASCADE'), nullable=False)
    target_member_id = db.Column(db.Integer, db.ForeignKey('family_members.id', ondelete='CASCADE'), nullable=False)
    relationship = db.Column(db.String(50), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    __table_args__ = (
        db.UniqueConstraint('source_member_id', 'target_member_id', name='uq_family_relationship_pair'),
    )

    source_member = db.relationship(
        'FamilyMember',
        foreign_keys=[source_member_id],
        backref=db.backref('outgoing_relationships', lazy=True, cascade='all, delete-orphan'),
        lazy=True,
    )
    target_member = db.relationship(
        'FamilyMember',
        foreign_keys=[target_member_id],
        backref=db.backref('incoming_relationships', lazy=True, cascade='all, delete-orphan'),
        lazy=True,
    )

class Bank(db.Model):
    __tablename__ = 'banks'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    accounts = db.relationship('BankAccount', backref='bank', lazy=True)

class BankAccount(db.Model):
    __tablename__ = 'bank_accounts'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'))
    bank_id = db.Column(db.Integer, db.ForeignKey('banks.id', ondelete='CASCADE'))
    account_number = db.Column(db.String(50))
    account_type = db.Column(db.String(50))
    owner = db.Column(db.String(100))
    current_balance = db.Column(db.Numeric(15, 2), default=0.00)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref=db.backref('bank_accounts', lazy=True), lazy=True)


class Transfer(db.Model):
    __tablename__ = 'transfers'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    from_account_id = db.Column(db.Integer, db.ForeignKey('bank_accounts.id', ondelete='SET NULL'))
    to_account_id = db.Column(db.Integer, db.ForeignKey('bank_accounts.id', ondelete='SET NULL'))
    amount = db.Column(db.Numeric(15, 2), nullable=False)
    transfer_date = db.Column(db.Date, nullable=False)
    description = db.Column(db.Text)
    status = db.Column(db.String(20), default='ACTIVO')  # ACTIVO, ANULADO, REVERSADO
    cancelled_at = db.Column(db.DateTime)
    cancelled_by = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='SET NULL'))
    cancellation_reason = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', foreign_keys=[user_id], backref='transfers', lazy=True)
    from_account = db.relationship('BankAccount', foreign_keys=[from_account_id], backref='transfers_out', lazy=True)
    to_account = db.relationship('BankAccount', foreign_keys=[to_account_id], backref='transfers_in', lazy=True)
    canceller = db.relationship('User', foreign_keys=[cancelled_by])


class CardPayment(db.Model):
    __tablename__ = 'card_payments'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    card_id = db.Column(db.Integer, db.ForeignKey('cards.id', ondelete='SET NULL'))
    account_id = db.Column(db.Integer, db.ForeignKey('bank_accounts.id', ondelete='SET NULL'))
    amount = db.Column(db.Numeric(15, 2), nullable=False)
    payment_date = db.Column(db.Date, nullable=False)
    description = db.Column(db.Text)
    status = db.Column(db.String(20), default='ACTIVO')
    cancelled_at = db.Column(db.DateTime)
    cancelled_by = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='SET NULL'))
    cancellation_reason = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', foreign_keys=[user_id], backref='card_payments', lazy=True)
    card = db.relationship('Card', backref='card_payments', lazy=True)
    account = db.relationship('BankAccount', backref='card_payments', lazy=True)
    canceller = db.relationship('User', foreign_keys=[cancelled_by])


class LoanPayment(db.Model):
    __tablename__ = 'loan_payments'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    loan_id = db.Column(db.Integer, db.ForeignKey('loans.id', ondelete='SET NULL'))
    account_id = db.Column(db.Integer, db.ForeignKey('bank_accounts.id', ondelete='SET NULL'))
    amount = db.Column(db.Numeric(15, 2), nullable=False)
    principal_paid = db.Column(db.Numeric(15, 2), nullable=False)
    interest_paid = db.Column(db.Numeric(15, 2), nullable=False)
    balance_after = db.Column(db.Numeric(15, 2), nullable=False)
    payment_date = db.Column(db.Date, nullable=False)
    description = db.Column(db.Text)
    status = db.Column(db.String(20), default='ACTIVO')
    cancelled_at = db.Column(db.DateTime)
    cancelled_by = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='SET NULL'))
    cancellation_reason = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', foreign_keys=[user_id], backref='loan_payments', lazy=True)
    loan = db.relationship('Loan', backref='loan_payments', lazy=True)
    account = db.relationship('BankAccount', backref='loan_payments', lazy=True)
    canceller = db.relationship('User', foreign_keys=[cancelled_by])

class Card(db.Model):
    __tablename__ = 'cards'
    id = db.Column(db.Integer, primary_key=True)
    bank_id = db.Column(db.Integer, db.ForeignKey('banks.id', ondelete='CASCADE'))
    bank_account_id = db.Column(db.Integer, db.ForeignKey('bank_accounts.id', ondelete='SET NULL'))
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='SET NULL'))
    card_name = db.Column(db.String(100))
    owner = db.Column(db.String(100))
    last_four_digits = db.Column(db.String(4))
    card_type = db.Column(db.String(20)) # 'Crédito' o 'Débito'
    credit_limit = db.Column(db.Numeric(15, 2), default=0.00)
    current_debt = db.Column(db.Numeric(15, 2), default=0.00)
    available_balance = db.Column(db.Numeric(15, 2), default=0.00)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    bank = db.relationship('Bank', backref='cards', lazy=True)
    bank_account = db.relationship('BankAccount', backref='cards', lazy=True)
    user = db.relationship('User', backref='cards', lazy=True)

class Loan(db.Model):
    __tablename__ = 'loans'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='SET NULL'))
    bank_id = db.Column(db.Integer, db.ForeignKey('banks.id', ondelete='SET NULL'))
    description = db.Column(db.String(255), nullable=False)
    owner = db.Column(db.String(100))
    initial_amount = db.Column(db.Numeric(15, 2), nullable=False)
    total_installments = db.Column(db.Integer, nullable=False)
    pending_installments = db.Column(db.Integer, nullable=False)
    monthly_payment = db.Column(db.Numeric(15, 2), nullable=False)
    interest_rate = db.Column(db.Numeric(5, 2))
    start_date = db.Column(db.Date)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    bank = db.relationship('Bank', backref='loans', lazy=True)
    user = db.relationship('User', backref='loans', lazy=True)

class Asset(db.Model):
    __tablename__ = 'assets'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'))
    name = db.Column(db.String(100), nullable=False)
    value = db.Column(db.Numeric(15, 2), nullable=False)
    owner = db.Column(db.String(100))
    description = db.Column(db.Text)
    purchase_date = db.Column(db.Date)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref=db.backref('assets', lazy=True), lazy=True)


class Investment(db.Model):
    __tablename__ = 'investments'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'))
    institution = db.Column(db.String(120), nullable=False)
    investment_type = db.Column(db.String(50), nullable=False)
    title = db.Column(db.String(150), nullable=False)
    owner = db.Column(db.String(100))
    invested_amount = db.Column(db.Numeric(15, 2), nullable=False)
    current_value = db.Column(db.Numeric(15, 2), nullable=False, default=0.00)
    expected_return_rate = db.Column(db.Numeric(5, 2))
    start_date = db.Column(db.Date)
    end_date = db.Column(db.Date)
    status = db.Column(db.String(30), default='activa')
    notes = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref='investments', lazy=True)

class Category(db.Model):
    __tablename__ = 'categories'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True, nullable=False)
    icon = db.Column(db.String(50))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class MonthlyPlanning(db.Model):
    __tablename__ = 'monthly_planning'
    id = db.Column(db.Integer, primary_key=True)
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id', ondelete='CASCADE'))
    planned_amount = db.Column(db.Numeric(15, 2), nullable=False)
    month = db.Column(db.Integer, nullable=False)
    year = db.Column(db.Integer, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    category = db.relationship('Category', backref='plans', lazy=True)

class Income(db.Model):
    __tablename__ = 'income'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'))
    amount = db.Column(db.Numeric(15, 2), nullable=False)
    source = db.Column(db.String(100), nullable=False)
    income_date = db.Column(db.Date, nullable=False)
    destination_type = db.Column(db.String(20), default='cash')
    bank_account_id = db.Column(db.Integer, db.ForeignKey('bank_accounts.id', ondelete='SET NULL'))
    description = db.Column(db.Text)
    status = db.Column(db.String(20), default='ACTIVO')  # ACTIVO, ANULADO, REVERSADO
    cancelled_at = db.Column(db.DateTime)
    cancelled_by = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='SET NULL'))
    cancellation_reason = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', foreign_keys=[user_id], backref='income_records', lazy=True)
    bank_account = db.relationship('BankAccount', backref='income_records', lazy=True)
    canceller = db.relationship('User', foreign_keys=[cancelled_by])

class Debtor(db.Model):
    __tablename__ = 'debtors'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'))
    name = db.Column(db.String(100), nullable=False)
    amount_owed = db.Column(db.Numeric(15, 2), nullable=False)
    description = db.Column(db.Text)
    due_date = db.Column(db.Date)
    status = db.Column(db.String(20), default='pendiente')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref='debtors', lazy=True)


class SmallDebt(db.Model):
    __tablename__ = 'small_debts'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'))
    lender_name = db.Column(db.String(100), nullable=False)
    amount = db.Column(db.Numeric(15, 2), nullable=False)
    description = db.Column(db.Text)
    borrowed_date = db.Column(db.Date)
    due_date = db.Column(db.Date)
    status = db.Column(db.String(20), default='pendiente')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref='small_debts', lazy=True)

class Expense(db.Model):
    __tablename__ = 'expenses'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'))
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id', ondelete='SET NULL'))
    amount = db.Column(db.Numeric(15, 2), nullable=False)
    payment_method = db.Column(db.String(50), nullable=False) # 'Tarjeta Crédito', 'Tarjeta Débito', 'Banca Móvil', 'Efectivo', 'Fiado'
    card_id = db.Column(db.Integer, db.ForeignKey('cards.id', ondelete='SET NULL'))
    bank_account_id = db.Column(db.Integer, db.ForeignKey('bank_accounts.id', ondelete='SET NULL'))
    expense_date = db.Column(db.Date, nullable=False)
    description = db.Column(db.Text)
    status = db.Column(db.String(20), default='ACTIVO')  # ACTIVO, ANULADO, REVERSADO
    cancelled_at = db.Column(db.DateTime)
    cancelled_by = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='SET NULL'))
    cancellation_reason = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', foreign_keys=[user_id], backref='expenses', lazy=True)
    category = db.relationship('Category', backref='expenses', lazy=True)
    card = db.relationship('Card', backref='expenses', lazy=True)
    bank_account = db.relationship('BankAccount', backref='expenses', lazy=True)
    canceller = db.relationship('User', foreign_keys=[cancelled_by])
