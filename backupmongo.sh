#!/bin/bash
# Script para realizar un backup mensual de MongoDB y comprimirlo

# Configuración estricta de manejo de errores (Mejor Práctica) 
# set -Eeo pipefail asegura que el script se detenga ante el primer error.
set -Eeo pipefail

# --- 1. Variables de Configuración ---

# Parámetros de Conexión a MongoDB (ajustar con variables de entorno)
DB_NAME="db_name"
DB_HOST="your:host" 
DB_USER="backup_user"
DB_PASS="TuContraseñaSegura" 

# Rutas de Almacenamiento
FECHA_MES=$(date +%Y%m)                                     # Formato AAAA-MM
DIRECTORIO_RAIZ="/var/backups/mongodb"
DIRECTORIO_DUMP_TEMPORAL="$DIRECTORIO_RAIZ/dump_temp"
ARCHIVO_COMPRIMIDO="$DIRECTORIO_RAIZ/mensual/mongodb_backup_$FECHA_MES.tar.gz"
LOG_FILE="$DIRECTORIO_RAIZ/mensual/backup_log_$FECHA_MES.log"
RETENCION_MESES=12 # Cuántos meses mantener el backup

# --- 2. Funciones de Utilidad ---

# Función para salir en caso de error y registrarlo [13]
error_exit () {
    echo "❌ ERROR [$(date +'%Y-%m-%d %H:%M:%S')]: $1" >> "$LOG_FILE" 2>&1
    echo "Fallo la operación de backup. Revisa $LOG_FILE" >&2
    exit 1
}

# Iniciar Log
echo "--- Backup Mensual MongoDB Iniciado $(date +'%Y-%m-%d %H:%M:%S') ---" >> "$LOG_FILE"

# Crear directorios de destino si no existen [13, 14]
mkdir -p "$DIRECTORIO_RAIZ/mensual" || error_exit "No se pudo crear el directorio de destino."
mkdir -p "$DIRECTORIO_DUMP_TEMPORAL" || error_exit "No se pudo crear el directorio temporal."

# --- 3. Ejecución del Backup (mongodump) ---
echo "Realizando dump de la base de datos '$DB_NAME'..." >> "$LOG_FILE"

# mongodump exporta los datos en formato BSON [3, 4].
# El flag --out dirige la salida a nuestro directorio temporal.
mongodump --host "$DB_HOST" --db "$DB_NAME" --username "$DB_USER" --password "$DB_PASS" --out "$DIRECTORIO_DUMP_TEMPORAL" 2>&1 >> "$LOG_FILE" || error_exit "El comando mongodump ha fallado."

echo "Dump completado exitosamente." >> "$LOG_FILE"

# --- 4. Compresión y Archivamiento ---
echo "Comprimiendo backup y creando archivo $ARCHIVO_COMPRIMIDO..." >> "$LOG_FILE"

# Utiliza tar para comprimir el dump en un archivo .tar.gz [15]
# Se especifica el directorio de salida final.
tar -czf "$ARCHIVO_COMPRIMIDO" -C "$DIRECTORIO_DUMP_TEMPORAL" "$DB_NAME" 2>&1 >> "$LOG_FILE" || error_exit "La compresión del archivo ha fallado."

echo "Compresión finalizada." >> "$LOG_FILE"

# --- 5. Limpieza y Retención ---

# Eliminar directorio temporal de dump [16]
echo "Limpiando directorio temporal: $DIRECTORIO_DUMP_TEMPORAL" >> "$LOG_FILE"
rm -rf "$DIRECTORIO_DUMP_TEMPORAL" || true # Usamos || true para ignorar errores si ya estuviera vacío [16]

# Eliminar backups antiguos (rotación mensual)
echo "Aplicando política de retención (eliminando archivos de más de $RETENCION_MESES meses)..." >> "$LOG_FILE"
# Buscar archivos .tar.gz en el directorio mensual modificados hace más de N días (30*N) y eliminarlos [14]
find "$DIRECTORIO_RAIZ/mensual" -name "mongodb_backup*.tar.gz" -mtime +$((RETENCION_MESES * 30)) -exec rm {} \; 2>&1 >> "$LOG_FILE"

echo "Política de retención aplicada." >> "$LOG_FILE"

# --- 6. Finalización ---
echo "✅ Backup mensual finalizado: $ARCHIVO_COMPRIMIDO" >> "$LOG_FILE"
echo "----------------------------------------------------" >> "$LOG_FILE"

exit 
