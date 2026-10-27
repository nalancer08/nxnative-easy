# ¿Dónde están mis partidas?

**Las partidas están en el dispositivo donde juegas.** La app de preparación de
Mac no recibe automáticamente lo que guardas en tu iPhone o iPad. Todavía no hay
sincronización en la nube.

## Si juegas en Mac

Se guardan fuera de la app, aquí:

```text
~/Library/Application Support/nxnative/<TITLE ID>/save/
```

Algunos juegos usan además una carpeta hermana llamada `save_device`.
Para Metroid Dread, ve a **Finder → Ir → Ir a la carpeta…** y pega:

```text
~/Library/Application Support/nxnative/010093801237C000/
```

Ahí están `save` y, si el juego la utiliza, `save_device`. Preparar otra versión
o mover la `.app` no reemplaza esas carpetas. Cierra el juego anterior antes de
abrir la versión nueva. Estas son las rutas predeterminadas; una configuración
avanzada con `DM_SAVE` puede cambiarlas.

## Si juegas en iPhone o iPad

Están dentro del contenedor privado de **esa app en ese dispositivo**, en
`Documents/save` y, cuando corresponde, `Documents/save_device`.

Para verlas: conecta y desbloquea tu dispositivo, confía en el Mac y abre
**Finder → tu iPhone/iPad → Archivos → tu juego**. Finder muestra directamente
el contenido de Documents. Según la configuración de iOS, el juego también puede
aparecer en **Archivos → En mi iPhone/iPad**.

| Carpeta o archivo | Qué contiene |
|---|---|
| `save` | Progreso del juego o cuenta |
| `save_device` | Progreso compartido del dispositivo, sólo en ciertos juegos |
| `romfs` | Datos del juego; no son tus partidas |
| `temp` | Archivos temporales |
| `log.txt` | Registro para diagnosticar problemas |

Tu iPad y tu iPhone guardan copias independientes. Una IPA y los archivos
`nxnative-ios.json`/`nxnative-mac.json` son de preparación; **no son un respaldo
del progreso que hay dentro del dispositivo**.

## Al actualizar o renovar la firma

En iPhone/iPad, conserva la misma cuenta, equipo e identificador efectivo de la
app e instala encima. **No desinstales el juego.** Si cambió su contenido,
reemplaza solamente `romfs`; conserva `save` y `save_device`.

Cambiar de cuenta o identificador puede crear otra app y otro contenedor. Por
eso el instalador integrado debe detenerse si no puede mantener esa identidad.
Que caduque la firma no significa que debas borrar el juego: vuelve a firmar e
instalar la misma app para recuperar el acceso a sus datos.

En Mac, la app nueva usa las partidas existentes del mismo Title ID en
Application Support. Renovar la firma de iPhone no sincroniza partidas ni cambia
la versión del juego.

Una carpeta puede no existir antes de abrir el juego y guardar por primera vez.
Estos archivos son los guardados que escribe el propio juego: no son un estado
de emulador ni la memoria que aún no has guardado. Renovar la firma no guarda
por ti una partida que dejaste abierta.

## Antes de copiar o respaldar

1. Guarda desde el propio juego y ciérralo por completo.
2. Conserva juntas `save` y `save_device`, si existe, en una carpeta con fecha y
   nombre del dispositivo dentro de tu carpeta personal del juego, fuera del repo.
3. Conserva también la copia anterior del destino antes de intentar restaurar.

Si no existe `save_device`, puede ser normal. No reemplaces una carpeta con
progreso por otra vacía. Tampoco copies `save.work`, `save.new` ni sus equivalentes:
son carpetas internas de una operación de guardado, no el respaldo confirmado.

**Una copia manual de archivos no está validada como respaldo portable para todos
los juegos.** Algunos necesitan metadatos de nombres de archivo que un ZIP o una
transferencia por Finder puede perder. El futuro exportador tendrá que conservar
esos metadatos y comprobar la restauración. También deben coincidir el juego,
versión, DLC y datos de cuenta; no prometemos que cualquier partida funcione con
cualquier versión o emulador. [Detalles técnicos](saves.md).

## ¿Y los perfiles de controles?

Son preferencias de la app, separadas del progreso. Actualizar la misma app los
conserva, pero copiar solamente `save` no lleva tus perfiles al otro dispositivo.
Aún no tienen exportación ni sincronización entre dispositivos.

Primero dejaremos probado el respaldo y la restauración; después conectaremos
la nube. La API existente es un prototipo y todavía no está conectada al juego.


## Futuro servidor portable

Todavía no elegimos proveedor de nube. La base de la API es independiente del
hosting: Python, HTTP, identidad OIDC configurable y SQLite. Su comando de
respaldo permite trasladar la base a otro servidor conservando versiones y
permisos. [Configuración, respaldo y traslado](../dm/cloud/README.md#portable-hosting-and-migration).
Esto no activa sincronización en los juegos: faltan el inicio de sesión nativo y
la exportación/restauración segura de partidas en cada dispositivo.
