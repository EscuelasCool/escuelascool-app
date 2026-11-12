# EscuelasCool – Registro en sala (WP2.2)

App para tablets y celulares que registra, por estudiante y por visita: identificación, ánimo, somnolencia, sensación y preferencia térmica (escalas de caritas) y la PVT-B de 3 minutos. Funciona sin internet, guarda cada respuesta en el dispositivo apenas se marca y la envía a REDCap cuando hay conexión. Versión 0.1.0 (prototipo para pilotaje).

## Contenido

| Archivo | Para qué sirve |
|---|---|
| `index.html` | La app completa (HTML, CSS y JavaScript en un archivo) |
| `manifest.webmanifest`, `sw.js`, `icons/` | Permiten instalarla en la pantalla de inicio y abrirla sin internet |
| `redcap/diccionario_datos_sesiones.csv` | Diccionario de datos para crear el proyecto REDCap de sesiones |
| `redcap/plantilla_lista_curso.csv` | Formato de la lista de curso que se carga en cada tablet |
| `R/redcap_respaldo_y_conciliacion.R` | Sube respaldos a REDCap, concilia y expande los ensayos de la PVT |
| `capacitor.config.json` | Configuración para generar la app Android (APK) |

## Decisiones de diseño

**Identificación.** El niño o niña toca su nombre en la lista de su sala y confirma su cumpleaños (día y mes). Tras dos intentos fallidos, la persona del equipo confirma la identidad con el PIN. A REDCap solo viaja el ID de estudiante; los nombres y fechas de nacimiento quedan en la lista de la tablet. Para estudiantes que no están en la lista, el equipo registra el nombre (solo en la tablet) y asigna el ID después desde el Panel; esas sesiones no se envían hasta tener ID.

**Dos proyectos REDCap.** (1) Enrolamiento: nombres, fecha de nacimiento, consentimiento y asentimiento, con acceso restringido. (2) Sesiones: solo IDs seudonimizados y mediciones. Las tablets tienen un token de *solo importación* del proyecto Sesiones: no pueden leer nada de REDCap, ni siquiera lo que ellas mismas enviaron.

**Un registro REDCap por sesión.** El `record_id` es un identificador único generado en la tablet (fecha + 16 caracteres aleatorios). Si un envío se repite por una falla de red, REDCap sobrescribe el mismo registro en vez de duplicarlo. La unión niño–sesiones se hace en R por `id_estudiante`.

**Sin pérdida de datos.**
1. Cada respuesta se escribe en la base local (IndexedDB) antes de avanzar de pantalla; la escritura se da por hecha solo cuando el navegador confirma que quedó grabada.
2. Si la app se cierra a mitad de una sesión, al reabrirse esa sesión queda marcada como incompleta, con lo que alcanzó a registrar.
3. Una sesión pasa a "confirmada" solo cuando REDCap responde con su `record_id`. Las fallidas quedan con el error visible y se reintentan.
4. Nada se borra automáticamente. Solo se pueden borrar, a mano, sesiones ya confirmadas.
5. Respaldo JSON descargable en cualquier momento, que el script de R puede subir a REDCap.

**PVT-B** (Basner et al., 2011): 3 min, ISI aleatorio uniforme de 1–4 s (desde la respuesta hasta el siguiente estímulo; el TR se muestra 1 s dentro de ese intervalo), lapso ≥355 ms, falsa partida <100 ms o toque sin estímulo, sin respuesta a los 30 s. Contador en ms que avanza en pantalla negra. Los tiempos usan el reloj de alta resolución del navegador; el inicio del estímulo se registra en el cuadro en que se dibuja (incertidumbre de ±1 cuadro, ~16 ms, constante dentro de un mismo modelo de tablet). Se guardan todos los ensayos crudos para recalcular las métricas en R. Si la app pasa a segundo plano durante la prueba, la sesión queda marcada como interrumpida. Para detener la prueba, la persona del equipo mantiene presionado 2 s el botón del rincón superior derecho.

## 1. Publicar la app (una vez, ~10 minutos)

1. Descomprime `escuelascool-app.zip`.
2. En https://github.com/HeatSchools → **New repository** → nombre `escuelascool-app` → **Public** → *Create repository*. El repositorio no contiene datos ni credenciales: los datos viven en cada tablet y el token se ingresa en cada dispositivo.
3. En el repositorio: **Add file → Upload files**, arrastra *todo el contenido* de la carpeta (no la carpeta misma) y pulsa **Commit changes**.
4. **Settings → Pages** → *Source*: **Deploy from a branch** → *Branch*: `main`, carpeta `/ (root)` → **Save**.
5. En 1–2 minutos la app queda en **https://heatschools.github.io/escuelascool-app/**. Ese es el enlace para el equipo.

Nunca subas al repositorio listas de curso, respaldos ni tokens.

Para publicar una versión nueva: sube el `index.html` modificado y cambia `CACHE` en `sw.js` (por ejemplo `escuelascool-v0.1.1`); los dispositivos se actualizan la siguiente vez que abren la app con internet.

## 2. Instalar en el celular o la tablet

**Android (Chrome):** abre el enlace → menú ⋮ → **Instalar app** (o *Agregar a la pantalla principal*) → confirma. Abre la app una vez con internet para que quede disponible sin conexión.

**iPhone o iPad (Safari, no Chrome):** abre el enlace → botón **Compartir** → **Agregar a inicio** → **Agregar**. Ábrela siempre desde el ícono; en iPhone, los datos de sitios web abiertos solo en el navegador pueden borrarse tras días sin uso.

La primera vez la app pide configurar la tablet (país, colegio, evaluador/a, etiqueta y PIN). Para conocerla sin datos reales, usa **Probar con datos de ejemplo** (PIN 0000).

## 3. Configurar REDCap

1. Crea el proyecto **EscuelasCool WP2.2 – Sesiones** (clásico, sin encuestas) e importa `redcap/diccionario_datos_sesiones.csv` en *Dictionary → Upload*.
2. Desactiva la numeración automática de registros. Crea *Data Access Groups* por país si cada país debe ver solo lo suyo.
3. Pide al administrador habilitar la API para el proyecto. Crea un usuario técnico (p. ej. `api_tablets`) con permiso **API Import/Update** y sin **API Export**, y genera su token.
4. En cada tablet: **Panel del equipo → Configuración** → URL de la API (termina en `/api/`) y token → *Guardar*. Luego **Enviar a REDCap**.
5. Para el laptop del equipo, genera otro token con exportación e importación, guardado como variable de entorno `REDCAP_SESIONES_TOKEN` (ver el script de R).

**Prueba de conexión (CORS).** Muchos servidores REDCap no aceptan llamadas a la API desde una página web. Si, con internet, el Panel muestra *"Sin conexión con REDCap: … (CORS)"*, el servidor está bloqueando la app web. Hay tres salidas:
- pedir al administrador que permita el origen `https://heatschools.github.io` (no siempre es posible);
- usar la versión Android (sección 4), que no tiene esa restricción;
- descargar el respaldo JSON y subirlo con el script de R.

Ninguna pierde datos.

## 4. Versión Android para el trabajo de campo (APK)

Recomendada para los colegios: almacenamiento que el sistema no borra, envío directo a REDCap y modo kiosco. Requiere Node.js y Android Studio en un computador.

```bash
npm init -y
npm install @capacitor/core @capacitor/cli @capacitor/android @capacitor/filesystem @capacitor/share
mkdir www && cp -r index.html manifest.webmanifest icons www/
npx cap add android
npx cap sync android
npx cap open android      # en Android Studio: Build → Build App Bundle(s)/APK(s) → Build APK(s)
```

`capacitor.config.json` ya activa `CapacitorHttp`, que envía a REDCap sin la restricción CORS. En la versión Android, los botones de respaldo abren el menú *Compartir* (OneDrive, correo, etc.). Instala el APK en las tablets (permitir *instalar apps de origen desconocido*), activa *Fijar pantalla* y un bloqueo de pantalla con PIN, lo que también cifra el almacenamiento del dispositivo.

## 5. Protocolo en terreno (para el equipo)

1. Antes de la visita: cargar o actualizar la lista del curso (Panel → Lista del curso) desde el proyecto de enrolamiento, y verificar que la hora de la tablet sea automática.
2. Durante la visita: elegir la sala → **Empezar** → entregar la tablet. Una tablet por niño a la vez.
3. Al terminar: Panel → **Enviar a REDCap** (si hay internet) y **Respaldo completo (JSON)** a SharePoint, sin excepción.
4. Cada semana: correr el script de R para conciliar (respaldos vs. REDCap).
5. Borrar sesiones de la tablet solo si están confirmadas y hay respaldo.

## Limitaciones conocidas de esta versión

- La latencia de la pantalla táctil varía entre modelos (decenas de ms): usar un único modelo de tablet y registrar `dispositivo` como covariable.
- Los datos locales están protegidos por el bloqueo del dispositivo, no por cifrado propio de la app. El respaldo JSON contiene IDs y, para sesiones sin ID, el nombre registrado: tratarlo como dato sensible.
- Las escalas de caritas son originales del proyecto; conviene un piloto cognitivo con niños de 10–12 años antes de marzo de 2027 y documentarlas en el protocolo y ante los comités de ética (con capturas de pantalla).
- Los parámetros de la PVT se pueden editar en el Panel; quedan registrados en cada sesión, pero no deben cambiarse durante el estudio.
