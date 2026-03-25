# 🚀 Guía de Configuración — Nervia

> Tiempo estimado de setup completo: **2-4 horas**

---

## 📁 Estructura del proyecto

```
nervia/
├── landing/
│   └── index.html              ← Landing page corporativa
├── webhub/
│   └── booking.html            ← Formulario de reserva (1 copia por cliente)
├── n8n-workflows/
│   ├── 01_agente_telegram.json      ← Agente IA en Telegram
│   ├── 02_reserva_google_calendar.json  ← Crea eventos en Calendar
│   ├── 03_agente_whatsapp.json      ← Agente IA en WhatsApp
│   └── 04_leads_landing.json        ← Captura leads del landing
└── docs/
    └── SETUP.md                ← Esta guía
```

---

## PASO 1 — Hosting de los archivos HTML

### Opción A: GitHub Pages (gratuito, recomendado para empezar)
1. Crea un repositorio en github.com
2. Sube todos los archivos manteniendo la estructura de carpetas
3. Ve a Settings → Pages → Source: main branch → `/root`
4. Tu URL será: `https://tuusuario.github.io/nervia/`

### Opción B: Cualquier hosting con FTP
- Sube los archivos a tu servidor
- La landing queda en `tudominio.com/landing/`
- Los formularios en `tudominio.com/webhub/`

---

## PASO 2 — Crear un cliente nuevo (formulario de reserva)

Para cada profesional de salud que contraten Nervia:

1. **Duplica** `webhub/booking.html`
2. **Renómbralo**: `booking-garcia.html`, `booking-martinez.html`, etc.
3. **Edita el bloque `CLIENT_CONFIG`** al inicio del script:

```javascript
const CLIENT_CONFIG = {
  id: "garcia-fisio-01",          // ID único del cliente
  name: "Dr. García Fernández",   // Nombre del profesional
  specialty: "Fisioterapeuta",    // Especialidad
  location: "Valencia",           // Ciudad
  emoji: "🦴",                    // Emoji representativo
  color: "#0D2240",               // Color corporativo del cliente (hex)
  services: [
    "Primera visita (60 min)",    // Lista de servicios
    "Seguimiento (30 min)",
  ],
  schedule: {
    days: [1, 2, 3, 4, 5],       // 1=Lun, 2=Mar, 3=Mie, 4=Jue, 5=Vie, 6=Sab
    slots: [                       // Horas disponibles
      "09:00", "09:30", "10:00",
      "16:00", "16:30", "17:00"
    ]
  },
  // URL del webhook n8n (ver Paso 3)
  webhookUrl: "https://TU-N8N.com/webhook/nervia-booking-garcia",
  calendarId: "garcia@consulta.com"
};
```

4. **Comparte la URL** con el cliente o **genera un QR** con qr-code-generator.com

---

## PASO 3 — Configurar n8n

### 3.1 Importar workflows

En tu instancia de n8n:
1. Settings → Import workflow
2. Importa en este orden:
   - `02_reserva_google_calendar.json` (el más importante)
   - `01_agente_telegram.json`
   - `04_leads_landing.json`
   - `03_agente_whatsapp.json` (solo Plan Pro)

### 3.2 Conectar Google Calendar

1. En n8n: Credentials → Add → Google Calendar OAuth2
2. Sigue el flujo OAuth con la cuenta Google del profesional
3. Activa la credential en el nodo "Crear Evento Google Calendar"

### 3.3 Conectar Telegram (Plan Base)

**Crear bot:**
1. Habla con @BotFather en Telegram
2. Envía `/newbot` y sigue las instrucciones
3. Guarda el token

**En n8n:**
1. Credentials → Add → Telegram API
2. Pega el token del bot
3. Actívalo en los nodos de Telegram

**Personalizar el agente:**
En el nodo "Claude IA — Agente" del workflow de Telegram, edita el system prompt:
```
Reemplaza todos los [PLACEHOLDERS] con los datos reales del cliente:
- [NOMBRE_PROFESIONAL] → "Dr. García Fernández"
- [ESPECIALIDAD] → "Fisioterapeuta"
- [CIUDAD] → "Valencia"
- [DIRECCIÓN] → "Calle Mayor 10, Valencia"
- [TELÉFONO] → "+34 960 000 000"
- [HORARIO] → "L-V de 9:00 a 14:00 y de 16:00 a 19:00"
- [LISTA_SERVICIOS] → "Fisioterapia, Osteopatía, Masaje deportivo"
- [URL_BOOKING] → URL del formulario del cliente
```

### 3.4 Conectar WhatsApp Business (Plan Pro)

1. Crea una app en **developers.facebook.com**
2. Añade el producto "WhatsApp"
3. Configura el número de teléfono
4. Guarda: **Phone Number ID** y **Access Token**
5. En n8n: Settings → Variables de entorno:
   - `WHATSAPP_PHONE_NUMBER_ID` = tu Phone Number ID
   - `WHATSAPP_ACCESS_TOKEN` = tu token
6. URL del webhook para Meta:
   `https://TU-N8N.com/webhook/whatsapp-webhook`

### 3.5 Obtener URL del webhook de reservas

1. Activa el workflow `02_reserva_google_calendar.json`
2. En el nodo "Webhook — Recibir Reserva", copia la URL de producción
3. Pégala en `CLIENT_CONFIG.webhookUrl` de cada formulario

---

## PASO 4 — Personalizar la landing page

Edita `landing/index.html`:

### Cambiar el email de contacto (línea ~560):
```html
<a href="mailto:hola@nervia.es">hola@nervia.es</a>
```

### Conectar el formulario de leads:
Descomenta y edita la línea del fetch en el script:
```javascript
await fetch('https://TU-N8N.com/webhook/nervia-leads', {
  method: 'POST',
  headers: {'Content-Type':'application/json'},
  body: JSON.stringify(data)
});
```

---

## PASO 5 — Por cada nuevo cliente

Lista de acciones para onboarding de un nuevo profesional:

- [ ] Duplicar `booking.html` y configurar `CLIENT_CONFIG`
- [ ] Subir el nuevo archivo al hosting
- [ ] Crear bot de Telegram con @BotFather
- [ ] Importar y configurar workflow de Telegram (cambiar placeholders)
- [ ] Dar acceso OAuth a Google Calendar del profesional
- [ ] Compartir URL del formulario y link del bot con el cliente
- [ ] Generar QR del formulario para la consulta
- [ ] Activar todos los workflows en n8n

---

## 💡 URLs de cada elemento

| Elemento | URL |
|----------|-----|
| Landing | `tudominio.com/landing/` |
| Formulario García | `tudominio.com/webhub/booking-garcia.html` |
| Bot Telegram García | `t.me/NerviaGarciaBot` |
| Webhook reservas | `n8n.tudominio.com/webhook/nervia-booking` |
| Webhook leads | `n8n.tudominio.com/webhook/nervia-leads` |

---

## 🔧 Variables de entorno recomendadas en n8n

```
ANTHROPIC_API_KEY=sk-ant-...
WHATSAPP_PHONE_NUMBER_ID=123456789
WHATSAPP_ACCESS_TOKEN=EAABxx...
NERVIA_ADMIN_TELEGRAM=123456789   (tu chat ID para notificaciones)
```

---

## ❓ Soporte

Para cualquier duda: hola@nervia.es
