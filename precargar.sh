#!/usr/bin/env bash
# Visita todas las URLs del sitemap de delaroca.es para que LiteSpeed las tenga en caché,
# y también las páginas 2, 3, 4... de categorías, etiquetas, tienda y blog (no están en el sitemap).
# Las páginas que ya están en caché ("hit") responden en ~0,02 s y apenas cargan el servidor.
set -u

SITE="https://www.delaroca.es"
PAUSA="${PAUSA:-1}"   # segundos entre visitas, para no cargar el servidor compartido
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36'
ACCEPT='text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8'
CUERPO=$(mktemp)
PAGINAS=$(mktemp)

urls=$(curl -s "$SITE/sitemap_index.xml" | grep -o '<loc>[^<]*</loc>' | sed 's/<[^>]*>//g' |
  while read -r sitemap; do curl -s "$sitemap" | grep -o '<loc>[^<]*</loc>' | sed 's/<[^>]*>//g'; done |
  grep -viE '\.(jpe?g|png|webp|gif)$' | sort -u)

total=$(echo "$urls" | grep -c .)
echo "URLs en el sitemap: $total"
[ "$total" -gt 0 ] || { echo "No se pudo leer el sitemap"; exit 1; }

hit=0; miss=0; error=0; inicio=$(date +%s)

visitar() {
  local url="$1" out codigo cache
  out=$(curl -s -o "$CUERPO" -D - --compressed --max-time 60 -A "$UA" -H "Accept: $ACCEPT" \
        -w 'codigo=%{http_code} tiempo=%{time_total}' "$url")
  codigo=$(echo "$out" | grep -o 'codigo=[0-9]*' | cut -d= -f2)
  cache=$(echo "$out" | grep -i '^x-litespeed-cache:' | awk '{print tolower($2)}' | tr -d '\r')
  if [ "$codigo" != "200" ]; then
    error=$((error+1)); echo "ERROR $codigo $url"
  elif [ "$cache" = "hit" ]; then
    hit=$((hit+1))
  else
    miss=$((miss+1)); echo "precargada $(echo "$out" | grep -o 'tiempo=[0-9.]*') $url"
    sleep "$PAUSA"
  fi
}

# 1) Páginas del sitemap. De paso se apunta cuántas páginas (page/2/, page/3/...) tiene cada listado.
while read -r url; do
  visitar "$url"
  case "$url" in */) ;; *) continue ;; esac
  max=$(grep -oE "href=\"${url}page/[0-9]+/\"" "$CUERPO" | grep -oE '[0-9]+/"$' | tr -d '/"' | sort -n | tail -1)
  if [ -n "$max" ]; then
    for n in $(seq 2 "$max"); do echo "${url}page/$n/" >> "$PAGINAS"; done
  fi
done <<< "$urls"

# 2) Páginas siguientes de los listados (categorías, etiquetas, tienda, blog...).
extra=$(sort -u "$PAGINAS")
nextra=$(echo "$extra" | grep -c .)
echo "Páginas siguientes de listados: $nextra"
if [ "$nextra" -gt 0 ]; then
  while read -r url; do visitar "$url"; done <<< "$extra"
fi

rm -f "$CUERPO" "$PAGINAS"
echo "----"
echo "Ya en caché: $hit | Precargadas ahora: $miss | Errores: $error | Duración: $(( ($(date +%s)-inicio)/60 )) min"
