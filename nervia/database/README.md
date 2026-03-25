# Base de datos Nervia — MariaDB

## Requisitos
- MariaDB 10.6+ (o MySQL 8.0+)
- Usuario con permisos CREATE DATABASE

## Instalación rápida

```bash
# 1. Importar el esquema completo
mysql -u root -p < nervia_schema.sql

# 2. Verificar tablas creadas
mysql -u root -p nervia -e "SHOW TABLES;"
```

## Crear usuario dedicado (recomendado)

```sql
CREATE USER 'nervia_app'@'localhost' IDENTIFIED BY 'CambiaEstaPassword123!';
GRANT SELECT, INSERT, UPDATE, DELETE ON nervia.* TO 'nervia_app'@'localhost';
FLUSH PRIVILEGES;
```

## Tablas

| Tabla           | Descripción                                         |
|-----------------|-----------------------------------------------------|
| `planes`        | Planes de suscripción (Base Telegram / Pro WhatsApp)|
| `clientes`      | Clínicas y profesionales suscritos                  |
| `servicios`     | Servicios de cada clínica                           |
| `disponibilidad`| Horarios semanales disponibles por cliente          |
| `pacientes`     | Pacientes de cada clínica                           |
| `citas`         | Reservas / citas                                    |
| `conversaciones`| Sesiones de chat con el agente IA                   |
| `mensajes`      | Historial de mensajes de cada conversación          |
| `leads`         | Contactos del formulario del landing                |
| `facturas`      | Pagos y suscripciones                               |
| `usuarios`      | Acceso al área cliente (login.html)                 |

## Vistas incluidas

- **`v_proximas_citas`** — todas las citas pendientes/confirmadas desde hoy
- **`v_stats_mes`** — resumen mensual de actividad por cliente

## Conexión desde n8n

En n8n → Settings → Credentials → MySQL/MariaDB:
```
Host:     localhost (o IP del servidor)
Port:     3306
Database: nervia
User:     nervia_app
Password: (la que configuraste)
```

## Contraseñas de usuarios

Las contraseñas en `usuarios.password_hash` deben ser hashes bcrypt (coste 12).
El registro demo incluye un hash de marcador — **reemplázalo antes de producción**:

```bash
# Generar hash en Node.js
node -e "const b=require('bcrypt'); b.hash('nervia2025',12).then(console.log)"
```

Luego:
```sql
UPDATE usuarios SET password_hash='<hash_generado>' WHERE email='demo@nervia.es';
```
