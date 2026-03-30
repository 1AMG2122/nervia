-- ============================================================
--  NERVIA — Esquema de Base de Datos MariaDB
--  Versión 1.0 | 2026
--  Ejecutar como: mysql -u root -p < nervia_schema.sql
-- ============================================================

CREATE DATABASE IF NOT EXISTS nervia
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE nervia;

-- ============================================================
-- PLANES DE SUSCRIPCIÓN
-- ============================================================

CREATE TABLE planes (
  id            TINYINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  nombre        VARCHAR(50)        NOT NULL,          -- 'Base', 'Pro'
  canal         ENUM('telegram','whatsapp') NOT NULL, -- canal del agente IA
  precio_mes    DECIMAL(8,2)       NOT NULL,          -- 29.00 / 49.00
  precio_setup  DECIMAL(8,2)       NOT NULL DEFAULT 180.00,
  activo        TINYINT(1)         NOT NULL DEFAULT 1,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

INSERT INTO planes (nombre, canal, precio_mes, precio_setup) VALUES
  ('Base', 'telegram', 29.00, 180.00),
  ('Pro',  'whatsapp', 49.00, 180.00);

-- ============================================================
-- CLIENTES (profesionales / clínicas)
-- ============================================================

CREATE TABLE clientes (
  id              INT UNSIGNED       NOT NULL AUTO_INCREMENT,
  slug            VARCHAR(60)        NOT NULL UNIQUE,   -- 'fisio-garcia'
  nombre          VARCHAR(120)       NOT NULL,          -- 'Dr. García Fernández'
  especialidad    VARCHAR(80)        NOT NULL,          -- 'Fisioterapeuta'
  email           VARCHAR(180)       NOT NULL UNIQUE,
  telefono        VARCHAR(20)        NULL,
  direccion       TEXT               NULL,
  ciudad          VARCHAR(80)        NULL,
  color_hex       CHAR(7)            NOT NULL DEFAULT '#25d366',
  logo_url        VARCHAR(255)       NULL,
  plan_id         TINYINT UNSIGNED   NOT NULL,
  estado          ENUM('activo','suspendido','prueba','cancelado')
                                     NOT NULL DEFAULT 'prueba',
  fecha_alta      DATE               NOT NULL DEFAULT (CURRENT_DATE),
  fecha_renovacion DATE              NULL,
  -- Google Calendar
  calendar_id     VARCHAR(200)       NULL,
  -- WhatsApp / Telegram
  bot_token       VARCHAR(255)       NULL,
  wa_phone_id     VARCHAR(100)       NULL,
  wa_token        TEXT               NULL,
  -- Webhook n8n
  webhook_booking VARCHAR(255)       NULL,
  webhook_agente  VARCHAR(255)       NULL,
  -- Notas internas (solo para el equipo Nervia)
  notas_internas  TEXT               NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_clientes_plan FOREIGN KEY (plan_id) REFERENCES planes(id)
) ENGINE=InnoDB;

-- ============================================================
-- SERVICIOS (por cliente)
-- ============================================================

CREATE TABLE servicios (
  id          INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  cliente_id  INT UNSIGNED      NOT NULL,
  nombre      VARCHAR(120)      NOT NULL,      -- 'Primera consulta'
  duracion    SMALLINT UNSIGNED NOT NULL,      -- minutos: 30, 45, 60
  precio      DECIMAL(8,2)      NULL,
  icono       VARCHAR(10)       NULL DEFAULT '🩺',
  activo      TINYINT(1)        NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  CONSTRAINT fk_servicios_cliente FOREIGN KEY (cliente_id)
    REFERENCES clientes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- DISPONIBILIDAD (horarios semanales por cliente)
-- ============================================================

CREATE TABLE disponibilidad (
  id          INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  cliente_id  INT UNSIGNED      NOT NULL,
  dia_semana  TINYINT UNSIGNED  NOT NULL,   -- 1=Lun, 2=Mar … 7=Dom
  hora_inicio TIME              NOT NULL,   -- '09:00:00'
  hora_fin    TIME              NOT NULL,   -- '09:30:00'
  activo      TINYINT(1)        NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  CONSTRAINT fk_disponibilidad_cliente FOREIGN KEY (cliente_id)
    REFERENCES clientes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- PACIENTES
-- ============================================================

CREATE TABLE pacientes (
  id              INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  cliente_id      INT UNSIGNED  NOT NULL,   -- a qué clínica pertenece
  nombre          VARCHAR(120)  NOT NULL,
  email           VARCHAR(180)  NULL,
  telefono        VARCHAR(25)   NULL,
  canal_contacto  ENUM('whatsapp','telegram','web','presencial')
                                NOT NULL DEFAULT 'web',
  -- RGPD
  consentimiento_rgpd   TINYINT(1)   NOT NULL DEFAULT 0,
  fecha_consentimiento  DATETIME     NULL,
  fecha_creacion        DATETIME     NOT NULL DEFAULT NOW(),
  notas                 TEXT         NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_pacientes_cliente FOREIGN KEY (cliente_id)
    REFERENCES clientes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Unique por clínica + teléfono → permite ON DUPLICATE KEY UPDATE en el workflow de reservas
CREATE UNIQUE INDEX uq_paciente_telefono ON pacientes(cliente_id, telefono);
-- Índice secundario por email
CREATE INDEX idx_pacientes_email    ON pacientes(cliente_id, email);

-- ============================================================
-- CITAS
-- ============================================================

CREATE TABLE citas (
  id              INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  cliente_id      INT UNSIGNED   NOT NULL,
  paciente_id     INT UNSIGNED   NOT NULL,
  servicio_id     INT UNSIGNED   NULL,
  fecha           DATE           NOT NULL,
  hora_inicio     TIME           NOT NULL,
  hora_fin        TIME           NOT NULL,
  estado          ENUM('pendiente','confirmada','cancelada','completada','no_show')
                                 NOT NULL DEFAULT 'pendiente',
  origen          ENUM('web','whatsapp','telegram','telefono','manual')
                                 NOT NULL DEFAULT 'web',
  -- Confirmaciones y recordatorios
  recordatorio_enviado  TINYINT(1)  NOT NULL DEFAULT 0,
  confirmada_paciente   TINYINT(1)  NOT NULL DEFAULT 0,
  -- Google Calendar
  gcal_event_id   VARCHAR(200)   NULL,
  -- Datos extra (payload JSON del booking)
  meta            JSON           NULL,
  notas           TEXT           NULL,
  creado_en       DATETIME       NOT NULL DEFAULT NOW(),
  actualizado_en  DATETIME       NOT NULL DEFAULT NOW()
                                 ON UPDATE NOW(),
  PRIMARY KEY (id),
  CONSTRAINT fk_citas_cliente   FOREIGN KEY (cliente_id)   REFERENCES clientes(id),
  CONSTRAINT fk_citas_paciente  FOREIGN KEY (paciente_id)  REFERENCES pacientes(id),
  CONSTRAINT fk_citas_servicio  FOREIGN KEY (servicio_id)  REFERENCES servicios(id)
                                ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE INDEX idx_citas_fecha        ON citas(cliente_id, fecha);
CREATE INDEX idx_citas_estado       ON citas(estado);
CREATE INDEX idx_citas_paciente     ON citas(paciente_id);

-- ============================================================
-- CONVERSACIONES (sesiones de chat con el agente IA)
-- ============================================================

CREATE TABLE conversaciones (
  id              BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  cliente_id      INT UNSIGNED     NOT NULL,
  paciente_id     INT UNSIGNED     NULL,   -- NULL si aún no identificado
  canal           ENUM('whatsapp','telegram') NOT NULL,
  -- ID externo de la plataforma (chat_id de Telegram, número WA, etc.)
  canal_id        VARCHAR(100)     NOT NULL,
  iniciada_en     DATETIME         NOT NULL DEFAULT NOW(),
  ultima_actividad DATETIME        NOT NULL DEFAULT NOW(),
  estado          ENUM('activa','cerrada','escalada') NOT NULL DEFAULT 'activa',
  cita_generada   TINYINT(1)       NOT NULL DEFAULT 0,
  cita_id         INT UNSIGNED     NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_conv_cliente  FOREIGN KEY (cliente_id)  REFERENCES clientes(id),
  CONSTRAINT fk_conv_paciente FOREIGN KEY (paciente_id) REFERENCES pacientes(id)
                               ON DELETE SET NULL,
  CONSTRAINT fk_conv_cita     FOREIGN KEY (cita_id)     REFERENCES citas(id)
                               ON DELETE SET NULL
) ENGINE=InnoDB;

-- Permite el INSERT ... WHERE NOT EXISTS + SELECT en un solo ciclo por sesión activa
CREATE INDEX idx_conv_canal_id    ON conversaciones(canal, canal_id);
CREATE INDEX idx_conv_activa      ON conversaciones(cliente_id, canal, canal_id, estado, ultima_actividad);

-- ============================================================
-- MENSAJES (historial detallado de cada conversación)
-- ============================================================

CREATE TABLE mensajes (
  id                BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  conversacion_id   BIGINT UNSIGNED  NOT NULL,
  rol               ENUM('user','assistant','system') NOT NULL,
  contenido         TEXT             NOT NULL,
  tokens_usados     SMALLINT UNSIGNED NULL,
  enviado_en        DATETIME         NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id),
  CONSTRAINT fk_mensajes_conv FOREIGN KEY (conversacion_id)
    REFERENCES conversaciones(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_mensajes_conv ON mensajes(conversacion_id, enviado_en);

-- ============================================================
-- LEADS (formulario de contacto del landing)
-- ============================================================

CREATE TABLE leads (
  id          INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  nombre      VARCHAR(120)   NOT NULL,
  email       VARCHAR(180)   NOT NULL,
  telefono    VARCHAR(25)    NULL,
  especialidad VARCHAR(80)   NULL,    -- 'Fisioterapeuta', 'Psicólogo', etc.
  mensaje     TEXT           NULL,
  plan_interes ENUM('base','pro','sin_definir') NOT NULL DEFAULT 'sin_definir',
  estado      ENUM('nuevo','contactado','demo','convertido','descartado')
                             NOT NULL DEFAULT 'nuevo',
  utm_source  VARCHAR(80)    NULL,
  utm_medium  VARCHAR(80)    NULL,
  creado_en   DATETIME       NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id)
) ENGINE=InnoDB;

-- ============================================================
-- FACTURACIÓN (suscripciones y pagos)
-- ============================================================

CREATE TABLE facturas (
  id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  cliente_id      INT UNSIGNED    NOT NULL,
  concepto        VARCHAR(200)    NOT NULL,
  importe         DECIMAL(10,2)   NOT NULL,
  iva_pct         DECIMAL(5,2)    NOT NULL DEFAULT 21.00,
  tipo            ENUM('setup','mensualidad','extra') NOT NULL,
  estado          ENUM('pendiente','pagada','fallida','reembolsada')
                                  NOT NULL DEFAULT 'pendiente',
  fecha_emision   DATE            NOT NULL DEFAULT (CURRENT_DATE),
  fecha_vencimiento DATE          NULL,
  fecha_pago      DATE            NULL,
  stripe_id       VARCHAR(100)    NULL,   -- Stripe payment intent / invoice ID
  notas           TEXT            NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_facturas_cliente FOREIGN KEY (cliente_id)
    REFERENCES clientes(id)
) ENGINE=InnoDB;

-- ============================================================
-- USUARIOS DEL ÁREA CLIENTE (login.html → cliente-demo)
-- ============================================================

CREATE TABLE usuarios (
  id              INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  cliente_id      INT UNSIGNED   NOT NULL,
  email           VARCHAR(180)   NOT NULL UNIQUE,
  password_hash   VARCHAR(255)   NOT NULL,    -- bcrypt
  nombre          VARCHAR(120)   NOT NULL,
  rol             ENUM('admin','staff','solo_lectura') NOT NULL DEFAULT 'admin',
  ultimo_acceso   DATETIME       NULL,
  activo          TINYINT(1)     NOT NULL DEFAULT 1,
  creado_en       DATETIME       NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id),
  CONSTRAINT fk_usuarios_cliente FOREIGN KEY (cliente_id)
    REFERENCES clientes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- VISTAS ÚTILES
-- ============================================================

-- Próximas citas de todos los clientes (hoy en adelante)
CREATE OR REPLACE VIEW v_proximas_citas AS
SELECT
  c.id            AS cita_id,
  cl.slug         AS cliente_slug,
  cl.nombre       AS clinica,
  p.nombre        AS paciente,
  p.telefono,
  s.nombre        AS servicio,
  c.fecha,
  c.hora_inicio,
  c.hora_fin,
  c.estado,
  c.origen,
  c.recordatorio_enviado
FROM citas c
JOIN clientes  cl ON cl.id = c.cliente_id
JOIN pacientes p  ON p.id  = c.paciente_id
LEFT JOIN servicios s ON s.id = c.servicio_id
WHERE c.fecha >= CURRENT_DATE
  AND c.estado NOT IN ('cancelada','no_show')
ORDER BY c.fecha, c.hora_inicio;

-- Resumen de actividad mensual por cliente
CREATE OR REPLACE VIEW v_stats_mes AS
SELECT
  cl.id          AS cliente_id,
  cl.nombre      AS clinica,
  DATE_FORMAT(c.fecha, '%Y-%m') AS mes,
  COUNT(*)                      AS total_citas,
  SUM(c.estado = 'completada')  AS completadas,
  SUM(c.estado = 'cancelada')   AS canceladas,
  SUM(c.estado = 'no_show')     AS no_show,
  SUM(c.origen = 'whatsapp')    AS via_whatsapp,
  SUM(c.origen = 'telegram')    AS via_telegram,
  SUM(c.origen = 'web')         AS via_web
FROM citas c
JOIN clientes cl ON cl.id = c.cliente_id
GROUP BY cl.id, mes;

-- ============================================================
-- DATOS DE DEMOSTRACIÓN (cliente Dr. García)
-- ============================================================

INSERT INTO clientes (slug, nombre, especialidad, email, telefono, direccion, ciudad, plan_id, estado, calendar_id)
VALUES ('fisio-garcia', 'Dr. García Fernández', 'Fisioterapeuta',
        'demo@nerv-ia.com', '+34 960 000 001', 'Calle Mayor 10', 'Valencia', 2, 'activo',
        'demo_garcia@group.calendar.google.com');

SET @cid = LAST_INSERT_ID();

INSERT INTO servicios (cliente_id, nombre, duracion, precio, icono) VALUES
  (@cid, 'Primera consulta',          60, 60.00, '🩺'),
  (@cid, 'Sesión de seguimiento',     30, 40.00, '💆'),
  (@cid, 'Masaje terapéutico',        45, 50.00, '🤲'),
  (@cid, 'Osteopatía',                60, 65.00, '🦴');

INSERT INTO disponibilidad (cliente_id, dia_semana, hora_inicio, hora_fin) VALUES
  (@cid, 1, '09:00', '09:30'), (@cid, 1, '09:30', '10:00'), (@cid, 1, '10:00', '10:30'),
  (@cid, 1, '16:00', '16:30'), (@cid, 1, '16:30', '17:00'), (@cid, 1, '17:00', '17:30'),
  (@cid, 2, '09:00', '09:30'), (@cid, 2, '09:30', '10:00'),
  (@cid, 2, '16:00', '16:30'), (@cid, 2, '16:30', '17:00'),
  (@cid, 3, '09:00', '09:30'), (@cid, 3, '09:30', '10:00'), (@cid, 3, '10:00', '10:30'),
  (@cid, 3, '16:00', '16:30'), (@cid, 3, '16:30', '17:00'),
  (@cid, 4, '09:00', '09:30'), (@cid, 4, '09:30', '10:00'),
  (@cid, 4, '16:00', '16:30'), (@cid, 4, '16:30', '17:00'), (@cid, 4, '17:00', '17:30'),
  (@cid, 5, '09:00', '09:30'), (@cid, 5, '09:30', '10:00'), (@cid, 5, '10:00', '10:30');

INSERT INTO usuarios (cliente_id, email, password_hash, nombre, rol)
VALUES (@cid, 'demo@nerv-ia.com',
        '$2b$12$demo_hash_bcrypt_replace_in_prod',  -- reemplazar con hash real
        'Dr. García', 'admin');

-- Pacientes de demo
INSERT INTO pacientes (cliente_id, nombre, email, telefono, canal_contacto, consentimiento_rgpd, fecha_consentimiento) VALUES
  (@cid, 'Ana Martínez',    'ana.martinez@email.com',  '+34 600 111 111', 'whatsapp',  1, NOW()),
  (@cid, 'Carlos Ruiz',     'carlos.ruiz@email.com',   '+34 600 222 222', 'telegram',  1, NOW()),
  (@cid, 'Elena Sánchez',   'elena.sanchez@email.com', '+34 600 333 333', 'web',        1, NOW()),
  (@cid, 'David López',     NULL,                      '+34 600 444 444', 'whatsapp',  1, NOW()),
  (@cid, 'María Fernández', NULL,                      '+34 600 555 555', 'whatsapp',  1, NOW());
