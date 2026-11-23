# Precarga de caché de delaroca.es

Cada noche (03:30, hora de Madrid) GitHub visita todas las páginas del sitemap de delaroca.es
para que LiteSpeed Cache las tenga preparadas y abran al instante.

- Solo carga el servidor con las páginas que no están en caché, con 1 segundo de pausa entre ellas.
- Para lanzarlo a mano: pestaña **Actions** → "Precarga caché delaroca.es" → **Run workflow**.
- Para pararlo: pestaña **Actions** → el flujo → menú "..." → **Disable workflow**.
