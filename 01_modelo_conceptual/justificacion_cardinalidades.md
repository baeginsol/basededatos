JUSTIFICACIÓN DE LAS CARDINALIDADES Y REGLAS DE NEGOCIO DE MI PROYECTO :v

Dominio: Hotel VIP de cinco estrellas

1. Relación REALIZA (HUESPED – RESERVA)

Cardinalidad: 1:N

Regla de negocio: Un huésped puede realizar varias reservas pero cada reserva pertenece a un solo huésped.

Justificación: Un huésped puede visitar el hotel en diferentes ocasiones y hacer nuevas reservas. Sin embargo cada reserva debe estar asociada a una sola persona.

Participación: HUESPED parcial porque puede existir sin reservas. RESERVA total porque siempre debe pertenecer a un huésped.

2. Relación REGISTRA (EMPLEADO – RESERVA)

Cardinalidad: 1:N

Regla de negocio: Un empleado puede registrar varias reservas pero cada reserva debe ser registrada por un solo empleado.

Justificación: Un empleado puede registrar distintas reservas durante su jornada de trabajo pero cada reserva debe tener un empleado encargado.

Participación: EMPLEADO parcial porque puede existir sin registrar reservas. RESERVA total porque siempre debe ser registrada por un empleado.

3. Relación ASIGNA (RESERVA – HABITACION)

Cardinalidad: N:1

Regla de negocio: Cada reserva debe tener una sola habitación asignada pero una habitación puede utilizarse en diferentes reservas y fechas.

Justificación: Una habitación puede formar parte de varias reservas a lo largo del tiempo. Sin embargo no puede asignarse a dos reservas que coincidan en sus fechas de ocupación.

Participación: RESERVA total porque toda reserva debe tener una habitación. HABITACION parcial porque puede existir sin estar asignada.

4. Relación INCLUYE (RESERVA – SERVICIO)

Cardinalidad: N:M

Regla de negocio: Una reserva puede incluir varios servicios y un mismo servicio puede utilizarse en diferentes reservas.

Justificación: Los huéspedes pueden utilizar distintos servicios como restaurante lavandería o spa. Para llevar un mejor control se agregan los atributos cantidad y fecha_servicio.

Participación: RESERVA parcial porque puede existir sin servicios adicionales. SERVICIO parcial porque puede estar registrado sin ser solicitado.

5. Relación EMITE (RESERVA – FACTURA)

Cardinalidad: RESERVA (0..1) – FACTURA (1..1)

Regla de negocio: Una reserva puede tener como máximo una factura pero también puede existir sin ella. Cada factura pertenece a una sola reserva.

Justificación: Una reserva no necesita tener una factura desde el momento de su creación. La factura se genera cuando corresponde realizar la facturación.

Participación: RESERVA parcial porque puede existir sin factura. FACTURA total porque siempre debe pertenecer a una reserva.

6. Relación RECIBE (FACTURA – PAGO)

Cardinalidad: FACTURA (0..N) – PAGO (1..1)

Regla de negocio: Una factura puede recibir varios pagos o no tener ninguno mientras esté pendiente. Cada pago pertenece a una sola factura.

Justificación: El huésped puede pagar una factura en varias partes mediante pagos parciales. También puede existir una factura sin pagos registrados.

Participación: FACTURA parcial porque puede existir sin pagos. PAGO total porque siempre debe estar relacionado con una factura.

7. Jerarquía PERSONA – HUESPED / EMPLEADO

Tipo de especialización: Total y disjunta (d)

Regla de negocio: Toda persona registrada debe ser HUESPED o EMPLEADO pero no puede pertenecer a ambas categorías al mismo tiempo.

Justificación: La especialización es total porque toda persona debe pertenecer a una categoría y es disjunta porque no puede pertenecer a las dos al mismo tiempo. Cada categoría tiene sus propios atributos según su función dentro del hotel.