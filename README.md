# Follower Equip Control (FEC)

**Versión actual:** 2.1.0 · **Juego:** Skyrim Special Edition (1.5.97) / Anniversary Edition (1.6.x) · **Licencia:** GPLv3

Follower Equip Control es un plugin nativo SKSE que amplía el menú de intercambio (comercio) con funciones de gestión de seguidores, permitiendo aplicar a los seguidores acciones que normalmente solo el jugador puede realizar: equipar objetos instanciados concretos, consumir pociones y alimentos, aplicar venenos, aprender grimorios, recargar encantamientos, fijar preferencias de equipo para el combate y mucho más.

Además, el mod combate la mayoría de problemas de "estabilidad de equipo" del motor: la IA que desequipa a los seguidores fuera de combate, el auto-equipamiento de la "mejor arma", los atuendos que se reinician al cambiar de zona, los objetos ocultos/inyectados en los inventarios y el saqueo no deseado.

Este repositorio es la distribución del código fuente y el entorno de desarrollo. La página del mod con instrucciones de instalación para usuarios finales está en Nexus Mods:

**https://www.nexusmods.com/skyrimspecialedition/mods/175124**

---

## Índice

1. [Características](#características)
2. [Requisitos](#requisitos)
3. [Instalación](#instalación)
4. [Controles](#controles)
5. [Panel de Control del Mod (MCM)](#panel-de-control-del-mod-mcm)
6. [Configuración (FollowerEquipControl.ini)](#configuración-followerequipcontrolini)
7. [Añadir seguidores manualmente (Actors/\*.ini)](#añadir-seguidores-manualmente-actorsini)
8. [Localización / Traducciones](#localización--traducciones)
9. [Compilación desde el código fuente](#compilación-desde-el-código-fuente)
10. [Solución de problemas](#solución-de-problemas)
11. [Notas técnicas y compatibilidad](#notas-técnicas-y-compatibilidad)
12. [Licencia](#licencia)

---

## Características

### 1. Modo de equipamiento en el menú de comercio

Es la función central del mod. **No es un menú nuevo ni un modificador por separado:** se activa manteniendo la **tecla Mod** y haciendo clic sobre un objeto en la ventana de comercio/contenedor (ContainerMenu de SkyUI).

- Con la tecla Mod **sin pulsar**, todo se comporta exactamente como en vanilla.
- **Pestaña "Dar" (tus objetos → seguidor):** el objeto se transfiere al seguidor **y se equipa automáticamente** en la mano adecuada.
- **Pestaña "Tomar" (objetos del seguidor):** la transferencia se bloquea y el clic **alterna** equipar/desequipar ese objeto en el seguidor, sin sacarlo de su inventario.
- Si se suelta la tecla Mod antes de que se complete la transferencia, la acción pendiente se descarta (fail-closed).

**Tipos de objeto soportados** (cada uno se puede activar o desactivar por separado):

| Tipo                                  | Comportamiento                                                                                                     |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Armas a una mano                      | Alterna entre la mano indicada; si ya está equipada en la otra mano, la intercambia o usa una copia del inventario |
| Armas a dos manos / arcos / ballestas | Siempre a la **mano derecha**                                                                                      |
| Armaduras / ropa                      | Sin mano asignada: alterna equipar/desequipar                                                                      |
| Munición (flechas/bolts)              | Alterna la munición actual del seguidor                                                                            |
| Antorchas                             | Siempre a la **mano izquierda** (sale del slot derecho si ya la lleva)                                             |
| Pergaminos                            | Igual que las armas; los de dos manos van a la derecha                                                             |

**Selección de instancia:** cuando un seguidor tiene varias copias del mismo objeto (distinto temperamento, encantamiento o carga), el mod resuelve la **instancia exacta** de su inventario real: prefiere la que ya está puesta en la mano deseada → una que no esté puesta → cualquier copia. Nunca confía en los punteros clonados de la interfaz, por lo que no puede equipar el "objeto fantasma" de una fila obsoleta.

#### Selección de mano

| Situación                  | Teclado/ratón                                                   | Mando                  |
| -------------------------- | --------------------------------------------------------------- | ---------------------- |
| Mano derecha (por defecto) | Mod + clic                                                      | LT + **A**             |
| Mano izquierda             | Mod + botón de _Ataque/Bloqueo izquierdo_ (clic derecho) + clic | LT + **X**             |
| Arma a dos manos           | Siempre mano derecha                                            | Siempre mano derecha   |
| Antorcha                   | Siempre mano izquierda                                          | Siempre mano izquierda |

El mod también intercepta las funciones Scaleform `AttemptEquip` / `handleInput` de SkyUI para que la elección de mano se registre antes de que se dispare la transferencia (importante en mando y con clics rápidos).

#### Modo cadáver

Configurable con `[CorpseEquipMode]` (activado por defecto). Al **saquear un cadáver** en lugar de un seguidor vivo, Mod + clic alterna el equipamiento sobre el cadáver (armaduras, armas y munición), permitiendo "vestir" cuerpos caídos. Se muestra un indicador propio en la barra inferior.

#### Precedencia de acciones

Cuando el clic con la tecla Mod puede significar varias cosas, el orden fijo es:

1. **Veneno** (si es un veneno y el modo está activo)
2. **Consumible** (pociones, comida, bebidas, ingredientes)
3. **Grimorio** (si enseña un hechizo)
4. **Modo de equipamiento** normal (armas, armadura, munición, antorchas, pergaminos)

Si el objeto no está soportado, se muestra la notificación `unsupported_item` y la transferencia se bloquea (en pestaña "Tomar") o se ignora (en pestaña "Dar").

---

### 2. Consumibles, venenos y grimorios

Estos tres modos **se hacen cargo del clic** (no transfieren el objeto, lo procesan directamente):

#### Consumibles (`[EquipModeConsumableMode]`)

- Mod + clic en una poción, comida, bebida o ingrediente → el objeto **se consume directamente en el seguidor** (no pasa por su inventario).
- Categorías independientes: `EnablePotions`, `EnableFoods`, `EnableDrinks`, `EnableIngredients` (todas por defecto `true`).
- `EnableIngredientDiscoveryForPlayer=false` → opcionalmente, al darle un ingrediente al seguidor, el jugador descubre su **primer efecto** (notificación + sonido de alquimia).

#### Venenos (`[EquipModePoisonMode]`)

- `Mode=applyToWeapon` (por defecto): Mod + clic → aplica el veneno al arma equipada del seguidor.
  - Si se pide mano izquierda pero la mano derecha sostiene un arma a dos manos, se aplica a la derecha.
  - Las **varitas no se pueden envenenar** (aviso correspondiente).
  - `EnablePoisonStacking=false` (por defecto): no deja acumular veneno sobre un arma ya envenenada; permite distinguir venenos distintos y bloquear cuando ya está al tope.
  - `MaxPoisonCharges=100` → 1–99 limita las cargas acumuladas; **100 = ilimitado**.
  - La cantidad de dosis por aplicación respeta el efecto de ventaja `kModPoisonDoseCount`.
- `Mode=consume`: Mod + clic → el seguidor **bebe el veneno** (lo consume).
- `Mode=disable`: el módulo de venenos no se instala.

#### Grimorios (`[EquipModeSpellTomeMode]`)

- Mod + clic en un grimorio → el seguidor **aprende el hechizo**.
  - Si ya lo sabe: aviso `already_known` (limitado a 1,5 s) y no consume el libro.
  - Si lo aprende: sonido de hechizo aprendido y se **consume 1 grimorio**, salvo que actives `DoNotConsumeSpellTomes=true`.

---

### 3. Recarga de encantamientos (`[WeaponEnchantmentRecharge]`)

Permite recargar **armas encantadas del seguidor desde el propio menú de comercio**, usando almas gemas llenas del **inventario del jugador o del seguidor** (da igual en qué pestaña estés).

**Flujo:**

1. Selecciona cualquier arma con encantamiento en el menú de comercio (barra de carga < 100 %).
2. Pulsa la tecla de recarga: **T** (teclado, sin modificador) o **LT + Y** (mando).
3. Se abre un selector en la tarjeta de objeto (ItemCard) con las almas gemas llenas disponibles.
4. Elige una → se aplica la carga y la gema se consume **solo si la carga realmente aumenta** (si no cambia nada, no se consume, como en vanilla).

**Detalles importantes:**

- Las gemas se recopilan de **ambos inventarios** y se agrupan por (FormID, nivel de alma), así que una misma gema con almas de distinto nivel se lista correctamente.
- Las gemas **vacías no aparecen**, y las gemas que no añadirían carga a esa arma concreta se ocultan del selector.
- Las **almas gemas reutilizables** (`KYWD:000ED2F1`) se **vacían** en lugar de eliminarse.
- Las armas **equipadas** se leen/escriben a través del caché de valores de atributos (`RightItemCharge` / `LeftItemCharge`), refrescando la habilidad de la mano tras recargar.
- Para objetos encantados por el jugador, la carga máxima se toma del `ExtraEnchantment` del objeto.
- Indicador opcional en la barra inferior con el botón "$Charge" (`EnableUIIndicator`).
- Si no hay gemas llenas: aviso "No items to charge enchantment" + sonido de fallo, y no se abre el selector.

**Opciones de visualización del selector** (`AdvancedSoulGemDisplay`, por defecto activo):

| Opción                     | Valores                                    | Por defecto  | Efecto                                                                                   |
| -------------------------- | ------------------------------------------ | ------------ | ---------------------------------------------------------------------------------------- |
| `ShowStackCount`           | true/false                                 | `true`       | Sufijo "(3)" con el número de gemas apiladas                                             |
| `ContainedSoulDisplayMode` | `disable` / `lower_only` / `always`        | `lower_only` | Sufijo tipo "(Grand)" cuando la gema no está llena a su capacidad                        |
| `SourceDisplayMode`        | `disable` / `follower` / `player` / `both` | `disable`    | Etiqueta " \| Nombre" indicando de quién es la gema                                      |
| `SoulGemSortMode`          | `name` / `soul_asc` / `soul_desc`          | `soul_asc`   | Orden: reutilizables primero, luego por alma contenida, capacidad, gema negra, origen... |

---

### 4. Preferencias de equipo y equipamiento en combate

#### Captura de preferencias (`[CombatEquipPreference]`)

El mod aprende **qué quiere el jugador** que lleve cada seguidor:

- Al equipar/desequipar **manualmente** un objeto en el menú de comercio con la tecla Mod, esa elección se guarda como **preferencia de combate** (y también como instantánea de atuendo y de objeto de mano, según la función).
- Al abrir el comercio con un seguidor **por primera vez**, si no hay preferencias, el equipo actual se siembra como línea base (así nunca se le fuerza a ir desarmado sin más).
- **14 categorías**: mano derecha, mano izquierda, escudo, arma a dos manos, arco, ballesta, flecha, bolt, varita derecha, varita izquierda, pergamino derecha/izquierda/dos manos y **casco**.
- La firma de instancia (nombre personalizado, calidad de temple, encantamiento, capacidad de carga) se guarda con la preferencia, de modo que se prefiere **ese ejemplar exacto**, no solo el mismo objeto base (`EnableInstanceAlign=true`).
- Opciones: `EnableClearPreferencesOnUnequip` / `EnableClearLeftHandPreferenceOnUnequip` (borrar la preferencia al desequipar; por defecto desactivadas).

#### Sesgo de puntuación (`EnableScoring=true`)

El motor del juego decide qué equipa un NPC en combate con `CombatInventoryItem::CalculateScore`. FEC **infla la puntuación** del objeto preferido en ese cálculo (no fuerza nada):

- **+600** para categorías generales (derecha, dos manos, arco, ballesta, munición, varitas, pergaminos derechos…)
- **+400** para categorías de mano izquierda (mano izquierda, escudo, varita y pergamino izquierdos)

Cantidades deliberadamente altas para dominar los empates del cálculo vanilla. Solo actúa sobre seguidores en alcance, con el arma desenvainada o en combate, y solo si el objeto está realmente en el inventario (una varita descargada o un arco sin munición no recibe bonus).

#### Imposición en combate (`[CombatEquipEnforcement]`)

Cuando la IA intenta cambiar el equipo del seguidor durante el combate, el mod **intercepta el cambio** en los hooks de `ActorEquipManager`:

| Opción                            | Por defecto | Efecto                                                                                                                                                         |
| --------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EnableMeleeEnforcement`          | `true`      | Si la IA intenta equipar un arma (2H, 1H o escudo) con el arma desenvainada, se **vuelve a poner la preferencia** del jugador y se bloquea el intento de la IA |
| `EnableMeleeEnforcementEmptyHand` | `false`     | Si no hay preferencia guardada, dejar las manos **vacías** en lugar de dejar lo que la IA eligió                                                               |
| `EnableAmmoPreference`            | `true`      | Si la IA cambia las flechas/bolts durante combate a distancia, se **restaura la munición preferida** (si está en el inventario)                                |

También se bloquea el desequipamiento por IA de un arma preferida mientras el seguidor está en combate/devainado, y se re-equipa la munición preferida si la IA la suelta (tarea diferida al siguiente frame).

#### Iconos de preferencia

Los objetos que son la preferencia guardada reciben un icono en la lista del menú de comercio (ver [Iconos e indicadores de la interfaz](#14-iconos-e-indicadores-de-la-interfaz)).

---

### 5. Restauración de equipo (`[CombatEquipRestore]`)

| Opción                         | Por defecto | Qué hace                                                                                                                                                                                               |
| ------------------------------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `EnableRestorePreCombatOnExit` | `true`      | **Al terminar el combate**, restaura el arma de mano derecha, la de mano izquierda/escudo y la munición que llevaba el seguidor **antes** del combate (snapshots con firma de instancia)               |
| `EnableHeadgearAutoEquip`      | `false`     | **Al empezar el combate**, equipa el casco/capucha/diadema preferido; **al terminar**, restaura exactamente lo que llevaba puesto antes (incluidas varias piezas a la vez: cabeza + cabello + diadema) |
| `EnableInfiniteAmmo`           | `false`     | El seguidor **nunca consume flechas ni bolts** (hook `UseAmmo`; no afecta al jugador ni a armas vinculadas)                                                                                            |

Notas:

- Las **armas vinculadas** (conjuración) se respetan siempre: nunca se capturan, restauran ni se les compite.
- Si el seguidor está en combate o el menú de comercio está abierto cuando toca restaurar, el reintento se pospone (hasta 5 intentos) y se reconcilia después (3 intentos).
- Con `EnableHeadgearAutoEquip=true`, Mod + clic con **mano izquierda** sobre un casco **guarda o borra** su preferencia de casco de combate en lugar de equiparlo (con mano derecha se equipa normalmente).
- Los snapshots se guardan en la partida (registros `CEPC` y `CHGT`).

---

### 6. Intercambio rápido (Quick Trade) (`[QuickTrade]`)

Abre el menú de comercio de un seguidor **directamente**, sin pasar por diálogo: mira al actor y pulsa **tecla Mod de Quick Trade + Activar** (por defecto: **tecla de Sprint** + E / botón de activar).

- La tecla Mod de Quick Trade es `QuickTradeKeyDik=0` / `QuickTradeGamepadKey=0` → **0 = usar la tecla de Sprint del motor** (Shift por defecto). Nótese que es distinta de la tecla Mod del menú de comercio (Ctrl izquierdo).
- No inicia diálogo real (no empuja paquetes de IA); abre el contenedor en modo NPC con una sesión de diálogo simulada para que el motor gestione el cierre automático en combate/muerte/cambio de zona.
- **Rechaza** la apertura si: el actor está en combate, hostil al jugador, en _bleedout_, ya está hablando contigo o hay una escena guionizada activa.
- Categorías configurables por separado: seguidores actuales, ex-seguidores, actores de listas de inclusión, invocaciones, actores no humanoides (`kNone`, solo comercio) y **monturas**.

| Clave                                | Por defecto                                                         |
| ------------------------------------ | ------------------------------------------------------------------- |
| `EnableQuickTrade`                   | `true` (maestro)                                                    |
| `EnableQuickTradeForFollowers`       | `true`                                                              |
| `EnableQuickTradeForFormerFollowers` | `true`                                                              |
| `EnableQuickTradeForInclusionActors` | `true`                                                              |
| `EnableQuickTradeForPlayerSummons`   | `true`                                                              |
| `EnableQuickTradeForKNoneActors`     | `true`                                                              |
| `EnableQuickTradeForMounts`          | `true` (montura del jinete en alcance + última montura del jugador) |
| `QuickTradeAllWorldMounts`           | `false` (con `true`, cualquier montura del mundo)                   |

---

### 7. Sincronización de atuendos (Outfit Sync) (`[OutfitSync]`)

Evita que atuendos externos (SPID, mods de ropa, reinicios de inventario, cambios de zona) se lleven puesto el equipo del seguidor:

| Opción                             | Por defecto | Efecto                                                                                                                                                            |
| ---------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EnableUpdateNpcOutfitSuppression` | `true`      | Sopla el `UpdateNPCOutfit` del motor: si el atuendo "oficial" del NPC no cambió, **se ignora el reinicio** y el seguidor conserva lo que llevaba                  |
| `EnableOutfitSnapshotRestore`      | `true`      | Guarda una instantánea por slot (objeto + instancia exacta) y la **restaura** si algo la quitó; nunca restaura en combate ni con el menú abierto                  |
| `AllowOutfitChanges`               | `true`      | Si un sistema externo asigna un **nuevo** `BGSOutfit` real (o el NPC no tenía atuendo asignado, tipo Inigo), se permite el cambio y se reconstruye la instantánea |

La preferencia de mano también se restaura al cerrar el menú (`HandItemRestore`, ver §9).

---

### 8. Elementos ocultos, atuendos e inyección de objetos

#### Elementos ocultos (`[HiddenItems]`)

Al abrir el comercio con un seguidor, el mod sanea su inventario para que la IA evalúe solo objetos utilizables:

| Clave                             | Por defecto | Efecto                                                                                                                                        |
| --------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `EnableNonPlayableItems`          | `true`      | Maestro del saneado de objetos no jugables                                                                                                    |
| `RemoveHiddenWeapon`              | `true`      | Elimina armas/escudos no jugables (no se recuperan si luego desactivas la opción)                                                             |
| `RemoveHiddenAmmo`                | `true`      | Elimina munición no jugable                                                                                                                   |
| `RemoveHiddenArmor`               | `false`     | Eliminar armaduras no jugables (por defecto **no**, para no tocar objetos de física HDT-SMP ni de misiones)                                   |
| `EnableOutfitItems`               | `true`      | Maestro de la revelación de objetos de atuendo                                                                                                |
| `EnableRevealDefaultOutfitItems`  | `true`      | Los objetos con etiqueta `ExtraOutfitItem` del atuendo por defecto se **revelan** en la lista (y se eliminan las copias redundantes sin usar) |
| `EnableRevealExternalOutfitItems` | `true`      | Ídem para atuendos distribuidos externamente (estilo SPID)                                                                                    |

Siempre se respetan: objetos de misión, armaduras sin modelo (física), armas vinculadas, puños, flechas vinculadas y objetos con peso cero.

#### Bloqueo de inyección (`[ItemInjectionBlocking]`)

| Clave                      | Por defecto | Efecto                                                                                                           |
| -------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------------- |
| `EnableLeveledItemBlocker` | `false`     | Impide que el motor inyecte objetos de listas de nivel (armas, munición, pociones…) en inventarios de seguidores |
| `EnableOutfitItemBlocker`  | `false`     | Impide que se inyecte la armadura del atuendo por defecto en el inventario del seguidor                          |

---

### 9. Estabilidad del equipo: bloqueo de auto-equipamiento (`[AutoEquipBlocking]` y `[EquipGate]`)

#### Auto-equip bloqueado (`[AutoEquipBlocking]`)

| Clave                                 | Por defecto | Problema que resuelve                                                                                                                         |
| ------------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `EnableNonCombatEquipBlocker`         | `true`      | Fuera de combate, la IA deja de **intercambiar equipo "por su cuenta"** (los cambios aleatorios mientras camina)                              |
| `EnableBestWeaponAutoEquipSuppressor` | `true`      | El vanilla no intenta **auto-equipar la "mejor arma"** cuando le quitas/armas un arma en el comercio                                          |
| `EnableHandItemRestore`               | `true`      | **Preserva la selección manual** de mano derecha, mano izquierda y munición a través de refrescos de atuendo, pausas/cargas y cambios de zona |

> `EnableHandItemRestore` requiere que **también** esté activo `EnableNonCombatEquipBlocker` para funcionar.

#### Puerta de equipamiento (`[EquipGate]`) — opcional, desactivada por defecto

Un sistema "denegar por defecto" sobre los hooks de `ActorEquipManager`:

| Clave                   | Por defecto | Efecto                                                                                                                                |
| ----------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `EnableEquipBlocking`   | `false`     | Bloquea **todo** equipamiento en los seguidores en alcance salvo el que hace el propio mod (permisos de un solo uso y bypass propios) |
| `EnableUnequipBlocking` | `false`     | Ídem para desequipar                                                                                                                  |
| `NeverBlockTorchEquip`  | `true`      | Exime siempre las antorchas jugables                                                                                                  |

**Nunca bloquea:** al jugador, con el menú de comercio abierto, en combate o con el arma desenvainada, munición, armas vinculadas, hechizos, ni las acciones propias del mod. Pensado para modlistas muy conflictivas; en uso normal no hace falta activarlo.

---

### 10. Bloqueo de saqueo (`[LootBlocking]`)

| Clave                        | Por defecto | Qué bloquea                                                                                                                                    |
| ---------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `EnablePreventCombatLoot`    | `true`      | Que los seguidores **saqueen armas del campo de batalla** durante el combate (antes de que el árbol de comportamiento "adquiera arma" empiece) |
| `EnablePreventContainerLoot` | `false`     | Que los seguidores activen y **vacien contenedores** y **cadáveres** por su cuenta (solo armas/munición en cadáveres)                          |
| `EnablePreventPickupObject`  | `false`     | Que los seguidores **recojan objetos sueltos** del mundo por su cuenta (pathing de IA)                                                         |

En todos los casos se permite el saqueo **ordenado por el jugador** (paquetes temporales de comando `FF`), y solo se aplica a actores en alcance.

---

### 11. Estadísticas del seguidor en el menú de comercio (`[StatsDisplay]`)

Sustituye la barra inferior de SkyUI por las **estadísticas del seguidor**: peso/equipaje actual, oro, y barras de salud, magia y resistencia (el peso se recalcula del inventario real si el caché del motor está corrupto).

`EnableFollowerStatsInTradeMenu`:

| Valor           | Efecto                                                          |
| --------------- | --------------------------------------------------------------- |
| `follower_side` | **Por defecto.** Solo en la pestaña "Tomar" (lado del seguidor) |
| `always`        | En ambas pestañas                                               |
| `disable`       | Comportamiento vanilla                                          |

---

### 12. Iconos e indicadores de la interfaz

#### Botón en la barra inferior

Mientras comercias con un actor elegible y tienes un objeto seleccionado **sin** mantener la tecla Mod, aparece un botón-recordatorio en la barra de navegación de SkyUI con el texto localizado según el tipo de actor:

| Actor                       | Texto por defecto | Clave de personalización          |
| --------------------------- | ----------------- | --------------------------------- |
| Seguidor                    | "Equip Follower"  | `ModKeyIndicatorText`             |
| Invocación                  | "Equip Summon"    | `SummonIndicatorText`             |
| Actor de lista de inclusión | "Equip Target"    | `InclusionIndicatorText`          |
| Cadáver                     | "Equip Corpse"    | `[CorpseEquipMode] IndicatorText` |

(`EnableModKeyIndicator=true` por defecto; texto vacío = usar el texto localizado.)

#### Iconos en la lista de objetos

Pequeños SWF cargados desde `Interface/FollowerEquipControl/`, colocados tras cualquier icono existente (SkyUI, DIII, etc.) sin solaparse:

| Icono                      | SWF                                                              | Se muestra cuando                                                   |
| -------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------- |
| Preferencia de combate     | `melee.swf`, `ranged.swf`, `ammo.swf`, `scroll.swf`, `staff.swf` | El objeto es la preferencia guardada en alguna de las 13 categorías |
| Casco de combate           | `headgear.swf`                                                   | Es el casco preferido (con `EnableHeadgearAutoEquip`)               |
| Atuendo restaurable        | `marked.swf`                                                     | Está en la instantánea del atuendo (Outfit Sync)                    |
| Objeto de mano restaurable | `marked.swf`                                                     | Está en la instantánea de mano/munición (HandItemRestore)           |

Configuración en `[IconAppearance]`: `EnableIconIndicator=true`, `EnableCombatEquipIcon/EnableHeadgearIcon/EnableOutfitSyncIcon/EnableHandItemIcon=true`, `EnableCustomization=true`, `IconSize=12`, `GapAfterText=8`, `GapAfterIcon=8`, `FecIconSpacing=8`.

---

### 13. Correcciones de motor y SkyUI (`[EngineFixes]` / `[SkyUIFixes]`)

| Clave                       | Por defecto | Problema que corrige                                                                                                                                                         |
| --------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `EnableStaleWeightCacheFix` | `true`      | Los ítems aparecían **grisados** en la pestaña "Dar" cuando el peso total en caché del inventario estaba corrupto/obsoleto; recalcula el peso real recorriendo el inventario |
| `EnableZeroWeightFix`       | `true`      | Con objetos de **peso exacto 0** (oro, ganzúas…) SkyUI forzaba "coger todo" y no dejaba elegir cantidad; se hace pasar por un peso de 0,000001 (se muestra 0,0)              |
| `EnableQuantityMenuBlocker` | `true`      | Suprime el **deslizador de cantidad** de SkyUI durante las acciones con tecla Mod y el modo de equipamiento de SkyUI, donde siempre se actúa sobre un solo objeto            |

---

### 14. ¿A quién afecta el mod? (ActorScope)

El mod distingue varias categorías de actor, con puertas independientes:

| Categoría            | Definición                                                                                                                  | Puertas por defecto                   |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| Seguidor actual      | Bandera de compañero del motor + persistencia                                                                               | Siempre en alcance                    |
| Ex-seguidor          | Visto por el mod pero ya no es compañero                                                                                    | `AffectFormerFollowers=true`          |
| Invocaciones         | Invocados, sirvientes muertos, reanimados dirigidos por el jugador                                                          | `IncludePlayerSummons=true`           |
| Actores de inclusión | Coincidencias en `Actors/*.ini`                                                                                             | `IncludeInclusionActors=true`         |
| Cadáveres            | Solo modo cadáver / saneado                                                                                                 | `[CorpseEquipMode]`                   |
| Monturas             | Solo Intercambio Rápido                                                                                                     | `EnableQuickTradeForMounts=true`      |
| Actores `kNone`      | Sin ranura de mano ni tipos de arma (lobos, atronacos, caballos…) → **sin funciones de equipamiento**, solo comercio rápido | `EnableQuickTradeForKNoneActors=true` |

- La capacidad de equipamiento (`kFull`) se calcula por **raza**: ranura de mano + tipo de arma real + capacidad de recoger objetos/cuerpo. Todo lo demás queda fuera de las funciones de equipamiento.
- Cualquier actor se puede **excluir individualmente** desde el Panel de Control (se guarda en la partida, registro `ACDS`), y los compañeros se **matriculan automáticamente** la primera vez que abres su comercio.
- Un actor puede ser excluido de todo el mod sin perder sus datos guardados, o eliminarse por completo (borra todos sus registros).

---

## Requisitos

### En tiempo de ejecución

- Skyrim Special Edition (1.5.97) o Anniversary Edition (1.6.x / 1.7.x). Compilado contra CommonLibSSE-NG v12.1.0, que soporta el formato 5 de Address Library usado por 1.7.x.
- [SKSE64](https://skse.silverlock.org/)
- [Address Library for SKSE Plugins](https://www.nexusmods.com/skyrimspecialedition/mods/32444) (versión SE o AE según tu runtime)
- [SkyUI](https://www.nexusmods.com/skyrimspecialedition/mods/2347) — **obligatorio** (el mod opera sobre el ContainerMenu de SkyUI)
- [SKSE Menu Framework 3](https://github.com/QTR-Modding/SKSE-Menu-Framework-3) — **opcional**. Necesario para el Panel de Control in-game; sin él, toda la configuración se hace por INI.

**Skyrim VR no está soportado.** El plugin se niega a cargar en VR salvo que se compile expresamente con `-DFEC_ENABLE_UNSUPPORTED_VR=ON` (modo experimental, puede requerir la Address Library de VR).

### Para compilar

- Visual Studio o Build Tools con la carga de trabajo de C++ (MSVC, C++23)
- CMake 3.21 o superior
- Ninja
- Git
- vcpkg
- CommonLibSSE-NG (submódulo)

---

## Instalación

1. Instala los requisitos obligatorios (SKSE64, Address Library, SkyUI).
2. Descarga e instala el archivo del mod con tu gestor de modos (Mod Organizer 2, Vortex) o cópialo manualmente en tu carpeta `Data`. Asegúrate de que los archivos queden así:

```text
Data/
├── Interface/
│   └── FollowerEquipControl/
│       ├── ammo.swf
│       ├── headgear.swf
│       ├── marked.swf
│       ├── melee.swf
│       ├── ranged.swf
│       ├── scroll.swf
│       └── staff.swf
└── SKSE/
    └── Plugins/
        ├── FollowerEquipControl.dll
        ├── FollowerEquipControl.ini
        └── FollowerEquipControl/
            ├── Actors/
            │   ├── Example.ini
            │   ├── ManageSeranaEarly.ini
            │   └── PlayerSpouses.ini
            └── Localization/
                └── en.ini
```

3. (Opcional) Instala **SKSE Menu Framework 3** para poder configurar el mod desde dentro del juego.
4. Inicia el juego con SKSE. El archivo de registro se genera en:
   `Documentos/My Games/Skyrim Special Edition/SKSE/FollowerEquipControl.log`

**Actualizar:** sobrescribe los archivos (el `.ini` de usuario se conserva si el instalador/archivo lo permite; si no, guarda tus cambios antes). Los datos de preferencias viven **en tu partida** (ver [Notas técnicas](#notas-técnicas-y-compatibilidad)).

**Desinstalar:** elimina los archivos del mod. La serialización de SKSE revierte automáticamente los registros guardados por el plugin al detectar su ausencia.

---

## Controles

### Teclado y ratón

| Acción                                             | Tecla por defecto                                                   |
| -------------------------------------------------- | ------------------------------------------------------------------- |
| Modo de equipamiento (modificador)                 | **Ctrl izquierdo** (`ModKeyDik=29`)                                 |
| Equipar en **mano derecha**                        | Mod + clic en el objeto                                             |
| Equipar en **mano izquierda**                      | Mod + _Ataque/Bloqueo izquierdo_ (clic derecho) + clic              |
| Alternar equipamiento (pestaña "Tomar" / cadáver)  | Mod + clic                                                          |
| **Recargar** encantamiento de la arma seleccionada | **T** (`RechargeKeyDik=20`, sin modificador)                        |
| **Intercambio rápido** con el actor mirado         | **Tecla de Sprint** (Shift) + **E**                                 |
| Modo de equipamiento nativo de SkyUI               | Se conserva la tecla de SkyUI salvo que cambies `SkyuiEquipModeKey` |

### Mando

| Acción                             | Combinación por defecto                |
| ---------------------------------- | -------------------------------------- |
| Modo de equipamiento (modificador) | **LT** (`GamepadModKey=280`)           |
| Equipar en **mano derecha**        | LT + **A** (`GamepadRightHandKey=276`) |
| Equipar en **mano izquierda**      | LT + **X** (`GamepadLeftHandKey=278`)  |
| **Recargar** encantamiento         | **LT + Y** (`GamepadRechargeKey=279`)  |
| **Intercambio rápido**             | Botón de **Sprint** + **Activar**      |

### Notas sobre los códigos de tecla

- `ModKeyDik` y `RechargeKeyDik` usan **códigos de escaneo DirectInput (DIK)**: `29` = Ctrl izquierdo, `42` = Shift izquierdo, `56` = Alt izquierdo, `20` = T, `1` = Esc, etc.
- Los códigos de mando usan el rango unificado de SKSE (266–281): `276` = A, `277` = B, `278` = X, `279` = Y, `280` = LT, `281` = RT.
- **`0` siempre significa "usar la tecla por defecto del motor"** (para Quick Trade: la tecla de Sprint).
- Todos los controles se pueden cambiar por INI; el Panel de Control permite cambiarlos visualmente y aplicarlos sin reiniciar.

---

## Panel de Control del Mod (MCM)

Requiere **SKSE Menu Framework 3**. Se abre desde su _Mod Control Panel_, con el título **"Follower Equip Control"**.

### Estructura

**Sección ACTOR MANAGEMENT**

- **Preferences & Spell List** — explorador por actor con pestañas coloreadas por categoría (seguidor gris, invocación azul claro, inclusión verde, excluido rojo) y filtros:
  - **PREFERENCES:** tabla de solo lectura con las 14 categorías de preferencia (mano derecha/izquierda, escudo, dos manos, arco, ballesta, flecha, bolt, varitas, pergaminos, casco) y la firma de instancia (nombre personalizado, temple, encantamiento, capacidad de carga), más una referencia de "borrado cruzado".
  - **SPELL LIST:** lista de hechizos del seguidor con botones **FORGET / REMEMBER** (supresión de lanzamiento de IA, guardada en la partida como `SSPL`), insignias de hechizo base / de lanzamiento, y panel de detalle (escuela, nivel, magnitud, duración, área, coste).
  - Acciones por actor: **Exclude** (excluir del mod conservando datos), **Re-include** y **Remove** (borrar todos sus registros), con confirmación.

**Sección SETTINGS** — 8 páginas:

| Página              | Contenido                                                                                                                                                                        |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **System**          | Activar/desactivar el mod, notificaciones, sonidos, nivel de registro                                                                                                            |
| **Scope & Access**  | Alcance de actores (ex-seguidores, inclusiones, invocaciones) + Intercambio rápido                                                                                               |
| **Controls & UI**   | Controles de teclado y mando, indicadores de botón, indicadores de icono (tamaño, espaciado)                                                                                     |
| **Equip Mode**      | Objetos equipables, consumibles, venenos, grimorios                                                                                                                              |
| **Combat Equip**    | Preferencias (prioridad, instancia exacta, borrado al desequipar), imposición (melee, manos vacías, munición), auto-equip y restauración (pre-combate, casco, munición infinita) |
| **Equip Stability** | Outfit Sync, elementos ocultos, inyección de objetos, saqueo, auto-equip bloqueado, Equip Gate                                                                                   |
| **Extra Features**  | Recarga de encantamientos, estadísticas del seguidor, modo cadáver                                                                                                               |
| **Fixes**           | Correcciones de motor y de SkyUI                                                                                                                                                 |

### Barra de herramientas

Cada página de ajustes tiene:

- **REVERT** — descartar cambios sin guardar y recargar los últimos valores guardados.
- **SAVE** — escribir el INI **y aplicar en caliente** (nivel de registro, modos de veneno/consumible, indicadores, interruptor maestro, etc.). Si el mod está desactivado, SAVE muestra un aviso rojo recordándote activarlo en _System_.
- **RESET** — restablecer **solo esa página** a los valores por defecto (luego pulsa SAVE para conservarlo). Cada fila individual también tiene su propio "restablecer".

Cada opción incluye texto de ayuda con su valor por defecto anotado.

> Sin SKSE Menu Framework, el Panel de Control no existe: edita `FollowerEquipControl.ini` manualmente (los cambios requieren reiniciar el juego).

---

## Configuración (FollowerEquipControl.ini)

Ruta: `Data/SKSE/Plugins/FollowerEquipControl.ini`
Se lee **al cargar el plugin** → los cambios por INI requieren **reiniciar**; desde el Panel de Control se aplican **al instante**. Las claves no distinguen mayúsculas.

### `[Core]` / `[UIFeedback]` / `[Logging]`

| Clave                 | Por defecto | Descripción                                                                                       |
| --------------------- | ----------- | ------------------------------------------------------------------------------------------------- |
| `EnableMod`           | `true`      | Maestro de todas las funciones (el Panel de Control se mantiene instalado para poder reactivarlo) |
| `EnableNotifications` | `true`      | Avisos cortos en pantalla cuando el mod actúa                                                     |
| `EnableUISounds`      | `true`      | Sonidos de UI de vanilla al actuar                                                                |
| `LogLevel`            | `info`      | `trace`, `debug`, `info`, `warn`, `error`, `critical`, `off`                                      |

### `[ActorScope]`

| Clave                    | Por defecto | Descripción                                 |
| ------------------------ | ----------- | ------------------------------------------- |
| `AffectFormerFollowers`  | `true`      | Incluir ex-seguidores                       |
| `IncludeInclusionActors` | `true`      | Incluir actores de `Actors/*.ini`           |
| `IncludePlayerSummons`   | `true`      | Incluir invocaciones/sirvientes del jugador |

### `[QuickTrade]`

Ver [Intercambio rápido](#6-intercambio-rápido-quick-trade-quicktrade).

### `[KeyboardControls]` / `[GamepadControls]`

| Clave                  | Por defecto      | Descripción                                                                 |
| ---------------------- | ---------------- | --------------------------------------------------------------------------- |
| `ModKeyDik`            | `29` (Ctrl izq.) | Tecla Mod del comercio (DIK)                                                |
| `SkyuiEquipModeKey`    | `0`              | Anula la tecla del modo equipamiento de SkyUI (`0` = conservar la de SkyUI) |
| `QuickTradeKeyDik`     | `0`              | Tecla Mod de Intercambio Rápido (`0` = tecla de Sprint)                     |
| `GamepadModKey`        | `280` (LT)       | Modificador en mando                                                        |
| `GamepadRightHandKey`  | `276` (A)        | Equipar mano derecha                                                        |
| `GamepadLeftHandKey`   | `278` (X)        | Equipar mano izquierda                                                      |
| `QuickTradeGamepadKey` | `0`              | Tecla Mod de Intercambio Rápido en mando (`0` = Sprint)                     |

### `[ButtonIndicators]` / `[IconAppearance]`

| Clave                                                                                              | Por defecto | Descripción                                     |
| -------------------------------------------------------------------------------------------------- | ----------- | ----------------------------------------------- |
| `EnableModKeyIndicator`                                                                            | `true`      | Mostrar botón-recordatorio en la barra inferior |
| `ModKeyIndicatorText` / `InclusionIndicatorText` / `SummonIndicatorText` / `EquipModeTextOverride` | (vacío)     | Textos propios (vacío = localizado por defecto) |
| `EnableIconIndicator`                                                                              | `true`      | Mostrar iconos en la lista                      |
| `EnableCombatEquipIcon` / `EnableHeadgearIcon` / `EnableOutfitSyncIcon` / `EnableHandItemIcon`     | `true`      | Iconos por tipo                                 |
| `EnableCustomization`                                                                              | `true`      | Permitir personalizar tamaño/espaciado          |
| `IconSize`                                                                                         | `12`        | Tamaño del icono                                |
| `GapAfterText` / `GapAfterIcon`                                                                    | `8` / `8`   | Huecos tras el texto y tras el icono            |
| `FecIconSpacing`                                                                                   | `8`         | Separación entre iconos FEC                     |

### `[EquipModeItems]` / `[EquipModeConsumableMode]` / `[EquipModePoisonMode]` / `[EquipModeSpellTomeMode]`

| Clave                                                                              | Por defecto     | Descripción                                           |
| ---------------------------------------------------------------------------------- | --------------- | ----------------------------------------------------- |
| `Enable`                                                                           | `true`          | Maestro del modo de equipamiento                      |
| `EnableWeapons` / `EnableArmor` / `EnableAmmo` / `EnableTorches` / `EnableScrolls` | `true`          | Tipos de objeto equipables                            |
| `EnableConsumableMode`                                                             | `true`          | Maestro de consumibles                                |
| `EnablePotions` / `EnableFoods` / `EnableDrinks` / `EnableIngredients`             | `true`          | Categorías de consumibles                             |
| `EnableIngredientDiscoveryForPlayer`                                               | `false`         | El jugador descubre el 1er efecto al dar ingredientes |
| `Mode`                                                                             | `applyToWeapon` | `applyToWeapon` \| `consume` \| `disable`             |
| `EnablePoisonStacking`                                                             | `false`         | Acumular veneno sobre arma ya envenenada              |
| `MaxPoisonCharges`                                                                 | `100`           | Tope de cargas (1–99; **100 = ilimitado**)            |
| `EnableSpellTomeMode`                                                              | `true`          | Maestro de grimorios                                  |
| `DoNotConsumeSpellTomes`                                                           | `false`         | No consumir el grimorio al aprender                   |

### `[CombatEquipPreference]` / `[CombatEquipEnforcement]` / `[CombatEquipRestore]`

| Clave                                    | Por defecto | Descripción                                               |
| ---------------------------------------- | ----------- | --------------------------------------------------------- |
| `EnableScoring`                          | `true`      | Sesgo de puntuación de combate (+600/+400)                |
| `EnableInstanceAlign`                    | `true`      | Preferir la instancia exacta (temple/encantamiento/carga) |
| `EnableClearPreferencesOnUnequip`        | `false`     | Borrar preferencia al desequipar                          |
| `EnableClearLeftHandPreferenceOnUnequip` | `false`     | Borrar solo la de mano izquierda                          |
| `EnableMeleeEnforcement`                 | `true`      | Imponer preferencia melee frente a la IA en combate       |
| `EnableMeleeEnforcementEmptyHand`        | `false`     | Sin preferencia → manos vacías                            |
| `EnableAmmoPreference`                   | `true`      | Imponer munición preferida                                |
| `EnableRestorePreCombatOnExit`           | `true`      | Restaurar equipo pre-combate al salir                     |
| `EnableHeadgearAutoEquip`                | `false`     | Casco preferido al entrar en combate / restaurar al salir |
| `EnableInfiniteAmmo`                     | `false`     | Munición infinita para seguidores                         |

### `[OutfitSync]` / `[HiddenItems]` / `[ItemInjectionBlocking]`

| Clave                              | Por defecto | Descripción                                 |
| ---------------------------------- | ----------- | ------------------------------------------- |
| `EnableUpdateNpcOutfitSuppression` | `true`      | Ignorar reinicios de atuendo del motor      |
| `EnableOutfitSnapshotRestore`      | `true`      | Restaurar instantánea de atuendo            |
| `AllowOutfitChanges`               | `true`      | Permitir cambios reales de atuendo externos |
| `EnableNonPlayableItems`           | `true`      | Maestro del saneado de objetos no jugables  |
| `RemoveHiddenArmor`                | `false`     | Eliminar armadura no jugable                |
| `RemoveHiddenWeapon`               | `true`      | Eliminar arma no jugable                    |
| `RemoveHiddenAmmo`                 | `true`      | Eliminar munición no jugable                |
| `EnableOutfitItems`                | `true`      | Maestro de revelado de atuendos             |
| `EnableRevealDefaultOutfitItems`   | `true`      | Revelar objetos del atuendo por defecto     |
| `EnableRevealExternalOutfitItems`  | `true`      | Revelar objetos de atuendo externos         |
| `EnableOutfitItemBlocker`          | `false`     | Bloquear inyección de armadura de atuendo   |
| `EnableLeveledItemBlocker`         | `false`     | Bloquear inyección de listas de nivel       |

### `[LootBlocking]` / `[AutoEquipBlocking]` / `[EquipGate]`

| Clave                                 | Por defecto | Descripción                                                |
| ------------------------------------- | ----------- | ---------------------------------------------------------- |
| `EnablePreventCombatLoot`             | `true`      | Bloquear saqueo de armas en combate                        |
| `EnablePreventContainerLoot`          | `false`     | Bloquear saqueo de contenedores y cadáveres                |
| `EnablePreventPickupObject`           | `false`     | Bloquear recogida de objetos sueltos                       |
| `EnableNonCombatEquipBlocker`         | `true`      | Bloquear cambios de equipo por IA fuera de combate         |
| `EnableHandItemRestore`               | `true`      | Preservar manos y munición elegidas (requiere la anterior) |
| `EnableBestWeaponAutoEquipSuppressor` | `true`      | Suprimir auto-equip de "mejor arma" al transferir          |
| `EnableEquipBlocking`                 | `false`     | Puerta deny-by-default de equipamiento                     |
| `EnableUnequipBlocking`               | `false`     | Puerta deny-by-default de desequipamiento                  |
| `NeverBlockTorchEquip`                | `true`      | Nunca bloquear antorchas                                   |

### `[WeaponEnchantmentRecharge]` / `[StatsDisplay]` / `[CorpseEquipMode]` / `[EngineFixes]` / `[SkyUIFixes]`

| Clave                            | Por defecto     | Descripción                                      |
| -------------------------------- | --------------- | ------------------------------------------------ |
| `EnableRecharge`                 | `true`          | Maestro de recarga                               |
| `RechargeKeyDik`                 | `20` (T)        | Tecla de recarga (DIK)                           |
| `GamepadRechargeKey`             | `279` (Y)       | Tecla de recarga en mando (con LT pulsado)       |
| `EnableUIIndicator`              | `true`          | Botón "$Charge" en la barra inferior             |
| `AdvancedSoulGemDisplay`         | `true`          | Opciones avanzadas del selector de gemas         |
| `ShowStackCount`                 | `true`          | Mostrar "(n)" de apilado                         |
| `ContainedSoulDisplayMode`       | `lower_only`    | `disable` \| `lower_only` \| `always`            |
| `SourceDisplayMode`              | `disable`       | `disable` \| `follower` \| `player` \| `both`    |
| `SoulGemSortMode`                | `soul_asc`      | `name` \| `soul_asc` \| `soul_desc`              |
| `EnableFollowerStatsInTradeMenu` | `follower_side` | `disable` \| `follower_side` \| `always`         |
| `Enable` (CorpseEquipMode)       | `true`          | Modo cadáver                                     |
| `IndicatorText`                  | (vacío)         | Texto del indicador de cadáver                   |
| `EnableStaleWeightCacheFix`      | `true`          | Corregir peso en caché obsoleto (ítems grisados) |
| `EnableQuantityMenuBlocker`      | `true`          | Suprimir deslizador de cantidad                  |
| `EnableZeroWeightFix`            | `true`          | Permitir cantidades con objetos de peso 0        |

---

## Añadir seguidores manualmente (Actors/\*.ini)

Cualquier `.ini` dentro de `Data/SKSE/Plugins/FollowerEquipControl/Actors/` se carga de forma independiente (el nombre del archivo es libre, y varios autores de mods o usuarios pueden añadir los suyos sin conflictos). Sirve para dar funciones de comercio/equipamiento a actores que no son compañeros del motor (`IsPlayerTeammate`), como personajes de mods que nunca activan esa bandera.

### Formato

```ini
[IncludeByNPC]        ; por referencia NPC      → clave: NPC
[IncludeByKeyword]    ; por keyword             → clave: Keyword (EditorID o FormID)
[IncludeByFaction]    ; por facción             → clave: Faction
NPC = Skyproc_ESP|0x00ABCD
Keyword = MyKeywordEditorID
Faction = Skyrim.esm|0x0C6472
```

- **Sufijo de modo** en el nombre de sección (opcional): `.NPCTrade` (por defecto si se omite), `.Loot`, `.Steal`, `.Pickpocket`.
  Ej.: `[IncludeByFaction.Steal]` → aplica al modo "robar".
- **Formato de FormID:** `Plugin.esp|0xLocalID` con prefijo `0x`, solo ID local (≤ `0x00FFFFFF`; los ESL usan los últimos 3 dígitos hex).
- Los valores aceptan **CSV** (varias entradas), comentarios en línea con `;` o `#`, y BOM UTF-8.
- Las keywords aceptan además `EditorID`; los NPC y facciones solo `Plugin|0xLocalID` (no tienen EditorID en runtime).
- La resolución a FormIDs reales es **perezosa** (al primer uso), de modo que las keywords que otros mods reparten, por ejemplo con SPID, ya están asignadas cuando se consultan.

### Ejemplos incluidos

```ini
; Actors/ManageSeranaEarly.ini — comerciar con Serana desde Cripta Dimhollow
[IncludeByNPC]
NPC = Dawnguard.esm|0x002B74

; Actors/PlayerSpouses.ini — intercambio rápido con los esposos
[IncludeByFaction]
Faction = Skyrim.esm|0x0C6472
```

El maestro global es `[ActorScope] IncludeInclusionActors=true`. Estos actores aparecen en el Panel de Control con pestaña verde y texto de indicador propio ("Equip Target").

---

## Localización / Traducciones

El Panel de Control y las notificaciones son traducibles:

1. Copia `Data/SKSE/Plugins/FollowerEquipControl/Localization/en.ini` y renómbralo a tu idioma (cualquier nombre **excepto** `en.ini`; p. ej. `es.ini`).
2. Traduce **solo el texto tras el `=`**; no toques `[secciones]` ni las claves de la izquierda.
3. Guarda en **UTF-8**.
4. Si hay **exactamente un** archivo distinto de `en.ini`, se carga automáticamente; si hay varios o ninguno, se usa `en.ini` (y en su defecto el inglés integrado). Las claves que falten caen al inglés.
5. Soporta `\n`, `\t` y marcadores `{0}`, `{1}`, `{2}` (consérvalos; se pueden reordenar).

Si los caracteres salen como `?`, la fuente activa no tiene esos glifos: SKSE Menu Framework incluye interruptores de rango de glifos (`EnableChinese`, `EnableJapanese`, `EnableKorean`, `EnableCyrillic`, …) en `SKSEMenuFramework.ini`. Para español no hace falta nada extra.

---

## Compilación desde el código fuente

### Requisitos de compilación

- Visual Studio o Build Tools con la carga de trabajo **C++** (MSVC, C++23)
- CMake **3.21+**
- Ninja
- Git
- vcpkg
- CommonLibSSE-NG (submódulo incluido)

### Obtener el código

```bat
git clone --recurse-submodules <repository-url>
cd <repository-folder>
```

Si ya clonaste sin submódulos:

```bat
git submodule update --init --recursive
```

La ruta esperada del submódulo es `extern/CommonLibSSE-NG`. También puede usarse un checkout externo definiendo `COMMONLIBSSE_NG_PATH` (variable de entorno o de CMake).

### vcpkg

El proyecto usa vcpkg en modo manifiesto. Define `VCPKG_ROOT`:

```bat
setx VCPKG_ROOT "C:\path\to\vcpkg"
```

Abre una terminal nueva después de definirla. Las dependencias están en `vcpkg.json`: `detours`, `directxmath`, `directxtk`, `fmt`, `rapidcsv`, `spdlog`, `xbyak` (triplet `x64-windows-static-md`). Las versiones se anclan con `builtin-baseline`, que debe coincidir con el que exige CommonLibSSE-NG (consulta su `vcpkg.json`): un baseline más antiguo instala `spdlog`/`fmt` incompatibles con Clang y rompe la compilación.

### Compilar

El preset por defecto compila el objetivo SE/AE:

```bat
BuildRelease.bat
```

Equivale a:

```bat
cmake -S . --preset Skyrim
cmake --build build --config Release
```

Se puede elegir otra configuración como segundo argumento:

```bat
BuildRelease.bat Skyrim Debug
BuildRelease.bat Skyrim RelWithDebInfo
```

Presets disponibles en `CMakePresets.json`:

- **`Skyrim`** — Skyrim SE/AE (`ENABLE_SKYRIM_SE=ON`, `ENABLE_SKYRIM_AE=ON`, VR off).
- **`SkyrimVR`** — Skyrim VR (oculto; **no soportado**, punto de partida futuro).

Salida: `FollowerEquipControl.dll` (x64, C++23, IPO en Release).

### Despliegue opcional

Tras compilar, el plugin puede copiarse a una carpeta local de Skyrim o de Mod Organizer 2:

```bat
rem Data de Skyrim directamente
setx SKYRIM_FOLDER "C:\path\to\Skyrim Special Edition"

rem carpeta mods de Mod Organizer 2
setx SKYRIM_MODS_FOLDER "C:\path\to\ModOrganizer\mods"
```

Con `SKYRIM_MODS_FOLDER` se despliega en:

```text
<SKYRIM_MODS_FOLDER>/Follower Equip Control SKSE/SKSE/Plugins
```

Si ninguna variable está definida, el proyecto compila igualmente sin copiar nada. Ambas variables se pueden definir (si las dos, gana `SKYRIM_MODS_FOLDER`).

### Compilación cruzada desde Linux (clang-cl)

Para runtimes recientes (por ejemplo **1.7.104**, formato 5 de Address Library) la vía recomendada es compilar en Linux con `clang-cl` + `lld-link` contra un sysroot de MSVC descargado con `xwin`. El preset `linux-clangcl` ya está preparado y usa los triples/presets de `extern/CommonLibSSE-NG/examples/linux-cross-compile`.

Requisitos:

- `clang`/`clang-cl` + `lld-link` (LLVM)
- `wine` (lo usa `fxc2` para compilar shaders de DirectXTK)
- `llvm-mingw`
- `xwin` y un sysroot de MSVC
- Python + venv con CMake y Ninja

El entorno se activa con el script de toolchain (ajusta las rutas a tu instalación):

```bash
source ~/skse-toolchain/env.sh   # exporta PATH, VCPKG_ROOT, XWIN_SYSROOT, etc.
```

Configura y compila:

```bash
cmake --preset linux-clangcl
cmake --build --preset linux-clangcl
```

Salida: `build/linux-clangcl/FollowerEquipControl.dll`.

Notas del preset y del árbol de dependencias:

- `VCPKG_OVERLAY_PORTS` incluye `port-overlays/` (de este repositorio) y los *custom-ports* de CommonLibSSE-NG. `port-overlays/detours` es un **port propio que compila Detours con CMake** en lugar de `vcpkg_build_nmake` (que aborta en un host no-Windows). Además define `_AMD64_` a mano, porque `clang-cl` no lo define y `detours.h` lo usa para activar la ruta x64.
- `CMakePresets.json` fija `VCPKG_TARGET_TRIPLET=x64-windows-clangcl` y encadena (`VCPKG_CHAINLOAD_TOOLCHAIN_FILE`) el toolchain `cmake/toolchain-linux-clangcl.cmake` de CommonLibSSE-NG.
- CommonLibSSE-NG debe ser **v12.1.0 o superior**: las versiones anteriores clasifican mal 1.7.104 como SE y buscan un `version-1-7-104-0.bin` que no existe (error `failed to open address library file`).

El despliegue descrito arriba (`SKYRIM_MODS_FOLDER`) también aplica desde Linux.

---

## Solución de problemas

| Síntoma                                    | Causa probable / solución                                                                                                                                     |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| El mod no hace nada                        | Comprueba `[Core] EnableMod=true`, SKSE y Address Library correctos, y la pestaña **System** del Panel de Control (el aviso rojo indica que está desactivado) |
| No aparece el Panel de Control             | Falta **SKSE Menu Framework 3** → configura por INI                                                                                                           |
| La tecla Mod no responde                   | Cambia `ModKeyDik` (código DIK) o `GamepadModKey`; otros programas con _overlay_ o _input hooks_ pueden interferir con `GetAsyncKeyState`                     |
| La recarga no abre el selector             | El arma no tiene encantamiento (carga ≤ 0) o está al 100 %; comprueba `EnableRecharge` y la tecla `RechargeKeyDik`                                            |
| No hay gemas en el selector                | Necesitas almas gemas **llenas** (en tu inventario o en el del seguidor); las vacías se excluyen                                                              |
| Ítems grisados en la pestaña "Dar"         | `EnableStaleWeightCacheFix=true` (por defecto)                                                                                                                |
| No puedo elegir cantidad de oro/ganzúas    | `EnableZeroWeightFix=true` (por defecto)                                                                                                                      |
| El seguidor se cambia de equipo solo       | Activa `EnableNonCombatEquipBlocker` / `EnableHandItemRestore` (por defecto activos); si otra mod sigue forzando equipo, prueba `EquipGate`                   |
| La ropa del seguidor se reinicia al cargar | `EnableUpdateNpcOutfitSuppression=true` + `EnableOutfitSnapshotRestore=true`                                                                                  |
| Necesito diagnosticar un fallo             | `[Logging] LogLevel=trace` y envía `Documentos/My Games/Skyrim Special Edition/SKSE/FollowerEquipControl.log`                                                 |
| Un actor no debería ser gestionado         | Exclúyelo desde **Actor Management** en el Panel de Control (se guarda en la partida)                                                                         |

---

## Notas técnicas y compatibilidad

- **Compatibilidad de runtime:** se compila con CommonLibSSE-NG y usa la Address Library (`UsesAddressLibrary`), por lo que sirve igual en 1.5.97 (SE) y 1.6.x (AE). **Skyrim VR no está soportado.**
- **Datos en la partida:** el plugin serializa con el ID único `'FEC0'` y estos registros (versión 2): `KNFL` (seguidores conocidos), `CEPR` (preferencias de combate), `OSRS` (instantánea de atuendo), `HIRS` (objetos de mano), `CEPC` (equipo pre-combate), `CHGT` (casco de combate), `SSPL` (hechizos suprimidos) y `ACDS` (actores excluidos). Se limpian con `Revert` de SKSE si desinstalas el mod.
- **Hooks utilizados (resumen):** Detours sobre `ContainerMenu::AddObjectToContainer`, `ActorEquipManager::EquipObject/UnequipObject/EquipSpell`, `InventoryChanges::GetInventoryWeight/InitLeveledItems/InitOutfitItems`, `Actor::AddObjectToContainer/RemoveItem/PickUpObject/UseAmmo`, `ActivateHandler::ProcessButton`, `UpdateNPCOutfit` y el árbol de comportamiento de combate; hooks de **vtable** en `CombatInventoryItem::CalculateScore` (índice 0x0C) y `VTABLE_CombatBehaviorTree…`; hooks **Scaleform/GFx** en `AttemptEquip`, `handleInput`, `formatName`, `updateButtons`, `UpdatePlayerInfo`, etc. Todos validan punteros y son _fail-open_/_fail-closed_ según conviene, y restauran la cadena original si otra mod se ha enganchado después.
- **Orden de carga:** al ser un plugin SKSE sin masters, el orden respecto a otros mods es libre; los posibles conflictos (otras mods que reescriban el ContainerMenu, `ActorEquipManager` o el equipamiento de NPCs) se resuelven normalmente desactivando la función correspondiente en FEC.
- **Notas de diseño:** el mod nunca confía en los punteros de la interfaz clonada (pueden quedar colgados tras ciclos de equipado), verifica la propiedad real de cada instancia en el inventario del actor y ante la duda **no actúa** (fail-closed), programando un refresco de la lista en su lugar. Las acciones que necesitan un frame posterior se diferencian con `SKSE::GetTaskInterface()->AddTask` para evitar reentrancia dentro de los hooks.
- El menú de comercio **sin SkyUI** no es compatible: las funciones se inhabilitan automáticamente si SkyUI no está presente.

---

## Licencia

Follower Equip Control se distribuye bajo **GNU General Public License v3.0**. Consulta el archivo `LICENSE`.

Incluye el header de SKSE Menu Framework (LGPL-2.1): https://github.com/QTR-Modding/SKSE-Menu-Framework-3
