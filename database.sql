-- Esquema de Base de Datos para Control de Finanzas Familiar
-- Motor: PostgreSQL

-- 1. Tabla de Usuarios
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'member', -- 'admin' o 'member'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 1.1 Tabla de Miembros de la Familia (Para asignar a cuentas/bienes)
CREATE TABLE IF NOT EXISTS family_members (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    relationship VARCHAR(50), -- 'Esposa', 'Hijo/a', 'Yo', etc.
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tabla de Bancos / Cooperativas
CREATE TABLE IF NOT EXISTS banks (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Tabla de Cuentas Bancarias
CREATE TABLE IF NOT EXISTS bank_accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    bank_id INTEGER REFERENCES banks(id) ON DELETE CASCADE,
    account_number VARCHAR(50),
    account_type VARCHAR(50), -- 'Ahorros', 'Corriente', etc.
    owner VARCHAR(100), -- Ej: Yo, Esposa, Hija, etc.
    current_balance DECIMAL(15, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Tabla de Tarjetas (Crédito y Débito)
CREATE TABLE IF NOT EXISTS cards (
    id SERIAL PRIMARY KEY,
    bank_id INTEGER REFERENCES banks(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    card_name VARCHAR(100), -- Ej: Visa Oro, Mastercard Black
    owner VARCHAR(100), -- Ej: Yo, Esposa, etc.
    last_four_digits VARCHAR(4),
    card_type VARCHAR(20), -- 'Crédito' o 'Débito'
    credit_limit DECIMAL(15, 2) DEFAULT 0.00, -- Solo para crédito
    current_debt DECIMAL(15, 2) DEFAULT 0.00,  -- Solo para crédito
    available_balance DECIMAL(15, 2) DEFAULT 0.00, -- Para débito (vinculado a cuenta)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Tabla de Préstamos
CREATE TABLE IF NOT EXISTS loans (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    bank_id INTEGER REFERENCES banks(id) ON DELETE SET NULL,
    description VARCHAR(255) NOT NULL,
    owner VARCHAR(100), -- Ej: Yo, Esposa, etc.
    initial_amount DECIMAL(15, 2) NOT NULL,
    total_installments INTEGER NOT NULL,
    pending_installments INTEGER NOT NULL,
    monthly_payment DECIMAL(15, 2) NOT NULL,
    interest_rate DECIMAL(5, 2),
    start_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. Tabla de Inventario de Bienes
CREATE TABLE IF NOT EXISTS assets (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    value DECIMAL(15, 2) NOT NULL,
    owner VARCHAR(100), -- Ej: Yo, Esposa, Hija, etc.
    description TEXT,
    purchase_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6.1 Tabla de Inversiones
CREATE TABLE IF NOT EXISTS investments (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    institution VARCHAR(120) NOT NULL,
    investment_type VARCHAR(50) NOT NULL, -- 'Cooperativa', 'Seguro', 'Negocio', etc.
    title VARCHAR(150) NOT NULL,
    owner VARCHAR(100),
    invested_amount DECIMAL(15, 2) NOT NULL,
    current_value DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    expected_return_rate DECIMAL(5, 2),
    start_date DATE,
    end_date DATE,
    status VARCHAR(30) DEFAULT 'activa',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. Tabla de Categorías de Gastos
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    icon VARCHAR(50), -- Para el frontend
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. Tabla de Planificación de Gastos Mensuales
CREATE TABLE IF NOT EXISTS monthly_planning (
    id SERIAL PRIMARY KEY,
    category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
    planned_amount DECIMAL(15, 2) NOT NULL,
    month INTEGER NOT NULL, -- 1 a 12
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9. Tabla de Ingresos / Sueldos
CREATE TABLE IF NOT EXISTS income (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(15, 2) NOT NULL,
    source VARCHAR(100) NOT NULL, -- Ej: Sueldo, Venta, etc.
    income_date DATE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 10. Tabla de Deudores (Personas que nos deben dinero)
CREATE TABLE IF NOT EXISTS debtors (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    amount_owed DECIMAL(15, 2) NOT NULL,
    description TEXT,
    due_date DATE,
    status VARCHAR(20) DEFAULT 'pendiente', -- 'pendiente', 'pagado'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 10.1 Tabla de Deudas Pequeñas (Dinero que debemos a amigos, familiares, etc.)
CREATE TABLE IF NOT EXISTS small_debts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    lender_name VARCHAR(100) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    description TEXT,
    borrowed_date DATE,
    due_date DATE,
    status VARCHAR(20) DEFAULT 'pendiente',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 11. Tabla de Gastos Diarios
CREATE TABLE IF NOT EXISTS expenses (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    amount DECIMAL(15, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL, -- 'Tarjeta Crédito', 'Tarjeta Débito', 'Banca Móvil', 'Efectivo', 'Fiado'
    card_id INTEGER REFERENCES cards(id) ON DELETE SET NULL,
    bank_account_id INTEGER REFERENCES bank_accounts(id) ON DELETE SET NULL,
    expense_date DATE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertar categorías por defecto
INSERT INTO categories (name, icon) VALUES 
('Alimentos', 'food'),
('Medicina', 'health'),
('Vivienda', 'home'),
('Transporte', 'car'),
('Educación', 'school'),
('Entretenimiento', 'gamepad'),
('Servicios Básicos', 'bolt'),
('Otros', 'plus')
ON CONFLICT (name) DO NOTHING;
