from datetime import datetime
from decimal import Decimal
import json
import os
import re
import uuid

from flask import Blueprint, current_app, request, jsonify, send_file
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.orm import joinedload
from werkzeug.utils import secure_filename

from pypdf import PdfReader

try:
    from PIL import Image
    import pytesseract
except ModuleNotFoundError:
    Image = None
    pytesseract = None

try:
    from backend.models import db, Expense, Category, Card, BankAccount, User
except ModuleNotFoundError:
    from models import db, Expense, Category, Card, BankAccount, User

expenses_bp = Blueprint('expenses', __name__)

ALLOWED_RECEIPT_EXTENSIONS = {'.pdf', '.png', '.jpg', '.jpeg', '.webp'}
RECEIPT_MANIFEST_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data')
RECEIPT_MANIFEST_PATH = os.path.join(RECEIPT_MANIFEST_DIR, 'expense_receipts.json')


def _ensure_receipt_manifest():
    os.makedirs(RECEIPT_MANIFEST_DIR, exist_ok=True)
    if not os.path.exists(RECEIPT_MANIFEST_PATH):
        with open(RECEIPT_MANIFEST_PATH, 'w', encoding='utf-8') as manifest_file:
            json.dump({}, manifest_file)


def _load_receipt_manifest():
    _ensure_receipt_manifest()
    with open(RECEIPT_MANIFEST_PATH, 'r', encoding='utf-8') as manifest_file:
        return json.load(manifest_file)


def _save_receipt_manifest(manifest):
    _ensure_receipt_manifest()
    with open(RECEIPT_MANIFEST_PATH, 'w', encoding='utf-8') as manifest_file:
        json.dump(manifest, manifest_file, ensure_ascii=False, indent=2)


def _store_receipt_file(file_storage):
    original_name = secure_filename(file_storage.filename or '')
    _, extension = os.path.splitext(original_name.lower())
    if extension not in ALLOWED_RECEIPT_EXTENSIONS:
        raise ValueError('Solo se permiten comprobantes PDF o imágenes')

    upload_folder = current_app.config['UPLOAD_FOLDER']
    os.makedirs(upload_folder, exist_ok=True)

    stored_name = f"{uuid.uuid4().hex}{extension}"
    stored_path = os.path.join(upload_folder, stored_name)
    file_storage.save(stored_path)

    return {
        'stored_name': stored_name,
        'original_name': original_name,
        'content_type': file_storage.mimetype,
        'stored_path': stored_path
    }


def _validate_receipt_file(file_storage):
    original_name = secure_filename(file_storage.filename or '')
    _, extension = os.path.splitext(original_name.lower())
    if extension not in ALLOWED_RECEIPT_EXTENSIONS:
        raise ValueError('Solo se permiten comprobantes PDF o imágenes')


def _normalize_text(text):
    return re.sub(r'\s+', ' ', (text or '')).strip().lower()


def _extract_text_from_pdf(file_storage):
    reader = PdfReader(file_storage.stream)
    pages_text = [page.extract_text() or '' for page in reader.pages]
    return '\n'.join(pages_text).strip()


def _extract_text_from_image(file_storage):
    if Image is None or pytesseract is None:
        raise ValueError('El análisis local de imágenes aún no está disponible en este entorno. Por ahora el análisis automático funciona con PDF')

    tesseract_cmd = os.environ.get('TESSERACT_CMD')
    if tesseract_cmd:
        pytesseract.pytesseract.tesseract_cmd = tesseract_cmd

    image = Image.open(file_storage.stream)
    return pytesseract.image_to_string(image, lang='spa+eng').strip()


def _find_date(text):
    patterns = [
        r'(\d{2}[/-]\d{2}[/-]\d{4})',
        r'(\d{4}[/-]\d{2}[/-]\d{2})'
    ]
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            raw_date = match.group(1)
            for fmt in ('%d/%m/%Y', '%d-%m-%Y', '%Y/%m/%d', '%Y-%m-%d'):
                try:
                    return datetime.strptime(raw_date, fmt).strftime('%Y-%m-%d')
                except ValueError:
                    continue
    return None


def _find_total(text):
    total_patterns = [
        r'(?:total|importe total|valor total|monto total)[^\d]{0,10}(\d+[.,]\d{2})',
        r'(\d+[.,]\d{2})'
    ]
    matches = []
    for pattern in total_patterns:
        for match in re.finditer(pattern, text, flags=re.IGNORECASE):
            try:
                value = float(match.group(1).replace('.', '').replace(',', '.'))
                matches.append(value)
            except ValueError:
                continue
        if matches:
            return max(matches)
    return None


def _find_merchant(text):
    for line in text.splitlines():
        clean_line = line.strip()
        if len(clean_line) >= 4 and not re.search(r'\d{2}[/-]\d{2}[/-]\d{4}', clean_line):
            return clean_line[:120]
    return None


def _suggest_categories(text, categories, total_amount):
    normalized_text = _normalize_text(text)
    keyword_map = {
        'alimentos': ['supermercado', 'mercado', 'alimento', 'comida', 'abarrotes'],
        'medicina': ['farmacia', 'medicina', 'medicamento', 'salud'],
        'transporte': ['gasolina', 'taxi', 'uber', 'bus', 'transporte'],
        'repuestos': ['repuesto', 'llanta', 'taller', 'aceite', 'bateria'],
        'hogar': ['limpieza', 'hogar', 'detergente', 'papel higienico'],
        'educacion': ['escuela', 'colegio', 'universidad', 'matricula', 'libros']
    }

    suggestions = []
    for category in categories:
        category_name = (category.name or '').strip()
        normalized_category = _normalize_text(category_name)
        matched = normalized_category in normalized_text
        if not matched:
            for keyword in keyword_map.get(normalized_category, []):
                if keyword in normalized_text:
                    matched = True
                    break
        if matched:
            suggestions.append({
                'category_id': category.id,
                'category_name': category_name,
                'amount': total_amount
            })

    if not suggestions and categories and total_amount:
        suggestions.append({
            'category_id': categories[0].id,
            'category_name': categories[0].name,
            'amount': total_amount
        })

    return suggestions[:3]


def _analyze_receipt_file(file_storage, categories):
    _validate_receipt_file(file_storage)

    original_name = secure_filename(file_storage.filename or '')
    _, extension = os.path.splitext(original_name.lower())
    file_storage.stream.seek(0)
    if extension == '.pdf':
        extracted_text = _extract_text_from_pdf(file_storage)
    else:
        extracted_text = _extract_text_from_image(file_storage)

    if not extracted_text:
        raise ValueError('No se pudo extraer texto del comprobante')

    total_amount = _find_total(extracted_text)
    expense_date = _find_date(extracted_text)
    merchant = _find_merchant(extracted_text)
    suggested_items = _suggest_categories(extracted_text, categories, total_amount)

    return {
        'raw_text': extracted_text[:3000],
        'description': merchant or 'Compra desde comprobante',
        'expense_date': expense_date,
        'total_amount': total_amount,
        'items': suggested_items
    }


def _link_receipt_to_expenses(expense_ids, receipt_metadata):
    manifest = _load_receipt_manifest()
    for expense_id in expense_ids:
        manifest[str(expense_id)] = {
            'stored_name': receipt_metadata['stored_name'],
            'original_name': receipt_metadata['original_name'],
            'content_type': receipt_metadata['content_type']
        }
    _save_receipt_manifest(manifest)


def _get_receipt_for_expense(expense_id, manifest=None):
    loaded_manifest = manifest or _load_receipt_manifest()
    return loaded_manifest.get(str(expense_id))


def _build_expense_response(expense):
    return {
        "id": expense.id,
        "user_id": expense.user_id,
        "user_name": expense.user.full_name if expense.user else 'N/A',
        "category_id": expense.category_id,
        "category_name": expense.category.name if expense.category else None,
        "amount": float(expense.amount),
        "payment_method": expense.payment_method,
        "card_id": expense.card_id,
        "bank_account_id": expense.bank_account_id,
        "expense_date": expense.expense_date.strftime('%Y-%m-%d'),
        "description": expense.description,
        "created_at": expense.created_at.isoformat() if expense.created_at else None
    }


def _build_group_key(expense):
    created_at = expense.created_at.isoformat() if expense.created_at else ''
    return '|'.join([
        str(expense.user_id),
        expense.expense_date.strftime('%Y-%m-%d'),
        expense.payment_method or '',
        expense.description or '',
        created_at[:19]
    ])


def _apply_payment_effect(payment_method, total_amount, card_id=None, bank_account_id=None, sign=1):
    amount_delta = Decimal(str(total_amount))

    if payment_method == 'Tarjeta Crédito' and card_id:
        card = db.session.get(Card, card_id)
        if card:
            card.current_debt += sign * amount_delta
            card.available_balance = max(
                Decimal('0.00'),
                Decimal(str(card.credit_limit or 0)) - Decimal(str(card.current_debt or 0)),
            )
        return

    if payment_method == 'Tarjeta Débito' and card_id:
        card = db.session.get(Card, card_id)
        if card:
            card.available_balance -= sign * amount_delta
        return

    if payment_method == 'Banca Móvil' and bank_account_id:
        account = db.session.get(BankAccount, bank_account_id)
        if account:
            account.current_balance -= sign * amount_delta


def _load_group_expenses(base_expense):
    if not base_expense:
        return []

    group_key = _build_group_key(base_expense)
    candidate_expenses = Expense.query.options(
        joinedload(Expense.user),
        joinedload(Expense.category)
    ).filter_by(user_id=base_expense.user_id).all()

    return [expense for expense in candidate_expenses if _build_group_key(expense) == group_key]


def _group_expenses(expenses):
    receipt_manifest = _load_receipt_manifest()
    grouped = {}

    for expense in expenses:
        created_at = expense.created_at.isoformat() if expense.created_at else ''
        group_key = _build_group_key(expense)

        if group_key not in grouped:
            grouped[group_key] = {
                "id": expense.id,
                "user_id": expense.user_id,
                "user_name": expense.user.full_name if expense.user else 'N/A',
                "description": expense.description,
                "payment_method": expense.payment_method,
                "card_id": expense.card_id,
                "bank_account_id": expense.bank_account_id,
                "expense_date": expense.expense_date.strftime('%Y-%m-%d'),
                "total_amount": 0.0,
                "category_name": None,
                "categories_summary": [],
                "items": [],
                "created_at": created_at,
                "card_name": expense.card.card_name if expense.card else None,
                "bank_account_name": f"{expense.bank_account.bank.name} - {expense.bank_account.account_number}"
                if expense.bank_account and expense.bank_account.bank else None,
                "receipt": None
            }

        grouped_item = grouped[group_key]
        receipt = _get_receipt_for_expense(expense.id, receipt_manifest)
        grouped_item["items"].append({
            "id": expense.id,
            "category_id": expense.category_id,
            "category_name": expense.category.name if expense.category else None,
            "amount": float(expense.amount),
            "receipt": receipt
        })
        grouped_item["total_amount"] += float(expense.amount)
        if grouped_item["receipt"] is None and receipt is not None:
            grouped_item["receipt"] = {
                "expense_id": expense.id,
                "original_name": receipt["original_name"],
                "content_type": receipt.get("content_type")
            }

    grouped_expenses = []
    for item in grouped.values():
        category_names = [line["category_name"] for line in item["items"] if line["category_name"]]
        item["categories_summary"] = category_names
        if len(category_names) == 1:
            item["category_name"] = category_names[0]
        elif len(category_names) > 1:
            item["category_name"] = 'Gasto compuesto'
        grouped_expenses.append(item)

    grouped_expenses.sort(
        key=lambda item: (item["expense_date"], item["created_at"] or ''),
        reverse=True
    )
    return grouped_expenses

# --- Rutas para Categorías ---

@expenses_bp.route('/categories', methods=['GET'])
@jwt_required()
def get_categories():
    categories = Category.query.all()
    return jsonify([{
        "id": c.id,
        "name": c.name,
        "icon": c.icon
    } for c in categories]), 200


@expenses_bp.route('/analyze-receipt', methods=['POST'])
@jwt_required()
def analyze_receipt():
    receipt_file = request.files.get('receipt')
    if not receipt_file or not receipt_file.filename:
        return jsonify({"msg": "Debes subir un comprobante"}), 400

    try:
        categories = Category.query.order_by(Category.name.asc()).all()
        analysis = _analyze_receipt_file(receipt_file, categories)
        return jsonify(analysis), 200
    except ValueError as error:
        return jsonify({"msg": str(error)}), 400

# --- Rutas para Gastos Diarios ---

@expenses_bp.route('/', methods=['GET'])
@jwt_required()
def get_expenses():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    
    # Si es admin, ver todos. Si no, solo los propios.
    if user.role == 'admin':
        expenses = Expense.query.options(
            joinedload(Expense.user),
            joinedload(Expense.category)
        ).order_by(Expense.expense_date.desc()).all()
    else:
        expenses = Expense.query.options(
            joinedload(Expense.user),
            joinedload(Expense.category)
        ).filter_by(user_id=user_id).order_by(Expense.expense_date.desc()).all()
        
    return jsonify(_group_expenses(expenses)), 200

@expenses_bp.route('/', methods=['POST'])
@jwt_required()
def create_expense():
    user_id = int(get_jwt_identity())
    receipt_file = None

    if request.content_type and request.content_type.startswith('multipart/form-data'):
        payload = request.form.get('payload')
        if not payload:
            return jsonify({"msg": "Missing payload"}), 400
        data = json.loads(payload)
        receipt_file = request.files.get('receipt')
    else:
        data = request.get_json() or {}

    items = data.get('items')

    required_fields = ['payment_method', 'expense_date']
    if not all(k in data for k in required_fields):
        return jsonify({"msg": "Missing required fields"}), 400

    if receipt_file and receipt_file.filename:
        try:
            _validate_receipt_file(receipt_file)
        except ValueError as error:
            return jsonify({"msg": str(error)}), 400

    if items:
        normalized_items = items
    else:
        normalized_items = [{
            'category_id': data.get('category_id'),
            'amount': data.get('amount')
        }]

    if not normalized_items:
        return jsonify({"msg": "Debes agregar al menos una categoría"}), 400

    total_amount = 0.0
    expense_date = datetime.strptime(data['expense_date'], '%Y-%m-%d')
    created_expenses = []

    for item in normalized_items:
        category_id = item.get('category_id')
        amount = item.get('amount')

        if not category_id or amount in [None, '']:
            return jsonify({"msg": "Cada detalle del gasto necesita categoría y monto"}), 400

        amount_value = float(amount)
        if amount_value <= 0:
            return jsonify({"msg": "Los montos deben ser mayores a 0"}), 400

        total_amount += amount_value

        new_expense = Expense(
            user_id=user_id,
            category_id=category_id,
            amount=amount_value,
            payment_method=data['payment_method'],
            card_id=data.get('card_id'),
            bank_account_id=data.get('bank_account_id'),
            expense_date=expense_date,
            description=data.get('description')
        )
        db.session.add(new_expense)
        created_expenses.append(new_expense)

    _apply_payment_effect(
        data['payment_method'],
        total_amount,
        card_id=data.get('card_id'),
        bank_account_id=data.get('bank_account_id'),
        sign=1,
    )

    db.session.commit()

    if receipt_file and receipt_file.filename:
        try:
            receipt_metadata = _store_receipt_file(receipt_file)
            _link_receipt_to_expenses([expense.id for expense in created_expenses], receipt_metadata)
        except ValueError as error:
            return jsonify({"msg": str(error)}), 400

    return jsonify({"msg": "Expense registered successfully"}), 201


@expenses_bp.route('/<int:expense_id>', methods=['PUT'])
@jwt_required()
def update_expense(expense_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    base_expense = db.session.get(Expense, expense_id)

    if not base_expense:
        return jsonify({"msg": "Expense not found"}), 404

    if user.role != 'admin' and base_expense.user_id != user_id:
        return jsonify({"msg": "No autorizado para editar este gasto"}), 403

    data = request.get_json() or {}
    items = data.get('items') or []

    if not data.get('payment_method') or not data.get('expense_date'):
        return jsonify({"msg": "Missing required fields"}), 400

    if not items:
        return jsonify({"msg": "Debes agregar al menos una categoría"}), 400

    grouped_expenses = _load_group_expenses(base_expense)
    original_total = sum(float(expense.amount) for expense in grouped_expenses)
    _apply_payment_effect(
        base_expense.payment_method,
        original_total,
        card_id=base_expense.card_id,
        bank_account_id=base_expense.bank_account_id,
        sign=-1,
    )

    for expense in grouped_expenses:
        db.session.delete(expense)

    expense_date = datetime.strptime(data['expense_date'], '%Y-%m-%d')
    total_amount = 0.0
    created_expenses = []

    for item in items:
        category_id = item.get('category_id')
        amount = item.get('amount')

        if not category_id or amount in [None, '']:
            return jsonify({"msg": "Cada detalle del gasto necesita categoría y monto"}), 400

        amount_value = float(amount)
        if amount_value <= 0:
            return jsonify({"msg": "Los montos deben ser mayores a 0"}), 400

        total_amount += amount_value
        updated_expense = Expense(
            user_id=base_expense.user_id,
            category_id=category_id,
            amount=amount_value,
            payment_method=data['payment_method'],
            card_id=data.get('card_id'),
            bank_account_id=data.get('bank_account_id'),
            expense_date=expense_date,
            description=data.get('description'),
        )
        db.session.add(updated_expense)
        created_expenses.append(updated_expense)

    _apply_payment_effect(
        data['payment_method'],
        total_amount,
        card_id=data.get('card_id'),
        bank_account_id=data.get('bank_account_id'),
        sign=1,
    )

    receipt = _get_receipt_for_expense(expense_id)
    db.session.commit()

    if receipt:
        manifest = _load_receipt_manifest()
        for old_expense in grouped_expenses:
            manifest.pop(str(old_expense.id), None)
        for new_expense in created_expenses:
            manifest[str(new_expense.id)] = receipt
        _save_receipt_manifest(manifest)

    return jsonify({"msg": "Expense updated successfully"}), 200


@expenses_bp.route('/<int:expense_id>', methods=['DELETE'])
@jwt_required()
def delete_expense(expense_id):
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    base_expense = db.session.get(Expense, expense_id)

    if not base_expense:
        return jsonify({"msg": "Expense not found"}), 404

    if user.role != 'admin' and base_expense.user_id != user_id:
        return jsonify({"msg": "No autorizado para eliminar este gasto"}), 403

    grouped_expenses = _load_group_expenses(base_expense)
    total_amount = sum(float(expense.amount) for expense in grouped_expenses)
    _apply_payment_effect(
        base_expense.payment_method,
        total_amount,
        card_id=base_expense.card_id,
        bank_account_id=base_expense.bank_account_id,
        sign=-1,
    )

    manifest = _load_receipt_manifest()
    for expense in grouped_expenses:
        manifest.pop(str(expense.id), None)
        db.session.delete(expense)

    db.session.commit()
    _save_receipt_manifest(manifest)

    return jsonify({"msg": "Expense deleted successfully"}), 200


@expenses_bp.route('/<int:expense_id>/receipt', methods=['GET'])
@jwt_required()
def download_expense_receipt(expense_id):
    expense = db.session.get(Expense, expense_id)
    if not expense:
        return jsonify({"msg": "Expense not found"}), 404

    receipt = _get_receipt_for_expense(expense_id)
    if not receipt:
        return jsonify({"msg": "Receipt not found"}), 404

    file_path = os.path.join(current_app.config['UPLOAD_FOLDER'], receipt['stored_name'])
    if not os.path.exists(file_path):
        return jsonify({"msg": "Receipt file not found"}), 404

    return send_file(
        file_path,
        mimetype=receipt.get('content_type'),
        as_attachment=False,
        download_name=receipt.get('original_name')
    )
