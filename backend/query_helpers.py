from datetime import datetime

from flask import request
from sqlalchemy import func, or_

DATE_FMT = '%Y-%m-%d'


def parse_date(value):
    if not value:
        return None
    try:
        return datetime.strptime(value, DATE_FMT).date()
    except (TypeError, ValueError):
        return None


def apply_date_range(query, column, from_key='from', to_key='to'):
    start = parse_date(request.args.get(from_key))
    if start:
        query = query.filter(column >= start)
    end = parse_date(request.args.get(to_key))
    if end:
        query = query.filter(column <= end)
    return query


def apply_search(query, *columns):
    term = (request.args.get('search') or '').strip()
    if not term or not columns:
        return query
    needle = f'%{term.lower()}%'
    return query.filter(or_(*[func.lower(column).like(needle) for column in columns]))


def int_param(name, default=None):
    raw = request.args.get(name)
    if raw in (None, ''):
        return default
    try:
        return int(raw)
    except (TypeError, ValueError):
        return default


def paginate_or_plain(query, serializer):
    page_raw = request.args.get('page')
    if page_raw in (None, ''):
        return serializer(query.all()), None
    try:
        page = max(int(page_raw), 1)
    except (TypeError, ValueError):
        page = 1
    per_page = min(max(int_param('per_page', 25) or 25, 1), 200)
    pagination = query.paginate(page=page, per_page=per_page, error_out=False)
    return serializer(pagination.items), {
        "page": pagination.page,
        "per_page": pagination.per_page,
        "total": pagination.total,
        "pages": pagination.pages,
    }