# omasyncro: contexto para Claude Code

Fuente de verdad del proyecto. Léelo antes de cambiar nada. El uso está en `README.md`
(en inglés). **Público** en https://github.com/lordyoyi/omasyncro (MIT) desde el 2026-10-07.

## Qué es

Fusión de dos proyectos anteriores, que se conservan intactos como referencia:
- `lordyoyi/omarchy-themes`: mismos temas y wallpapers en todos los equipos (vía git).
- `lordyoyi/omarchy-theme-mirror`: mismo tema activo en vivo (vía Tailscale).

Nació como `omasync` (repo privado `lordyoyi/omasync`, archivado). Al publicarlo apareció
`dupontbertrand/omasync`, un plugin de Omarchy parecido (un equipo principal empuja tema, barra,
Hyprland y plugins por LAN + SSH), y el usuario eligió renombrar a **omasyncro**. El README lo
menciona en "Similar projects". El protocolo y el puerto no cambiaron con el nombre, así que
omasync y omasyncro se entienden entre sí.

Pedido del usuario (2026-10-07): un repo nuevo, **código separado de los datos**, genérico y
limpio para que otros usuarios de Omarchy lo instalen. Al instalar, la app ve lo que la máquina
tiene y lo mantiene. Ajustarlo con cada cambio de Omarchy está aceptado.

## Máquinas del usuario

| Máquina | Tailscale | Notas |
|---|---|---|
| Zenbook | `omarchy` | Laptop, se suspende. Código en `~/Dev/omasyncro`. |
| notro | `notro` | Mini PC 24/7, sesión abierta. Sin SSH desde el Zenbook: los pasos para notro van en un `.md` en `~/Dropbox/01 - Proyectos/`. |
| hex | `hex` | Linux en la misma tailnet, sin omasyncro. Aparece en la detección y no responde; es normal. |

Datos del usuario: `lordyoyi/omasyncro-data` (privado, antes `omasync-data`; GitHub redirige). Config: `AUTO_UPDATE=yes`.

## Estructura

- `bin/omasyncro`: comandos (`setup`, `status`, `sync`, `remove`, `remove-bg`) y los internos
  (`tick`, `changed`, `serve`).
- `lib/common.sh`: rutas, config (`~/.config/omasyncro/config`), log, locks.
- `lib/library.sh`: biblioteca (temas + wallpapers) contra el repo de datos. Portado de
  `omarchy-themes-sync` casi sin cambios de lógica.
- `lib/active.sh`: tema activo. Portado de `omarchy-theme-mirror`.
- `lib/peers.sh`: detección de peers, `send`, `broadcast`, `serve`.
- `systemd/`: `omasyncro.socket` + `omasyncro@.service` (recibir), `omasyncro-active.path/.service`
  (vigilar el tema activo), `omasyncro.timer/.service` (tick cada 5 min).
- `install.sh` enlaza `omasyncro` en `~/.local/bin` y corre `omasyncro setup`. `uninstall.sh`.
- `test/run.sh`: prueba de punta a punta con dos máquinas simuladas. **Correrla después de
  cualquier cambio.**

Rutas en cada máquina: datos en `~/.local/share/omasyncro/data`, estado y log en
`~/.local/state/omasyncro/`.

## Decisiones (no cambiar sin hablarlo)

- **Sin hooks de Omarchy.** Todo va con unidades de systemd: un path unit para el tema activo
  y un timer. Cambiar el fondo no dispara ningún hook, y los wallpapers nuevos se agregan
  copiando archivos, sin ningún comando.
- **Peers sin lista:** cualquier máquina Linux online en `tailscale status` que responda en el
  puerto. Nota de seguridad en el README: se comparte con todo equipo de la tailnet que tenga
  la app (pedido explícito del usuario, en vez de una clave compartida).
- **Sin regla de ufw ni sudo:** Tailscale acepta el tráfico de `tailscale0` antes que ufw
  (notro respondió "connection refused" sin regla, no timeout). Si alguien corre Tailscale
  con `--netfilter-mode=off`, tendría que abrir el puerto a mano.
- **Repo de datos sin URL:** `setup` usa `gh` para encontrar o crear `<usuario>/omasyncro-data`.
  Con URL, cualquier host git.
- **La biblioteca solo agrega**; `remove`/`remove-bg` dejan tombstones. Reinstalar revive. El
  tema activo nunca se borra solo.
- **Tema activo:** gana el timestamp más nuevo. Una máquina recién instalada marca su estado
  con timestamp 1, así sigue a las demás en vez de imponerse. Al aplicar un estado remoto se
  guarda lo que quedó aplicado con el timestamp remoto (sin rebotes, y sin pisar al otro con un
  fondo de reemplazo).
- **Orden:** si el tema o fondo activo no está en la biblioteca, `changed` sincroniza y manda
  `PULL` antes del `SET`. Si al recibir falta algo, `apply_active` sincroniza antes de aplicar.
- **Locks:** fd 8 = tema activo, fd 7 = biblioteca; siempre 8 antes que 7. Los comandos de
  Omarchy se llaman con `7>&- 8>&-`. `changed` espera el lock de `omarchy-theme-set`.
- **AUTO_UPDATE** (por defecto `no`): en cada sync completo hace `git pull` del código y, si
  cambió `systemd/`, vuelve a enlazar las unidades. En las máquinas del usuario está en `yes`.

## Probar

`test/run.sh` (o `test/run.sh <dir>` para conservar el directorio). Usa un Omarchy falso con
stubs de `omarchy-theme-set`, `omarchy-theme-bg-set`, `tailscale`, `systemctl` y `gh`, repos de
temas locales y socat como listener (con `trap '' TERM HUP`, porque socat mata al hijo al
cortar; systemd no). Nunca probar contra `~/.config` ni `~/.local` reales.

## Estado

2026-10-07: omasyncro instalado en el Zenbook y en notro. Los repos antiguos (`omasync`,
`omarchy-themes`, `omarchy-theme-mirror`) quedaron archivados en GitHub y sin copia local. Prueba real: cambio de
tema aplicado en el otro equipo en ~2.9 s (Zenbook → notro) y ~3.5 s (notro → Zenbook; el Zenbook
tarda más en su propio `omarchy theme set`), solo fondo en ~260 ms, sin rebotes.

Al publicar se agregó: fondos pedidos por un peer limitados a imágenes en las carpetas de fondos
y temas de Omarchy (`allowed_bg`), `status` consulta a los peers en paralelo, y `uninstall.sh
--purge` ya no borra la carpeta del programa. 20 pruebas en `test/run.sh`.

Gotcha de notro: `gh` corre vía shim de mise, que imprime un aviso en stdout antes de la
respuesta; por eso `gh_value` se queda solo con la última línea.
