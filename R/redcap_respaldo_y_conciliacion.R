# =============================================================================
# EscuelasCool WP2.2 – Respaldo, envío a REDCap y conciliación
# Uso: en el laptop del equipo, NO en las tablets.
#   1) Sube a REDCap las sesiones de los respaldos JSON que aún no estén allí
#      (útil si una tablet no pudo sincronizar, o si el servidor bloquea CORS).
#   2) Concilia: qué hay en los respaldos vs. qué hay en REDCap.
#   3) Expande los ensayos crudos de la PVT a formato largo.
# Requiere un token del proyecto "Sesiones" con exportación e importación,
# guardado como variable de entorno (nunca escrito en el script):
#   usethis::edit_r_environ()  ->  REDCAP_SESIONES_TOKEN=xxxxxxxx
# =============================================================================

library(jsonlite)
library(dplyr)
library(tidyr)
library(readr)
library(REDCapR)

uri   <- "https://redcap.TU-UNIVERSIDAD/api/"        # ajustar
token <- Sys.getenv("REDCAP_SESIONES_TOKEN")
carpeta_respaldos <- "respaldos"                     # JSON descargados desde el Panel

# --- 1. Leer todos los respaldos ---------------------------------------------
archivos <- list.files(carpeta_respaldos, pattern = "_respaldo\\.json$", full.names = TRUE)
stopifnot(length(archivos) > 0)

leer_respaldo <- function(f) {
  x <- fromJSON(f, simplifyVector = TRUE)
  if (length(x$redcap) == 0) return(NULL)
  as_tibble(x$redcap) |> mutate(across(everything(), as.character), .archivo = basename(f))
}
filas <- bind_rows(lapply(archivos, leer_respaldo)) |>
  distinct(record_id, .keep_all = TRUE)               # la misma sesión puede estar en varios respaldos

# --- 2. Qué falta en REDCap ---------------------------------------------------
en_redcap <- redcap_read_oneshot(uri, token, fields = "record_id")$data$record_id
faltan <- filas |> filter(!record_id %in% en_redcap)
message("Sesiones en respaldos: ", nrow(filas),
        " | ya en REDCap: ", sum(filas$record_id %in% en_redcap),
        " | por subir: ", nrow(faltan))

if (nrow(faltan) > 0) {
  res <- redcap_write(select(faltan, -.archivo), redcap_uri = uri, token = token)
  stopifnot(res$success)
}

# --- 3. Conciliación final ----------------------------------------------------
sesiones <- redcap_read_oneshot(uri, token)$data
conciliacion <- filas |>
  mutate(en_redcap = record_id %in% sesiones$record_id) |>
  count(.archivo, en_redcap)
print(conciliacion)
stopifnot(all(filas$record_id %in% sesiones$record_id))

# --- 4. Ensayos de la PVT en formato largo -----------------------------------
ensayos <- sesiones |>
  filter(!is.na(pvt_ensayos), pvt_ensayos != "") |>
  select(record_id, id_estudiante, pais, colegio, sala, dispositivo, pvt_ensayos) |>
  mutate(t = lapply(pvt_ensayos, \(x) read_csv(I(x), show_col_types = FALSE,
                                                col_types = "icdddc"))) |>
  select(-pvt_ensayos) |>
  unnest(t) |>
  # hora_local es la hora del dispositivo; la zona está en sesiones$zona_horaria
  mutate(hora_local = as.POSIXct(hora_local, format = "%Y-%m-%d %H:%M:%OS"))

# Recalcular métricas desde los ensayos (no depender del cálculo de la app)
metricas <- ensayos |>
  group_by(record_id) |>
  summarise(
    n_estimulos = sum(tipo %in% c("respuesta", "falsa_partida", "sin_respuesta")),
    rt_mediana  = median(rt_ms[tipo == "respuesta"]),
    vel_media   = mean(1000 / rt_ms[tipo == "respuesta"]),
    lapsos      = sum(tipo == "respuesta" & rt_ms >= 355) + sum(tipo == "sin_respuesta"),
    falsas      = sum(tipo %in% c("falsa_partida", "falsa_partida_isi")),
    .groups = "drop"
  )
