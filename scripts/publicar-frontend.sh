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
# Orden de subida: primero /assets (nombres con hash, cache inmutable) y después el resto
# (index.html y archivos de la raíz, no-cache), así index.html nunca referencia un asset que
# todavía no está. No invalida CloudFront: index.html es no-cache y los assets cambian de nombre.
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

log "sync de assets/ a s3://$bucket/assets ($CACHE_ASSETS)"
aws s3 sync "$site/assets" "s3://$bucket/assets" \
  --delete --no-progress --cache-control "$CACHE_ASSETS" >&2

log "sync del resto a s3://$bucket ($CACHE_OTROS)"
aws s3 sync "$site" "s3://$bucket" \
  --exclude "assets/*" --delete --no-progress --cache-control "$CACHE_OTROS" >&2

fin="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fin_s="$(date -u +%s)"

printf '{"imagen":"%s","digest":"%s","bucket":"%s","frontend_hash":"%s","archivos":%s,"inicio":"%s","fin":"%s","duracion_s":%s}\n' \
  "$image" "$digest" "$bucket" "$frontend_hash" "$archivos" "$inicio" "$fin" "$((fin_s - inicio_s))"
