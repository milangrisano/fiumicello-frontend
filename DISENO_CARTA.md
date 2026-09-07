# Documento de Diseño — Carta Digital de Fiumicello

**Propietario:** Enrique · **Trattoria:** Fiumicello (Bogotá e Ibagué, fundada 2024)
**Paleta base:** Maratea — "Perla del Tirreno" (`lib/core/theme/maratea_colors.dart`)
**Archivo de referencia de la carta actual:** `lib/views/carta_view.dart`
**Fecha:** septiembre 2026

---

## 1. Enfoque

Este documento presenta **tres alternativas visuales** para la carta (menú público) de
Fiumicello. Las tres comparten el mismo objetivo: presentar la carta como una *carta de
una trattoria italiana* — profesional, elegante y apetitosa — sobre la paleta de Maratea,
respetando **íntegramente** la información real: nombres, descripciones/ingredientes y
precios exactos. No se inventa ni se modifica ningún dato; solo se rediseña la
presentación.

### Estructura real de la carta (se conserva en las 3 alternativas)
| Categoría | Items | Tipo de precio |
|---|---|---|
| **Pizzas** | 7 (Margherita, Pollo y Champiñón, Pepperoni, Hawaiana, Maíz Guanciale, Vegetariana, Napolitana) | Personal / Mediana / Grande |
| **Pizzas de la Casa** | 7 (Quatro Formaggi, Coppa, Prosciutto Crudo e Rucula, Quattro Maiale, Salametto, Prosciutto e Funghi, Salami y Vegetales) | Personal / Mediana / Grande |
| **Lasagnas** | 2 (Lasagna di Carne, Lasagna Mista) | Precio único |
| **Paninis** | 4 (Schiacciata di Parma, di Bologna, di Córcega, Cotto) | Precio único |
| **Bebidas** | 13, agrupadas en **Cervezas** (3), **Tés** (3), **Gaseosas** (5), **Aguas** (2) | Precio único |

### Paleta Maratea disponible (referencia)
| Color | Hex | Uso natural inspirativo |
|---|---|---|
| `deepBlue` | `#0E2A3A` | Profundidad del mar Tirreno — títulos, textos nobles, fondos oscuros |
| `mediterraneanBlue` | `#1F6F8B` | Cielo/agua del Mediterráneo — acentos secundarios |
| `turquoise` | `#2FB9A6` | Calas cristalinas — precios, acentos vivos |
| `mediterraneanGreen` | `#2F4F33` | Bosques de pino — detalles de marca, vegetales |
| `volcanoBlack` | `#2B2620` | Arena volcánica — fondos oscuros |
| `goldenSand` | `#C9A227` | Sol sobre la arena — descripciones, metales |
| `ochre` | `#C9A227` | Tejas/soles — acentos cálidos |
| `paleYellow` | `#F0D9A6` | Yeso pastel — fondos dulces, resaltes |
| `oldRose` | `#C98A9B` | Fachadas rosadas — acentos románticos |
| `cream` | `#F5EBDD` | Estuco crema — fondos claros |
| `brokenWhite` | `#F8F5F0` | Blanco cálido roto — fondos neutros |
| `terracotta` | `#C65D3B` | Tejas rojas — protagonista cálido, nombres |
| `stoneGray` | `#9C948F` | Piedra — bordes, tonalidades |
| `rockGray` | `#7B8184` | Roca — grises medios |
| `pureWhite` | `#FFFFFF` | Blanco del Cristo di Maratea — nieves, fondos puros |

Las tres alternativas usan **solo estos colores**, combinados de manera distinta para
darle a cada una una personalidad visual clara y diferenciada.

---

## 2. Alternativa A — "Carta di Borgo" *(fondo claro y elegante)*

**Concepto / dirección visual**
Una carta de trattoria diurna, luminosa y pulcra, como un mantel de lino sobre una mesa
frente al mar. Es la evolución refinada del estilo actual (fondo crema, jerarquía por
tinta), elevada con más aire, líneas finas y una composición serena. Ideal para el
celular y perfecta para leerse en condiciones de luz.

**Mantener el espíritu actual es una fortaleza:** mantiene la legibilidad sobria que ya
gusta a los clientes y solo la pule. Es la alternativa de menor riesgo.

**Paleta Maratea que usaría (rol por elemento)**
- **Fondo general:** `cream` `#F5EBDD`.
- **Fichas/columnas de escritorio:** `brokenWhite` `#F8F5F0` con borde `stoneGray` `#9C948F` (muy fino, 1px) y sombra suave.
- **Logo:** tal cual (fondo blanco del asset), sobre banda de `brokenWhite`.
- **Títulos de categoría (Pizzas, Pizzas de la Casa, …):** `deepBlue` `#0E2A3A`, en MAYÚSCULAS, con filete decorativo corto en `turquoise`.
- **Subtítulos de bebidas (Cervezas, Tés, Gaseosas, Aguas):** `mediterraneanBlue` `#1F6F8B`, versalitas.
- **Nombres de plato:** `terracotta` `#C65D3B`.
- **Descripciones / ingredientes:** `rockGray` `#7B8184` (más legible que el dorado sobre crema).
- **Precios:** `turquoise` `#2FB9A6`, en negrita.
- **Precios por tamaño** (Personal · Mediana · Grande): `goldenSand` `#C9A227`, tamaño pequeño.
- **Acentos ornamentales** (bordes divisorios, serpientes): `stoneGray` + toques de `paleYellow`.
- **Cierre "¡BUON APPETITO!":** `deepBlue`.

**Tipografía sugerida**
- Títulos de categoría: serif elegante con contraste — **Cormorant Garamond** (bold, pequeñas capitales).
- Nombres de plato: **Source Serif / Lora** semibold.
- Descripciones y precios: **Inter** o **Source Sans** (máxima legibilidad en pantalla).

**Layout**
- **Móvil/tablet (<1200px):** una sola columna, logo centrado (~70px), margen lateral cómodo (24px), categorías apiladas en orden (Pizzas → Pizzas de la Casa → Lasagnas → Paninis → Bebidas).
- **Escritorio (≥1200px):** dos columnas en filas — fila 1: *Pizzas | Pizzas de la Casa*; fila 2: *(Lasagnas + Paninis) | Bebidas*. Cada columna como ficha de `brokenWhite` con borde fino, logotipo duplicado (140px).

**Cómo se vería**
Carta clara y "respirable": fondo crema suave, fichas blancas cálidas con líneas finas,
títulos azul mar profundo que anclan cada sección, nombres de plato en terracota cálido,
precios en turquesa que invitan a leer. Se percibe como el restaurante: sereno, italiano,
accesible. Sobre fondo claro la información queda completamente legible, incluso en
celulares con luz exterior.

---

## 3. Alternativa B — "Notte del Tirreno" *(fondo oscuro y mediterráneo-dramático)*

**Concepto / dirección visual**
Una carta nocturna de trattoria junto al mar: fondo azul profundo como la noche sobre el
Tirreno, acentos de cala turquesa y dunas doradas. Dramática y sofisticada, ideal para
una experiencia premium de cena. El contraste inverso (texto claro sobre fondo oscuro)
hace que **nombres y precios brillen**, un efecto visual muy atractivo en el celular.

**Paleta Maratea que usaría (rol por elemento)**
- **Fondo general:** `deepBlue` `#0E2A3A` (o hasta `volcanoBlack` `#2B2620` en la base).
- **Fichas/columnas:** `volcanoBlack` `#2B2620` con borde `turquoise`/`goldenSand` sutil (reborde de 1px para dar luz).
- **Logo:** se muestra sobre banda de `brokenWhite` (el asset blanco necesita un "marco" claro para no desvanecerse sobre azul).
- **Títulos de categoría:** `pureWhite` con filete o decorado en `turquoise`.
- **Subtítulos de bebidas:** `goldenSand` `#C9A227`.
- **Nombres de plato:** `pureWhite`.
- **Descripciones / ingredientes:** `stoneGray` `#9C948F` o `paleYellow` suave (texto sobre oscuro, siempre > 4.5:1).
- **Precios:** `turquoise` `#2FB9A6` (brillan sobre fondo oscuro) en negrita.
- **Precios por tamaño** (Personal · Mediana · Grande): `paleYellow` `#F0D9A6`.
- **Acentos ornamentales** (líneas divisorias, marcos, esquinas): `goldenSand` + `oldRose` en detalles mínimos.
- **Cierre "¡BUON APPETITO!":** `turquoise` en itálica.

**Tipografía sugerida**
- Títulos de categoría: serif display con mucho carácter — **Playfair Display** (bold, MAYÚSCULAS).
- Nombres de plato: **Lora / Source Serif** semibold.
- Descripciones y precios: **Inter** (luz, buena sobre oscuro).

**Layout**
- **Móvil/tablet (<1200px):** una columna, logo centrado sobre banda clara (~70px), fondo `deepBlue` continuo, separadores finos dorados entre items.
- **Escritorio (≥1200px):** dos columnas en filas (Pizzas | Pizzas de la Casa / Lasagnas+Paninis | Bebidas), cada columna como "tarjeta" oscura `volcanoBlack` con marco fino dorado, logotipo duplicado (140px).

**Cómo se vería**
Una carta-cenador: fondo mar profundo que enmarca platos claros y precios turquesa
luminosos. Transmite exclusividad y "noche italiana". Es la opción más memorables y
fotogénica — destaca en el celular y se ve espectacular en el escritorio. Requiere
cuidado con el contraste del texto claro y con el logo (que se resuelve con su banda
blanca), pero el resultado es muy diferenciador.

---

## 4. Alternativa C — "Casa & Forno" *(acentos cálidos terracota-madera)*

**Concepto / dirección visual**
La calidez del horno de leña y la teja toscana: fondos cálidos de estuco, teja roja y
dunas de arena, con pinceladas de verde pins (los montes de Maratea) y dorado solar.
Es la carta del "hogar y el horno": familiar, acogedora, artesanal. Comunica la cocina
tradicional de la trattoria con un acabado cálido y terroso.

**Paleta Maratea que usaría (rol por elemento)**
- **Fondo general:** `brokenWhite` `#F8F5F0` con banda/encabezado superior en `cream` `#F5EBDD`.
- **Banda superior o franja de marca:** `terracotta` `#C65D3B` (una franja fina bajo el logo) para un toque de "teja".
- **Fichas/columnas:** `paleYellow` muy suave `#F0D9A6` tenue con borde `ochre` `#C9A227`.
- **Títulos de categoría:** `terracotta` (o `deepBlue` para contraste) — recomendado `terracotta` con filete `ochre`.
- **Subtítulos de bebidas:** `mediterraneanGreen` `#2F4F33` (pins → legumbres/hierbas, con un toque fresco frente al marrón).
- **Nombres de plato:** `volcanoBlack` `#2B2620` (tinta cálida casi negra, muy legible).
- **Descripciones / ingredientes:** `goldenSand` `#C9A227` sobre fondos claros (requiere peso ≥600 en pantalla).
- **Precios:** `terracotta` `#C65D3B` en negrita.
- **Precios por tamaño** (Personal · Mediana · Grande): `rockGray` `#7B8184`.
- **Acentos decorativos** (bordes, viñetas, divisores): `ochre`/`goldenSand`, con líneas `stoneGray`.
- **Cierre "¡BUON APPETITO!":** `terracotta` itálica.

**Tipografía sugerida**
- Títulos de categoría: caligráfica/menosformas acogedoras — **Osteria** o **Canela** (regular/bold), o bien serif redondeada tipo **DM Serif Display**.
- Nombres de plato: **Fraunces** o **Source Serif** semibold.
- Descripciones y precios: **Inter / Work Sans**.

**Layout**
- **Móvil/tablet (<1200px):** una columna; tras el logo, una franja fina `terracotta`; categorías en tarjetas `paleYellow` tenue con borde `ochre`; grupos de bebidas claramente separados.
- **Escritorio (≥1200px):** dos columnas en filas (Pizzas | Pizzas de la Casa / Lasagnas+Paninis | Bebidas), cada columna dentro de una "carta-ficha" cálida con borde `ochre` y leve sombra, logotipo duplicado (140px).

**Cómo se vería**
Carta cálida y hogareña: estuco claro, franja de teja terracota, tarjetas de yeso dorado
con vivos verdes-pins en los subtítulos y tinta cálida para los nombres. Comunica
"cocina de horno", artesanía y tradición italiana. Es la alternativa más **cálida y
familiar**, cercana al imaginario de la trattoria de barrio, con un acabado pulido y
coherente de marca.

---

## 5. Recomendación

### Ganador: **Alternativa A — "Carta di Borgo"** (fondo claro y elegante)
*(Seguida muy de cerca por la Alternativa C)*

**Por qué la elijo para una trattoria italiana:**

1. **Máxima legibilidad y bajo riesgo.** La carta pública se lee en celulares con luz
   exterior y en el escritorio; un fondo `cream`/`brokenWhite` con tinta oscura ofrece
   el mejor contraste (WCAG AA) para nombres, descripciones y precios. Es la opción más
   **accesible y universal** de las tres, y la que mejor conserva la identidad del
   restaurante tal como ya la usan.

2. **Coherencia de marca sin fricción.** Mantiene la misma lógica de colores que la
   carta actual (fondo crema, títulos azul profundo, precios turquesa), por lo que la
   transición a producción es natural y los clientes no perciben un "cambio de marca"
   brusco — solo una carta mejor pulida.

3. **Jerarquía y elegancia.** Con títulos `deepBlue` en MAYÚSCULAS serif, nombres
   `terracotta`, descripciones en gris piedra legible y precios `turquesa`, se logra una
   jerarquía visual clara (categoría → plato → ingredientes → precio) que una trattoria
   elegante necesita. Los filetes ornamentales finos en `turquoise` y `paleYellow` dan
   el acabado pulido sin caer en ornamento excesivo.

4. **Versatilidad.** Es la base más fácil de adaptar al resto de la app (facturas, POS,
   resúmenes) y a futuros cambios de menú. Si Enrique quiere luego un toque más cálido,
   puede sumarse la franja `terracotta` de la Alternativa C sin rediseñar todo.

**Cuándo elegiría la otra:**
- Elija la **Alternativa B "Notte del Tirreno"** si el objetivo es una experiencia
  nocturna premium y fotogénica, y si se dispone de tiempo para validar el contraste del
  texto claro y el manejo del logo sobre fondo oscuro.
- Elija la **Alternativa C "Casa & Forno"** si quiere enfatizar la **artesanía y el
  calor del horno** por encima de la elegancia serena, manteniendo un fondo claro
  legible.

> **Modificación mínima recomendada a la carta actual (camino a implementar):**
> cambiar la descripción de `goldenSand` → `rockGray`, y el precio por tamaño de
> `turquoise` único → `goldenSand` pequeña de apoyo, manteniendo todo lo demás; y añadir
> filetes finos `turquoise` bajo cada título de categoría. Es un cambio de presentación,
> sin tocar los datos.

---

*Documento de diseño. Ningún archivo de producción fue modificado; este documento es
una propuesta para aprobación de Enrique.*