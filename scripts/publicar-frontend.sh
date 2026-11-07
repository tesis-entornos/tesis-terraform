#!/usr/bin/env bash
# Publica el frontend de un entorno: extrae los archivos estáticos de la imagen del frontend
# (referenciada por digest) y los sube al bucket del entorno, servido por CloudFront.
#
#   scripts/publicar-frontend.sh <registro>/<repo>@sha256:<digest> <bucket>
#
# Credenciales: AWS_PROFILE o las del entorno (por ejemplo, CodeBuild). Región: AWS_REGION
# (default us-east-2). Docker tiene que poder hacer pull de la imagen (docker login a ECR antes).
# MANIFEST_OUT=<archivo>: guarda ahí el manifiesto de hashes.
#
# Orden de subida, para que index.html nunca referencie algo que todavía no está:
#   1. assets/ sin subcarpetas: JS y CSS con hash de Vite → inmutable.
#   2. assets/images/: archivos de public/, sin hash en el nombre → no-cache.
#   3. el resto de la raíz → no-cache, con index.html al final.
# Cada paso usa --delete solo sobre lo suyo (los excluidos no se borran). Los grupos no-cache se
# suben siempre (cp) antes del sync: sync no vuelve a subir un archivo de igual tamaño si el local
# es más viejo, y docker cp conserva la fecha de la imagen, así que no actualizaría la metadata.
# No invalida CloudFront: lo no-cache se revalida en cada pedido y lo inmutable cambia de nombre.
#
# Salida: progreso por stderr y, al final, una línea JSON por stdout.
# Funciona en macOS (bash 3.2, shasum) y en Linux (sha256sum).

set -euo pipefail

readonly HTML_DIR=/usr/share/nginx/html
readonly PLATFORM=linux/arm64
readonly CACHE_ASSETS="public, max-age=31536000, immutable"
readonly CACHE_OTROS="no-cache"

log() { printf '[publicar-frontend] %s\n' "$*" >&2; }
die() { log "error: $*"; exit 1; }

usage() {
  printf 'Uso: %s <imagen@sha256:digest> <bucket>\n' "$(basename "$0")" >&2
  exit 2
}

[ "$#" -eq 2 ] || usage
image="$1"
bucket="$2"

[[ "$image" =~ ^[^@[:space:]]+@sha256:[0-9a-f]{64}$ ]] \
  || die "la imagen tiene que venir por digest (<repo>@sha256:<64 hex>): $image"
[[ "$bucket" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]] \
  || die "nombre de bucket inválido: $bucket"
digest="${image#*@}"

export AWS_REGION="${AWS_REGION:-us-east-2}"

for cmd in docker aws; do
  command -v "$cmd" >/dev/null 2>&1 || die "falta el comando $cmd"
done
if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$@"; }
elif command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$@"; }
else
  die "falta sha256sum o shasum"
fi

inicio="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
inicio_s="$(date -u +%s)"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/publicar-frontend.XXXXXX")"
container=""
cleanup() {
  if [ -n "$container" ]; then
    docker rm "$container" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

# --- 1. Archivos de la imagen ---------------------------------------------------

log "pull de $image ($PLATFORM)"
docker pull --quiet --platform "$PLATFORM" "$image" >&2

container="$(docker create --platform "$PLATFORM" "$image")"
docker cp "$container:$HTML_DIR" "$tmp/html"
docker rm "$container" >/dev/null
container=""

site="$tmp/html"
[ -f "$site/index.html" ] || die "la imagen no tiene $HTML_DIR/index.html"
[ -d "$site/assets" ] || die "la imagen no tiene $HTML_DIR/assets"
# Solo se conoce assets/images como subcarpeta: otra quedaría sin regla de cache, así que se frena.
otras="$(cd "$site/assets" && find . -mindepth 1 -type d ! -path './images' ! -path './images/*')"
[ -z "$otras" ] || die "subcarpetas de assets/ sin regla de cache: $(echo "$otras" | tr '\n' ' ')"

# --- 2. Hash del contenido ------------------------------------------------------

# Manifiesto "<sha256>  <ruta relativa>", ordenado por ruta (orden de bytes, igual en
# macOS y Linux). El hash del frontend es el sha256 del manifiesto.
manifest="$tmp/manifest.txt"
(
  cd "$site"
  find . -type f | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r path; do
    printf '%s  %s\n' "$(sha256 "$path" | cut -d' ' -f1)" "$path"
  done
) > "$manifest"

archivos="$(wc -l < "$manifest" | tr -d ' ')"
[ "$archivos" -gt 0 ] || die "no hay archivos para publicar"
frontend_hash="$(sha256 "$manifest" | cut -d' ' -f1)"
log "$archivos archivos, frontend_hash $frontend_hash"

if [ -n "${MANIFEST_OUT:-}" ]; then
  cp "$manifest" "$MANIFEST_OUT"
  log "manifiesto guardado en $MANIFEST_OUT"
fi

# --- 3. Subida ------------------------------------------------------------------

# 1. assets/ sin subcarpetas (con hash): sync alcanza, un nombre nuevo es un archivo nuevo.
log "1/3 assets/ sin subcarpetas → s3://$bucket/assets ($CACHE_ASSETS)"
aws s3 sync "$site/assets" "s3://$bucket/assets" \
  --exclude "*/*" --delete --no-progress --cache-control "$CACHE_ASSETS" >&2

# 2. assets/images/ (sin hash): se suben siempre y después sync --delete borra lo que sobra.
if [ -d "$site/assets/images" ]; then
  log "2/3 assets/images/ → s3://$bucket/assets/images ($CACHE_OTROS)"
  aws s3 cp "$site/assets/images" "s3://$bucket/assets/images" \
    --recursive --no-progress --cache-control "$CACHE_OTROS" >&2
  aws s3 sync "$site/assets/images" "s3://$bucket/assets/images" \
    --delete --no-progress --cache-control "$CACHE_OTROS" >&2
else
  log "2/3 sin assets/images/: se borra lo que haya en el bucket"
  aws s3 rm "s3://$bucket/assets/images" --recursive --only-show-errors >&2
fi

# 3. El resto de la raíz, con index.html al final.
log "3/3 raíz sin assets/ → s3://$bucket ($CACHE_OTROS), index.html al final"
aws s3 cp "$site" "s3://$bucket" \
  --recursive --exclude "assets/*" --exclude "index.html" \
  --no-progress --cache-control "$CACHE_OTROS" >&2
aws s3 sync "$site" "s3://$bucket" \
  --exclude "assets/*" --exclude "index.html" \
  --delete --no-progress --cache-control "$CACHE_OTROS" >&2
aws s3 cp "$site/index.html" "s3://$bucket/index.html" \
  --no-progress --cache-control "$CACHE_OTROS" >&2

fin="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fin_s="$(date -u +%s)"

printf '{"imagen":"%s","digest":"%s","bucket":"%s","frontend_hash":"%s","archivos":%s,"inicio":"%s","fin":"%s","duracion_s":%s}\n' \
  "$image" "$digest" "$bucket" "$frontend_hash" "$archivos" "$inicio" "$fin" "$((fin_s - inicio_s))"
