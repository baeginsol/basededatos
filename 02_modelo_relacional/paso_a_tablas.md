PASO DEL MODELO ENTIDAD-RELACIÓN AL MODELO RELACIONAL
Dominio: Hotel VIP de cinco estrellas
1. Transformación de entidades fuertes a tablas
Cada entidad fuerte del modelo Entidad-Relación se convierte en una tabla. Su identificador pasa a ser la clave primaria (PK) y sus atributos se convierten en columnas.
PEOPLE
Almacena los datos generales de las personas registradas en el hotel.
people (
    person_id (PK),
    first_name,
    last_name,
    document,
    phone,
    email
)
ROOMS
Almacena la información de las habitaciones.
rooms (
    room_number (PK),
    floor,
    type,
    price_per_night,
    status
)
SERVICES
Almacena los servicios que ofrece el hotel.
services (
    service_id (PK),
    name,
    price
)
RESERVATIONS
Almacena las reservas realizadas por los huéspedes.
reservations (
    reservation_id (PK),
    reservation_date,
    check_in_date,
    check_out_date,
    status,
    guest_id (FK) → guests,
    employee_id (FK) → employees
)
INVOICES
Almacena las facturas emitidas por las reservas.
invoices (
    invoice_id (PK),
    issue_date,
    total,
    reservation_id (FK, UNIQUE) → reservations
)
PAYMENTS
Registra los pagos realizados a las facturas.
payments (
    payment_id (PK),
    payment_date,
    amount,
    method,
    invoice_id (FK) → invoices
)
2. Transformación de la especialización
La entidad PERSONA tiene dos subtipos: HUESPED y EMPLEADO.
Como la especialización es total y disjunta, se crea una tabla principal llamada PEOPLE y una tabla para cada subtipo.
GUESTS
guests (
    person_id (PK, FK) → people,
    nationality,
    birth_date
)
EMPLOYEES
employees (
    person_id (PK, FK) → people,
    position,
    hire_date
)
La clave primaria de cada subtipo también funciona como clave foránea y se relaciona con la tabla PEOPLE.
De esta manera, los datos generales de las personas se almacenan una sola vez y se separa la información específica de los huéspedes y empleados.
3. Transformación de relaciones 1:N
Las relaciones 1:N se representan colocando la clave foránea en la tabla que se encuentra en el lado N.
REALIZA (GUESTS – RESERVATIONS)
Un huésped puede realizar varias reservas, pero cada reserva pertenece a un solo huésped.
Por eso se agrega guest_id como clave foránea en RESERVATIONS.
REGISTRA (EMPLOYEES – RESERVATIONS)
Un empleado puede registrar varias reservas, pero cada reserva es registrada por un solo empleado.
Por eso se agrega employee_id como clave foránea en RESERVATIONS.
Las dos claves foráneas se incluyen en la tabla:
reservations (
    guest_id (FK) → guests,
    employee_id (FK) → employees
)
4. Transformación de relaciones N:M
Las relaciones N:M necesitan una tabla asociativa para relacionar los registros de ambas entidades.
ASIGNA (RESERVATIONS – ROOMS)
Una reserva puede incluir una o varias habitaciones y una habitación puede aparecer en diferentes reservas, siempre que correspondan a períodos distintos.
Se crea la tabla:
reservation_rooms (
    reservation_id (PK, FK) → reservations,
    room_number (PK, FK) → rooms
)
La clave primaria se forma con las dos claves foráneas.
Esta tabla permite relacionar las reservas con las habitaciones correspondientes.
INCLUYE (RESERVATIONS – SERVICES)
Una reserva puede incluir diferentes servicios y un mismo servicio puede aparecer en distintas reservas.
Se crea la tabla:
reservation_services (
    reservation_id (PK, FK) → reservations,
    service_id (PK, FK) → services,
    quantity,
    service_date
)
La clave primaria se forma con las dos claves foráneas.
Los atributos quantity y service_date pertenecen a esta relación porque indican la cantidad del servicio solicitado y la fecha en que se utiliza.
Se estableció que un mismo servicio solamente puede aparecer una vez por reserva, por lo que se utiliza la combinación de ambas claves como identificador.
5. Transformación de relaciones 1:1 y 1:N
EMITE (RESERVATIONS – INVOICES)
Una reserva puede tener como máximo una factura, pero también puede existir sin factura mientras todavía no se haya realizado la facturación.
Se representa colocando reservation_id en INVOICES como clave foránea y agregando UNIQUE.
Esto evita que una misma reserva tenga más de una factura.
La clave foránea es obligatoria porque cada factura debe corresponder a una reserva.
RECIBE (INVOICES – PAYMENTS)
Una factura puede recibir varios pagos o ninguno si todavía está pendiente.
Cada pago corresponde a una sola factura.
Se representa colocando invoice_id como clave foránea en PAYMENTS.
6. Resultado del modelo relacional
El modelo relacional del Hotel VIP de cinco estrellas queda formado por las siguientes diez tablas:
1. PEOPLE
2. GUESTS
3. EMPLOYEES
4. RESERVATIONS
5. ROOMS
6. SERVICES
7. INVOICES
8. PAYMENTS
9. RESERVATION_ROOMS
10. RESERVATION_SERVICES
Estas tablas permiten organizar la información del hotel y representar las relaciones establecidas en el diagrama Entidad-Relación.
Conclusión
La transformación permite pasar del modelo conceptual al modelo relacional, identificando las claves primarias, claves foráneas y tablas asociativas necesarias para organizar la información del hotel.
Posteriormente, estas tablas se utilizaron como base para desarrollar el modelo físico en PostgreSQL.



NORMALIZACIÓN DEL MODELO RELACIONAL
Dominio: Hotel VIP de cinco estrellas
Introducción
La normalización es un proceso que permite organizar los datos de una base de datos para evitar repeticiones innecesarias y mantener la información correctamente relacionada.
Para el proyecto del Hotel VIP de cinco estrellas se revisaron las tres primeras formas normales: Primera Forma Normal (1FN), Segunda Forma Normal (2FN) y Tercera Forma Normal (3FN).
1. Primera Forma Normal (1FN)
Una tabla cumple con la Primera Forma Normal cuando cada columna contiene valores individuales y no existen grupos de datos repetidos dentro de una misma fila.
En nuestro modelo se cumple esta condición porque cada atributo almacena un solo valor.
Por ejemplo, en la tabla PEOPLE los nombres, apellidos, documentos, teléfonos y correos se encuentran separados en diferentes columnas.
También se utilizan tablas asociativas para almacenar las habitaciones y servicios relacionados con cada reserva.
De esta manera, cada dato se registra de forma individual.
Resultado: las tablas del modelo cumplen con la Primera Forma Normal.
2. Segunda Forma Normal (2FN)
Una tabla cumple con la Segunda Forma Normal cuando primero cumple con la 1FN y todos sus atributos que no forman parte de la clave primaria dependen de la clave primaria completa.
En nuestro modelo, las tablas que tienen una sola columna como clave primaria no presentan dependencias parciales.
En las tablas asociativas se revisa la dependencia de sus atributos respecto a la clave compuesta.
Por ejemplo, en RESERVATION_SERVICES la clave primaria está formada por:
* reservation_id
* service_id
Los atributos quantity y service_date dependen de la combinación de ambas claves, porque representan la cantidad y la fecha de utilización de un servicio dentro de una reserva.
En RESERVATION_ROOMS no existen atributos adicionales que dependan parcialmente de una sola parte de la clave.
Resultado: las tablas cumplen con la Segunda Forma Normal.
3. Tercera Forma Normal (3FN)
Una tabla cumple con la Tercera Forma Normal cuando primero cumple con la 2FN y sus atributos que no forman parte de la clave primaria no dependen de otros atributos que tampoco sean claves.
En nuestro modelo, la información se encuentra separada según su función.
Por ejemplo:
* PEOPLE almacena los datos generales de las personas.
* GUESTS almacena los datos específicos de los huéspedes.
* EMPLOYEES almacena los datos específicos de los empleados.
* ROOMS almacena la información de las habitaciones.
* SERVICES almacena los servicios y sus precios.
* RESERVATIONS almacena la información de las reservas.
* INVOICES almacena los datos de las facturas.
* PAYMENTS almacena los datos de los pagos.
Esta separación permite evitar repetir información que pertenece a otras tablas.
Por ejemplo, los datos generales de una persona no necesitan repetirse en cada reserva, ya que se encuentran almacenados en PEOPLE y se relacionan mediante claves foráneas.
Resultado: el modelo relacional cumple con la Tercera Forma Normal.
4. Dependencias funcionales
Las dependencias funcionales permiten identificar cómo un atributo determina el valor de otros atributos dentro de una tabla.
En nuestro proyecto se pueden observar los siguientes ejemplos:
Tabla PEOPLE
La clave primaria person_id determina los demás datos de la persona.
person_id → first_name, last_name, document, phone, email
Además, como document tiene una restricción UNIQUE, también permite identificar a una persona.
Tabla ROOMS
El número de habitación determina sus características y su información.
room_number → floor, type, price_per_night, status
Tabla RESERVATION_SERVICES
La combinación de reservation_id y service_id determina la cantidad y la fecha del servicio solicitado.
(reservation_id, service_id) → quantity, service_date
Estas dependencias muestran que los atributos dependen de sus respectivas claves y permiten justificar la organización de las tablas.
5. Resultado de la normalización
Después de revisar las tres formas normales, se obtuvo una estructura organizada en diez tablas relacionadas.
La información se encuentra separada según su función y las tablas asociativas permiten representar las relaciones entre reservas, habitaciones y servicios.
De esta manera, se reduce la repetición innecesaria de datos y se facilita el mantenimiento de la información.        
