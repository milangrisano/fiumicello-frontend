# Fiumicello — Branding Assets (variantes suavizadas)

Carpeta organizada con variantes de marca generadas a partir de los assets
originales en `../`. Todas las imágenes son PNG RGBA con **fondo transparente**
y la **banda tricolor italiana (verde/blanco/rojo) íntegra**.

## Estructura

| Carpeta     | Contenido |
|-------------|-----------|
| `gorro/`    | El gorro de chef solo (recortado a su contenido), alta resolución (min 512 px de lado), líneas blancas o negras. |
| `logo/`     | Logo completo "Fiumicello" (gorro + texto + DAL 2024), líneas blancas o negras. |
| `favicon/`  | Iconos cuadrados 256×256, fondo transparente, listos para favicon / pestaña web. |

## gorro/ (solo el sombrero)

- `gorro_linea_blanca.png` — gorro con líneas/contorno en blanco + banda tricolor.
- `gorro_linea_negra.png` — gorro con líneas/contorno en negro + banda tricolor.
- `gorro_linea_blanca_suave.png` — misma versión blanca, suavizada.
- `gorro_linea_negra_suave.png` — misma versión negra, suavizada.

(Ambas variantes ya están suavizadas; los archivos `_suave` son equivalentes,
guardados para claridad de nombres.)
Uso: lugares donde se necesita el icono del gorro aislado y grande (splash,
fondos, separadores), con fondo claro (negro) u oscuro (blanco).

## logo/ (logo completo)

- `logo_fiumicello_linea_blanca.png` — logo completo en blanco/transparente.
- `logo_fiumicello_linea_negra.png` — logo completo en negro/transparente.

Uso: cabeceras, login, carteles, sobre fondos que contrasten (texto en negro →
fondos claros; texto en blanco → fondos oscuros/fotografías).

## favicon/ (256×256, transparentes)

- `favicon_gorro_linea_negra_256.png` — silueta del gorro en negro + banda.
- `favicon_gorro_linea_blanca_256.png` — silueta del gorro en blanco + banda.
- `favicon_logo_linea_negra_256.png` — logo completo en negro.
- `favicon_logo_linea_blanca_256.png` — logo completo en blanco.

Uso recomendado:
- **Pestaña del navegador / favicon web:** usa `favicon_gorro_*_256.png` (el
  gorro solo se lee mejor a tamaño pequeño). El negro para fondos claros y el
  blanco para fondos oscuros.
- **App icon / icono de progresiva (PWA):** `favicon_logo_linea_negra_256.png`
  sobre fondo claro. Si el entorno es oscuro, usa la versión blanca.

## Técnica de suavizado

Render a alta resolución (supersampling LANCZOS ~2400 px), de-jag de bordes
mediante Gaussiano en espacio-fuente (sigma adaptado: favor del tratamiento en
favicons para evitar el aspecto pixelado), y reducción en pasos con LANCZOS
para líneas continuas sin escalones. La banda tricolor se conserva completa:
verde + blanco central + rojo (nunca se pierde el blanco de la bandera).

## Generación

Re-generar: modos diferentes se producen desde los assets originales
(`gorro_fiumicello_blanco.png` para gorro, `logo_fiumicello*.png` para logo).
Fuentes originales no se modifican.