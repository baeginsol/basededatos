PASO DEL MODELO ENTIDAD-RELACIÓN AL MODELO RELACIONAL

Dominio: Hotel VIP de cinco estrellas

Pasooo a tablass

1. Entidades fuertes → una tabla

Cada entidad fuerte se convierte en una tabla y su identificador pasa a ser la clave primaria (PK)

people (
    person_id (PK),
    first_name,
    last_name,
    document,
    phone,
    email
)
rooms (
    room_number (PK),
    floor,
    type,
    price_per_night,
    status
)
services (
    service_id (PK),
    name,
    price
)
reservations (
    reservation_id (PK),
    reservation_date,
    check_in_date,
    check_out_date,
    status,
    guest_id (FK) → guests,
    employee_id (FK) → employees
)
invoices (
    invoice_id (PK),
    issue_date,
    total,
    reservation_id (FK, UNIQUE) → reservations
)
payments (
    payment_id (PK),
    payment_date,
    amount,
    method,
    invoice_id (FK) → invoices
)

1. Especialización → tablas relacionadas

La entidad PERSONA tiene dos tipos de personas que son HUESPED y EMPLEADO

Como cada persona pertenece a uno de estos dos tipos se crea una tabla principal llamada PEOPLE y una tabla para cada tipo

guests (
    person_id (PK, FK) → people,
    nationality,
    birth_date
)
employees (
    person_id (PK, FK) → people,
    position,
    hire_date
)

La clave primaria de cada subtipo también sirve como clave foránea y se relaciona con la tabla PEOPLE

1. Relaciones 1:N → clave foránea en el lado N

Las relaciones REALIZA y REGISTRA se representan usando claves foráneas en la tabla RESERVATIONS

* REALIZA: un huésped puede hacer varias reservas
* REGISTRA: un empleado puede registrar varias reservas

Por eso se agregan las siguientes claves

reservations (
    guest_id (FK) → guests,
    employee_id (FK) → employees
)

1. Relaciones N:M → tabla aparte

Las relaciones ASIGNA e INCLUYE necesitan sus propias tablas porque permiten relacionar varios registros de una tabla con varios de otra

Relación ASIGNA (RESERVATIONS – ROOMS)

reservation_rooms (
    reservation_id (PK, FK) → reservations,
    room_number (PK, FK) → rooms
)

La clave primaria se forma con las dos claves foráneas

Relación INCLUYE (RESERVATIONS – SERVICES)

reservation_services (
    reservation_id (PK, FK) → reservations,
    service_id (PK, FK) → services,
    quantity,
    service_date
)

Esta tabla permite guardar los servicios que se utilizan en cada reserva indicando también la cantidad y la fecha

1. Relaciones 1:1 opcional y 1:N opcional

Relación EMITE (RESERVATIONS – INVOICES)

Se representa colocando reservation_id en la tabla INVOICES

Esta clave es foránea y también tiene UNIQUE para evitar que una misma reserva tenga más de una factura

Relación RECIBE (INVOICES – PAYMENTS)

Se representa colocando invoice_id en la tabla PAYMENTS

Una factura puede tener varios pagos y cada pago corresponde a una sola factura

⸻

Resultado: El modelo relacional está formado por las tablas PEOPLE, GUESTS, EMPLOYEES, RESERVATIONS, ROOMS, SERVICES, INVOICES, PAYMENTS, RESERVATION_ROOMS y RESERVATION_SERVICES