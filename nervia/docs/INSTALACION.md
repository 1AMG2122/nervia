# 🧠 Nervia — Guía de Instalación Completa

## Estructura del Proyecto

```
nervia/
├── landing/
│   └── index.html              ← Landing page corporativa
├── webhub/
│   └── form.html               ← Formulario de citas (personalizable por cliente)
├── n8n-workflows/
│   ├── nervia-telegram-agent.json      ← Agente IA en Telegram
│   ├── nervia-whatsapp-agent.json      ← Agente IA en WhatsApp
│   └── nervia-webhook-calendar.json    ← Formulario → Google Calendar
└── docs/
    └── INSTALACION.md          ← Esta guía
```

---

## PASO 1 — Publicar los archivos HTML

### Opción A: Netlify (recomendado, gratis)
1. Ve a [netlify.com](https://netlify.com) y crea cuenta
2. Arrastra la carpeta `nervia/` al dashboard de Netlify
3. Obtienes URL tipo: `https://nervia-tunombre.netlify.app`
4. La landing → `https://tu-url.netlify.app/landing/`
5. El formulario → `https://tu-url.netlify.app/webhub/form.html?cliente=ID`

### Opción B: GitHub Pages
1. Crea repositorio en GitHub
2. Sube los archivos
3. Activa GitHub Pages en Settings > Pages

### Opción C: Tu propio hosting
- Sube por FTP a `public_html/nervia/`

---

## PASO 2 — Configurar n8n

### Requisitos previos en n8n
- n8n activo (cloud o self-hosted)
- Acceso a **Settings > Credentials**

### Credenciales a crear en n8n:

#### 1. OpenAI API
- Tipo: `OpenAI API`
- Ve a [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
- Crea una API key y pégala en n8n

#### 2. Google Calendar (OAuth2)
- Tipo: `Google Calendar OAuth2 API`
- Ve a [Google Cloud Console](https://console.cloud.google.com)
- Crea proyecto → Habilita Google Calendar API
- Crea credenciales OAuth2 → tipo "Web application"
- URI de redirección: `https://TU-N8N.com/rest/oauth2-credential/callback`
- Añade Client ID y Client Secret en n8n

#### 3. Telegram Bot
- Habla con [@BotFather](https://t.me/botfather) en Telegram
- Comando: `/newbot` → sigue las instrucciones
- Copia el TOKEN y úsalo en la credencial `Telegram API` de n8n

#### 4. SMTP (para emails de confirmación)
- Usa Gmail, Mailgun, Brevo o tu SMTP propio
- Tipo: `SMTP`

---

## PASO 3 — Importar los Workflows en n8n

1. En n8n, ve a **Workflows > Import from file**
2. Importa cada archivo `.json` de la carpeta `n8n-workflows/`

### Workflow 1: `nervia-telegram-agent.json`
Después de importar:
1. Abre el nodo **"Extraer Datos"**
2. Edita el objeto `CLIENTE_CONFIG`:
   ```javascript
   const CLIENTE_CONFIG = {
     id: 'TU_CLIENTE_ID',          // ej: 'fisio-garcia'
     nombre: 'Nombre del Profesional',
     especialidad: 'Su especialidad',
     horario: 'Lunes-Viernes 9-13h y 16-20h',
     telefono: '+34 600 000 000',
     direccion: 'Dirección completa',
     form_url: 'https://TU-URL/form.html?cliente=TU_CLIENTE_ID',
     google_calendar_id: 'TU_CALENDAR@group.calendar.google.com',
     servicios: [...]
   };
   ```
3. En el nodo **"Telegram Trigger"**: selecciona la credencial del bot
4. En **"Agente IA"**: selecciona la credencial OpenAI
5. En **"Responder por Telegram"**: selecciona la credencial Telegram
6. **Activa** el workflow (toggle en la esquina superior)

### Workflow 2: `nervia-webhook-calendar.json`
1. Abre el nodo **"Webhook Recibe Reserva"**
2. Copia la URL del webhook (aparece al abrir el nodo en modo "production")
3. **Pega esa URL** en el formulario HTML (`form.html`), en la propiedad `n8n_webhook` del cliente correspondiente
4. En **"Crear Evento Google Calendar"**: selecciona credencial Google Calendar
5. Activa el workflow

### Workflow 3: `nervia-whatsapp-agent.json`
Para WhatsApp necesitas una cuenta de WhatsApp Business API:

**Opción recomendada: Meta (gratis para empezar)**
1. Ve a [developers.facebook.com](https://developers.facebook.com)
2. Crea una app → tipo "Business"
3. Añade producto "WhatsApp"
4. Obtén tu `Phone Number ID` y `Access Token`
5. En el nodo **"Parsear Mensaje WhatsApp"**, edita:
   ```javascript
   wa_phone_id: 'TU_PHONE_NUMBER_ID',
   wa_token: 'TU_ACCESS_TOKEN'
   ```
6. La URL del webhook (del nodo "WhatsApp Webhook") configúrala en Meta Developers > WhatsApp > Configuration
7. Verify Token: usa cualquier string secreto que pongas también en Meta

---

## PASO 4 — Añadir un nuevo cliente/profesional

### En el formulario web (`form.html`):
Añade una entrada al objeto `CLIENTS`:
```javascript
"nombre-cliente": {
  name: "Nombre del Profesional",
  specialty: "Su especialidad",
  location: "Dirección",
  initials: "NP",       // Iniciales para el avatar
  color: "#0D2240",     // Color principal (hex)
  accent: "#2EC574",    // Color acento
  n8n_webhook: "https://TU-N8N/webhook/nervia-booking",
  services: [
    { id: "consulta", icon: "🩺", name: "Primera consulta", duration: "45 min", price: "50€" }
  ],
  availableSlots: {
    1: ["09:00","10:00","11:00","16:00","17:00"],  // Lunes
    2: ["09:00","10:00","16:00","17:00"],           // Martes
    3: ["09:00","10:00","11:00","16:00","17:00"],   // Miércoles
    4: ["09:00","10:00","16:00","17:00"],           // Jueves
    5: ["09:00","10:00","11:00"]                    // Viernes
  }
}
```

### URL del formulario para ese cliente:
```
https://TU-URL/form.html?cliente=nombre-cliente
```

### Para Telegram: duplica el workflow `nervia-telegram-agent.json`
1. En n8n: Workflows > ... > Duplicate
2. Edita `CLIENTE_CONFIG` con los datos del nuevo profesional
3. Crea un nuevo bot con BotFather
4. Actualiza la credencial Telegram
5. Activa el workflow

---

## PASO 5 — Configurar recordatorio 24h antes (Workflow adicional)

Crear un workflow extra en n8n:
- **Trigger**: Schedule (cada hora)
- **Lógica**: Consultar Google Calendar → si hay evento mañana → enviar SMS/WhatsApp/email al paciente

---

## URLs del sistema completo

| Componente | URL |
|---|---|
| Landing page | `https://TU-URL/landing/` |
| Formulario cliente A | `https://TU-URL/form.html?cliente=fisio-garcia` |
| Formulario cliente B | `https://TU-URL/form.html?cliente=psicologa-martinez` |
| Webhook n8n (reservas) | `https://TU-N8N/webhook/nervia-booking` |
| Webhook n8n (WhatsApp) | `https://TU-N8N/webhook/nervia-whatsapp` |

---

## Costes estimados (mensual)

| Servicio | Plan gratuito | De pago |
|---|---|---|
| n8n Cloud | Gratis (5k ejecuciones) | 20€/mes |
| OpenAI API | — | ~3-8€/mes por cliente |
| Netlify hosting | Gratis | — |
| Google Calendar | Gratis | — |
| Telegram bots | Gratis | — |
| WhatsApp Meta API | Gratis (1000 conv/mes) | Según volumen |

---

## Soporte y personalización

Para personalizar colores, servicios, mensajes del agente o añadir más clientes, edita:
- `form.html` → objeto `CLIENTS`
- Workflows n8n → nodo `CLIENTE_CONFIG`
- Landing page → `index.html`
