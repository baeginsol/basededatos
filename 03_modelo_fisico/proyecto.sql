-- MODELO FISICO - HOTEL VIP DE CINCO ESTRELLAS
-- Base de datos: PostgreSQL

-- 1. TABLAS PRINCIPALES

CREATE TABLE people (
    person_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(60) NOT NULL,
    last_name VARCHAR(60) NOT NULL,
    document VARCHAR(20) NOT NULL UNIQUE,
    phone VARCHAR(20),
    email VARCHAR(100)
);

CREATE TABLE rooms (
    room_number VARCHAR(10) PRIMARY KEY,
    floor INTEGER NOT NULL,
    type VARCHAR(30) NOT NULL,
    price_per_night NUMERIC(10,2) NOT NULL
        CHECK (price_per_night > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'occupied', 'maintenance'))
);

CREATE TABLE services (
    service_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(60) NOT NULL UNIQUE,
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0)
);

-- 2. TABLAS DE ESPECIALIZACION

CREATE TABLE guests (
    person_id INTEGER PRIMARY KEY,
    nationality VARCHAR(40) NOT NULL,
    birth_date DATE NOT NULL,

    FOREIGN KEY (person_id)
        REFERENCES people(person_id)
        ON DELETE CASCADE
);

CREATE TABLE employees (
    person_id INTEGER PRIMARY KEY,
    position VARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL,

    FOREIGN KEY (person_id)
        REFERENCES people(person_id)
        ON DELETE CASCADE
);

-- CONTROL DE ESPECIALIZACION TOTAL Y DISJUNTA

CREATE OR REPLACE FUNCTION verificar_especializacion()
RETURNS TRIGGER AS $$
DECLARE
    v_person_id INTEGER;
    v_cantidad INTEGER;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_person_id := OLD.person_id;
    ELSE
        v_person_id := NEW.person_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM people
        WHERE person_id = v_person_id
    ) THEN
        RETURN NULL;
    END IF;

    SELECT COUNT(*) INTO v_cantidad
    FROM (
        SELECT person_id FROM guests
        WHERE person_id = v_person_id

        UNION ALL

        SELECT person_id FROM employees
        WHERE person_id = v_person_id
    ) AS subtipos;

    IF v_cantidad <> 1 THEN
        RAISE EXCEPTION
        'Cada persona debe pertenecer a un solo subtipo: HUESPED o EMPLEADO. Persona: %',
        v_person_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER comprobar_persona
AFTER INSERT OR UPDATE OR DELETE ON people
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION verificar_especializacion();

CREATE CONSTRAINT TRIGGER comprobar_huesped
AFTER INSERT OR UPDATE OR DELETE ON guests
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION verificar_especializacion();

CREATE CONSTRAINT TRIGGER comprobar_empleado
AFTER INSERT OR UPDATE OR DELETE ON employees
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION verificar_especializacion();

-- 3. TABLA DE RESERVAS

CREATE TABLE reservations (
    reservation_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reservation_date DATE NOT NULL DEFAULT CURRENT_DATE,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
    guest_id INTEGER NOT NULL,
    employee_id INTEGER NOT NULL,

    CHECK (check_out_date > check_in_date),

    FOREIGN KEY (guest_id)
        REFERENCES guests(person_id)
        ON DELETE RESTRICT,

    FOREIGN KEY (employee_id)
        REFERENCES employees(person_id)
        ON DELETE RESTRICT
);

-- 4. TABLAS DE FACTURACION Y PAGOS

CREATE TABLE invoices (
    invoice_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total NUMERIC(10,2) NOT NULL CHECK (total >= 0),
    reservation_id INTEGER NOT NULL UNIQUE,

    FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
        ON DELETE RESTRICT
);

CREATE TABLE payments (
    payment_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    method VARCHAR(30) NOT NULL,
    invoice_id INTEGER NOT NULL,

    FOREIGN KEY (invoice_id)
        REFERENCES invoices(invoice_id)
        ON DELETE RESTRICT
);

-- 5. TABLAS ASOCIATIVAS

CREATE TABLE reservation_rooms (
    reservation_id INTEGER NOT NULL,
    room_number VARCHAR(10) NOT NULL,

    PRIMARY KEY (reservation_id, room_number),

    FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
        ON DELETE CASCADE,

    FOREIGN KEY (room_number)
        REFERENCES rooms(room_number)
        ON DELETE RESTRICT
);

CREATE TABLE reservation_services (
    reservation_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    service_date DATE NOT NULL,

    PRIMARY KEY (reservation_id, service_id),

    FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
        ON DELETE CASCADE,

    FOREIGN KEY (service_id)
        REFERENCES services(service_id)
        ON DELETE RESTRICT
);

-- 6. CONTROL DE HABITACIONES OBLIGATORIAS POR RESERVA

CREATE OR REPLACE FUNCTION verificar_habitacion_reserva()
RETURNS TRIGGER AS $$
DECLARE
    v_reservation_id INTEGER;
    v_cantidad INTEGER;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_reservation_id := OLD.reservation_id;
    ELSE
        v_reservation_id := NEW.reservation_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM reservations
        WHERE reservation_id = v_reservation_id
    ) THEN

        SELECT COUNT(*) INTO v_cantidad
        FROM reservation_rooms
        WHERE reservation_id = v_reservation_id;

        IF v_cantidad = 0 THEN
            RAISE EXCEPTION
            'La reserva % debe tener al menos una habitacion asignada.',
            v_reservation_id;
        END IF;
    END IF;

    IF TG_OP = 'UPDATE'
       AND OLD.reservation_id <> NEW.reservation_id THEN

        IF EXISTS (
            SELECT 1 FROM reservations
            WHERE reservation_id = OLD.reservation_id
        ) THEN

            SELECT COUNT(*) INTO v_cantidad
            FROM reservation_rooms
            WHERE reservation_id = OLD.reservation_id;

            IF v_cantidad = 0 THEN
                RAISE EXCEPTION
                'La reserva % debe tener al menos una habitacion.',
                OLD.reservation_id;
            END IF;
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER comprobar_habitacion_reserva
AFTER INSERT OR UPDATE OR DELETE ON reservations
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION verificar_habitacion_reserva();

CREATE CONSTRAINT TRIGGER comprobar_habitacion_asignada
AFTER INSERT OR UPDATE OR DELETE ON reservation_rooms
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION verificar_habitacion_reserva();

-- 7. CONTROL DE FECHAS DE OCUPACION DE HABITACIONES

CREATE OR REPLACE FUNCTION verificar_disponibilidad_habitacion()
RETURNS TRIGGER AS $$
DECLARE
    v_reservation_id INTEGER;
    v_room_number VARCHAR(10);
    v_entrada DATE;
    v_salida DATE;
    v_estado VARCHAR(20);
BEGIN
    IF TG_TABLE_NAME = 'reservation_rooms' THEN

        v_reservation_id := NEW.reservation_id;
        v_room_number := NEW.room_number;

        SELECT check_in_date, check_out_date, status
        INTO v_entrada, v_salida, v_estado
        FROM reservations
        WHERE reservation_id = v_reservation_id;

        IF v_estado = 'cancelled' THEN
            RETURN NEW;
        END IF;

        IF EXISTS (
            SELECT 1
            FROM reservation_rooms rr
            INNER JOIN reservations r
                ON rr.reservation_id = r.reservation_id
            WHERE rr.room_number = v_room_number
              AND rr.reservation_id <> v_reservation_id
              AND r.status <> 'cancelled'
              AND daterange(r.check_in_date, r.check_out_date, '[)')
                  && daterange(v_entrada, v_salida, '[)')
        ) THEN
            RAISE EXCEPTION
            'La habitacion % ya esta asignada en esas fechas.',
            v_room_number;
        END IF;

        RETURN NEW;

    ELSE

        IF NEW.status = 'cancelled' THEN
            RETURN NEW;
        END IF;

        IF EXISTS (
            SELECT 1
            FROM reservation_rooms rr
            INNER JOIN reservation_rooms otras
                ON rr.room_number = otras.room_number
            INNER JOIN reservations r
                ON otras.reservation_id = r.reservation_id
            WHERE rr.reservation_id = NEW.reservation_id
              AND otras.reservation_id <> NEW.reservation_id
              AND r.status <> 'cancelled'
              AND daterange(r.check_in_date, r.check_out_date, '[)')
                  && daterange(NEW.check_in_date, NEW.check_out_date, '[)')
        ) THEN
            RAISE EXCEPTION
            'La habitacion ya tiene otra reserva en esas fechas.';
        END IF;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER controlar_fechas_habitacion
BEFORE INSERT OR UPDATE ON reservation_rooms
FOR EACH ROW
EXECUTE FUNCTION verificar_disponibilidad_habitacion();

CREATE TRIGGER controlar_fechas_reserva
BEFORE UPDATE OF check_in_date, check_out_date, status ON reservations
FOR EACH ROW
EXECUTE FUNCTION verificar_disponibilidad_habitacion();

-- 8. CONTROL DE PAGOS

CREATE OR REPLACE FUNCTION verificar_total_pagos()
RETURNS TRIGGER AS $$
DECLARE
    v_total_factura NUMERIC(10,2);
    v_total_pagado NUMERIC(10,2);
BEGIN
    SELECT total INTO v_total_factura
    FROM invoices
    WHERE invoice_id = NEW.invoice_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La factura indicada no existe.';
    END IF;

    SELECT COALESCE(SUM(amount), 0)
    INTO v_total_pagado
    FROM payments
    WHERE invoice_id = NEW.invoice_id
      AND payment_id IS DISTINCT FROM NEW.payment_id;

    IF v_total_pagado + NEW.amount > v_total_factura THEN
        RAISE EXCEPTION
        'El pago supera el total pendiente de la factura %.',
        NEW.invoice_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER controlar_pagos
BEFORE INSERT OR UPDATE ON payments
FOR EACH ROW
EXECUTE FUNCTION verificar_total_pagos();

-- 9. INSERCION DE DATOS DE PRUEBA

BEGIN;

-- PERSONAS

INSERT INTO people
(first_name, last_name, document, phone, email)
VALUES
('Carlos', 'Mendoza', '1001001', '70010001', 'carlos@gmail.com'),
('Maria', 'Lopez', '1001002', '70010002', 'maria@gmail.com'),
('Javier', 'Flores', '1001003', '70010003', 'javier@gmail.com'),
('Ana', 'Rojas', '1001004', '70010004', 'ana@gmail.com'),
('Luis', 'Fernandez', '1001005', '70010005', 'luis@gmail.com'),
('Pedro', 'Garcia', '2002001', '70020001', 'pedro@hotel.com'),
('Laura', 'Vargas', '2002002', '70020002', 'laura@hotel.com'),
('Miguel', 'Torrez', '2002003', '70020003', 'miguel@hotel.com'),
('Sofia', 'Cruz', '2002004', '70020004', 'sofia@hotel.com'),
('Diego', 'Castro', '2002005', '70020005', 'diego@hotel.com');

-- HUESPEDES

INSERT INTO guests
(person_id, nationality, birth_date)
SELECT person_id, 'Boliviana', DATE '1995-04-12'
FROM people WHERE document = '1001001';

INSERT INTO guests
(person_id, nationality, birth_date)
SELECT person_id, 'Boliviana', DATE '1998-08-20'
FROM people WHERE document = '1001002';

INSERT INTO guests
(person_id, nationality, birth_date)
SELECT person_id, 'Argentina', DATE '1990-02-15'
FROM people WHERE document = '1001003';

INSERT INTO guests
(person_id, nationality, birth_date)
SELECT person_id, 'Boliviana', DATE '1997-11-05'
FROM people WHERE document = '1001004';

INSERT INTO guests
(person_id, nationality, birth_date)
SELECT person_id, 'Peruana', DATE '1992-06-18'
FROM people WHERE document = '1001005';

-- EMPLEADOS

INSERT INTO employees
(person_id, position, hire_date)
SELECT person_id, 'Recepcionista', DATE '2024-01-10'
FROM people WHERE document = '2002001';

INSERT INTO employees
(person_id, position, hire_date)
SELECT person_id, 'Administradora', DATE '2023-05-15'
FROM people WHERE document = '2002002';

INSERT INTO employees
(person_id, position, hire_date)
SELECT person_id, 'Gerente', DATE '2022-03-20'
FROM people WHERE document = '2002003';

INSERT INTO employees
(person_id, position, hire_date)
SELECT person_id, 'Recepcionista', DATE '2025-02-01'
FROM people WHERE document = '2002004';

INSERT INTO employees
(person_id, position, hire_date)
SELECT person_id, 'Supervisor', DATE '2024-08-12'
FROM people WHERE document = '2002005';

-- HABITACIONES

INSERT INTO rooms
(room_number, floor, type, price_per_night, status)
VALUES
('101', 1, 'Simple', 350.00, 'available'),
('102', 1, 'Doble', 500.00, 'available'),
('103', 1, 'Suite', 900.00, 'available'),
('104', 2, 'Familiar', 700.00, 'available'),
('105', 2, 'Presidencial', 1500.00, 'available');

-- SERVICIOS

INSERT INTO services
(name, price)
VALUES
('Desayuno especial', 50.00),
('Spa', 150.00),
('Lavanderia', 40.00),
('Servicio a la habitacion', 60.00),
('Transporte privado', 100.00);

-- RESERVAS

INSERT INTO reservations
(reservation_date, check_in_date, check_out_date,
 status, guest_id, employee_id)
SELECT
    DATE '2026-11-19',
    datos.entrada,
    datos.salida,
    datos.estado,
    g.person_id,
    e.person_id
FROM (
    VALUES
    ('1001001', '2002001', DATE '2026-12-01', DATE '2026-12-03', 'confirmed'),
    ('1001002', '2002002', DATE '2026-12-10', DATE '2026-12-12', 'pending'),
    ('1001003', '2002003', DATE '2026-12-05', DATE '2026-12-07', 'confirmed'),
    ('1001004', '2002004', DATE '2026-12-15', DATE '2026-12-17', 'pending'),
    ('1001005', '2002005', DATE '2026-12-20', DATE '2026-12-22', 'confirmed')
) AS datos(documento_huesped, documento_empleado, entrada, salida, estado)
INNER JOIN people pg
    ON pg.document = datos.documento_huesped
INNER JOIN guests g
    ON g.person_id = pg.person_id
INNER JOIN people pe
    ON pe.document = datos.documento_empleado
INNER JOIN employees e
    ON e.person_id = pe.person_id;

-- ASIGNACION DE HABITACIONES

INSERT INTO reservation_rooms
(reservation_id, room_number)
VALUES
(1, '101'),
(2, '101'),
(3, '102'),
(4, '103'),
(5, '104');

-- SERVICIOS INCLUIDOS EN RESERVAS

INSERT INTO reservation_services
(reservation_id, service_id, quantity, service_date)
VALUES
(1, 1, 2, '2026-12-01'),
(1, 2, 1, '2026-12-02'),
(2, 1, 2, '2026-12-10'),
(2, 3, 1, '2026-12-11'),
(3, 2, 1, '2026-12-05'),
(3, 4, 2, '2026-12-06'),
(4, 3, 2, '2026-12-15'),
(4, 5, 1, '2026-12-16'),
(5, 1, 2, '2026-12-20'),
(5, 4, 1, '2026-12-21');

-- FACTURAS

INSERT INTO invoices
(issue_date, total, reservation_id)
VALUES
('2026-11-19', 1200.00, 1),
('2026-11-19', 950.00, 2),
('2026-11-19', 1500.00, 3),
('2026-11-19', 800.00, 4),
('2026-11-19', 1100.00, 5);

-- PAGOS

INSERT INTO payments
(payment_date, amount, method, invoice_id)
VALUES
('2026-11-19', 600.00, 'other', 1),
('2026-11-19', 950.00, 'other', 2),
('2026-11-19', 750.00, 'other', 3),
('2026-11-19', 400.00, 'other', 4),
('2026-11-19', 1100.00, 'other', 5);

COMMIT;

-- 10. COMPROBACION DE TABLAS

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- COMPROBACION DE COLUMNAS

SELECT
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

-- COMPROBACION DE REGISTROS

SELECT 'people' AS tabla, COUNT(*) AS registros FROM people
UNION ALL
SELECT 'guests', COUNT(*) FROM guests
UNION ALL
SELECT 'employees', COUNT(*) FROM employees
UNION ALL
SELECT 'rooms', COUNT(*) FROM rooms
UNION ALL
SELECT 'services', COUNT(*) FROM services
UNION ALL
SELECT 'reservations', COUNT(*) FROM reservations
UNION ALL
SELECT 'reservation_rooms', COUNT(*) FROM reservation_rooms
UNION ALL
SELECT 'reservation_services', COUNT(*) FROM reservation_services
UNION ALL
SELECT 'invoices', COUNT(*) FROM invoices
UNION ALL
SELECT 'payments', COUNT(*) FROM payments;

-- 11. CONSULTA 1: RESERVAS Y HABITACIONES

SELECT
    r.reservation_id,
    p.first_name || ' ' || p.last_name AS guest,
    e.first_name || ' ' || e.last_name AS employee,
    r.check_in_date,
    r.check_out_date,
    r.status,
    rr.room_number,
    rm.type AS room_type
FROM reservations r
INNER JOIN guests g
    ON r.guest_id = g.person_id
INNER JOIN people p
    ON g.person_id = p.person_id
INNER JOIN employees em
    ON r.employee_id = em.person_id
INNER JOIN people e
    ON em.person_id = e.person_id
INNER JOIN reservation_rooms rr
    ON r.reservation_id = rr.reservation_id
INNER JOIN rooms rm
    ON rr.room_number = rm.room_number
ORDER BY r.reservation_id;

-- 12. CONSULTA 2: SERVICIOS SOLICITADOS

SELECT
    r.reservation_id,
    s.name AS service,
    rs.quantity,
    rs.service_date,
    s.price
FROM reservation_services rs
INNER JOIN reservations r
    ON rs.reservation_id = r.reservation_id
INNER JOIN services s
    ON rs.service_id = s.service_id
ORDER BY r.reservation_id;

-- 13. CONSULTA 3: FACTURACION Y PAGOS PENDIENTES

SELECT
    i.invoice_id,
    i.reservation_id,
    i.issue_date,
    i.total AS invoice_total,
    COALESCE(SUM(p.amount), 0) AS total_paid,
    i.total - COALESCE(SUM(p.amount), 0) AS pending_amount
FROM invoices i
LEFT JOIN payments p
    ON i.invoice_id = p.invoice_id
GROUP BY
    i.invoice_id,
    i.reservation_id,
    i.issue_date,
    i.total
ORDER BY i.invoice_id;

-- 14. TRANSACCION CON ROLLBACK

BEGIN;

UPDATE rooms
SET price_per_night = price_per_night + 1
WHERE room_number = '101';

SELECT room_number, price_per_night
FROM rooms
WHERE room_number = '101';

ROLLBACK;

SELECT room_number, price_per_night
FROM rooms
WHERE room_number = '101';

-- 15. TRANSACCION DEL NEGOCIO CON COMMIT

BEGIN;

INSERT INTO payments
(payment_date, amount, method, invoice_id)
VALUES
(CURRENT_DATE, 600.00, 'cash', 1);

COMMIT;

-- COMPROBACION DEL PAGO

SELECT
    i.invoice_id,
    i.total AS invoice_total,
    COALESCE(SUM(p.amount), 0) AS total_paid,
    i.total - COALESCE(SUM(p.amount), 0) AS pending_amount
FROM invoices i
LEFT JOIN payments p
    ON i.invoice_id = p.invoice_id
WHERE i.invoice_id = 1
GROUP BY i.invoice_id, i.total;

-- 16. COMPROBACION DE RESTRICCIONES UNIQUE

SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'public'
AND table_name = 'invoices'
AND constraint_type = 'UNIQUE';