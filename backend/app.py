import time

from flask import Flask, g, jsonify, request
from flask_cors import CORS
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager

try:
    from backend.config import Config
    from backend.models import db
except ModuleNotFoundError:
    from config import Config
    from models import db

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    # Inicializar extensiones
    db.init_app(app)
    Migrate(app, db)
    CORS(app, resources={r"/api/*": {"origins": "*"}}, supports_credentials=True)
    jwt = JWTManager(app)

    @jwt.invalid_token_loader
    def invalid_token_callback(error):
        return jsonify({
            'msg': 'Invalid token',
            'error': error
        }), 422

    @jwt.unauthorized_loader
    def missing_token_callback(error):
        return jsonify({
            'msg': 'Missing token',
            'error': error
        }), 401

    # Registro de Blueprints (Rutas)
    try:
        from backend.routes.auth import auth_bp
        from backend.routes.banks import banks_bp
        from backend.routes.expenses import expenses_bp
        from backend.routes.cards_loans import cards_loans_bp
        from backend.routes.assets_income import assets_income_bp
        from backend.routes.planning import planning_bp
        from backend.routes.debtors import debtors_bp
        from backend.routes.family import family_bp
        from backend.routes.dashboard import dashboard_bp
        from backend.routes.investments import investments_bp
    except ModuleNotFoundError:
        from routes.auth import auth_bp
        from routes.banks import banks_bp
        from routes.expenses import expenses_bp
        from routes.cards_loans import cards_loans_bp
        from routes.assets_income import assets_income_bp
        from routes.planning import planning_bp
        from routes.debtors import debtors_bp
        from routes.family import family_bp
        from routes.dashboard import dashboard_bp
        from routes.investments import investments_bp
    
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(banks_bp, url_prefix='/api/banks')
    app.register_blueprint(expenses_bp, url_prefix='/api/expenses')
    app.register_blueprint(cards_loans_bp, url_prefix='/api/cards_loans')
    app.register_blueprint(assets_income_bp, url_prefix='/api/assets_income')
    app.register_blueprint(planning_bp, url_prefix='/api/planning')
    app.register_blueprint(debtors_bp, url_prefix='/api/debtors')
    app.register_blueprint(family_bp, url_prefix='/api/family')
    app.register_blueprint(dashboard_bp, url_prefix='/api/dashboard')
    app.register_blueprint(investments_bp, url_prefix='/api/investments')

    @app.route('/health', methods=['GET'])
    def health_check():
        return jsonify({"status": "healthy", "message": "Backend is running"}), 200

    @app.before_request
    def start_request_timer():
        g.request_start_time = time.perf_counter()

    @app.after_request
    def log_request_duration(response):
        start_time = getattr(g, 'request_start_time', None)
        if start_time is not None:
            elapsed_ms = (time.perf_counter() - start_time) * 1000
            print(f"{request.method} {request.path} -> {response.status_code} [{elapsed_ms:.2f} ms]")
        return response

    return app

app = create_app()
from a2wsgi import WSGIMiddleware
asgi_app = WSGIMiddleware(app)

if __name__ == '__main__':
    app.run(debug=True, port=5000)
