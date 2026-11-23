#!/usr/bin/env bash
# Comprueba una muestra fija de ~45 páginas y apunta cuántas siguen en la caché de LiteSpeed.
# Sirve para ver a qué hora se vacía la caché. Las que no están quedan guardadas al pasar.
set -u
SITE="https://www.delaroca.es"
UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36'
ACCEPT='text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8'
urls=$(curl -s "$SITE/sitemap_index.xml" | grep -o '<loc>[^<]*</loc>' | sed 's/<[^>]*>//g' |
  while read -r s; do curl -s "$s" | grep -o '<loc>[^<]*</loc>' | sed 's/<[^>]*>//g'; done |
  grep -viE '\.(jpe?g|png|webp|gif)$' | sort -u | awk 'NR%30==1')
urls=$(printf '%s\n%s/\n%s/categoria-producto/categorias/abrigos-de-piel/\n' "$urls" "$SITE" "$SITE")
hit=0; total=0; fallos=""
while read -r url; do
  [ -n "$url" ] || continue
  c=$(curl -s -o /dev/null -D - --compressed --max-time 60 -A "$UA" -H "Accept: $ACCEPT" "$url" |
      grep -i '^x-litespeed-cache:' | awk '{print tolower($2)}' | tr -d '\r')
  total=$((total+1))
  if [ "$c" = "hit" ]; then hit=$((hit+1)); else echo "  no estaba: $url"; fi
done <<< "$urls"
echo "SONDA $(TZ=Europe/Madrid date '+%Y-%m-%d %H:%M') Madrid: en caché $hit de $total"
