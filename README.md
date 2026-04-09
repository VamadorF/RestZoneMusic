# RestZoneMusic

Addon para **World of Warcraft (retail)** que reproduce **música aleatoria** del juego cuando estás en **zona de descanso** (posada / área de descanso).

## Instalación

1. Copia la carpeta `RestZoneMusic` dentro de `_retail_\Interface\AddOns\`.
2. En el juego: **Addons** → activa **RestZoneMusic** → recargar UI (`/reload`).

## Uso

- **Opciones:** escribe `/rzm` o haz **clic izquierdo** en el icono del LDB (minimapa / soporte de broker).
- **Siguiente pista:** **clic derecho** en el icono (solo en descanso) o el botón en el panel de opciones.
- **Activar / desactivar:** **Shift + clic** en el icono.
- Icono del minimapa: se puede ocultar desde opciones (**LibDBIcon**).

## Lista de pistas

Las rutas bajo `sound/music/` y los **FileDataID** vienen de un listfile comunitario (p. ej. Excel `community-listfile.xlsx`). El archivo **`RestZoneMusic_Data.lua`** define:

- `TRACKS` — orden de reproducción (barajado en el cliente).
- `TRACK_NAMES` — texto mostrado en chat al reproducir.
- `TRACK_DURATIONS` — duración en segundos por ID (**opcional**; ver más abajo).

Pistas extra de taberna / Wowhead se añaden en **`RestZoneMusic.lua`** si no están en el listfile.

## Duración de cada pista

El API **`PlayMusic()`** del juego **repite la música en bucle** y **no avisa** cuando termina una pista. El addon usa:

- `TRACK_DURATIONS[id]` si existe en los datos;
- si no, el valor **“Duración por pista (seg)”** en opciones.

Para **medir** duraciones con archivos exportados (p. ej. **wow.export**):

```powershell
cd "ruta\a\RestZoneMusic"
pip install -r tools\requirements.txt
python tools\gen_music_data.py --xlsx "ruta\community-listfile.xlsx" --export-root "ruta\wowexport" --layout full -o RestZoneMusic_Data.lua
```

- **`--layout full`:** la carpeta de export contiene `sound\music\...`.
- **`--layout music_only`:** la raíz del export es el contenido de `music\` (sin `sound\music`).

Si falta un archivo en el export, ese ID no tendrá entrada en `TRACK_DURATIONS`.

## Regenerar solo datos (sin duraciones)

```powershell
python tools\gen_music_data.py --xlsx "ruta\listfile.xlsx" -o RestZoneMusic_Data.lua
```

## Requisitos en el cliente

- **Interface** indicada en `RestZoneMusic.toc` (compatible con la versión de juego al publicar el addon).
- Librerías embebidas: **Ace3**, **LibDataBroker-1.1**, **LibDBIcon-1.0**.

## Estructura del repositorio

| Ruta | Descripción |
|------|-------------|
| `RestZoneMusic.toc` | Manifiesto de carga |
| `RestZoneMusic.lua` | Lógica del addon |
| `RestZoneMusic_Data.lua` | IDs, nombres y duraciones (generado) |
| `tools/gen_music_data.py` | Genera `RestZoneMusic_Data.lua` desde el XLSX |
| `tools/requirements.txt` | Dependencias Python del generador |
| `Libs/` | Ace3, LDB, LibDBIcon |

## Licencia y autor

Ver el propietario del repositorio. Este README describe el uso técnico del proyecto.
