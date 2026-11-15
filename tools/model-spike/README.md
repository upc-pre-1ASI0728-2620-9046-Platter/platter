# Prueba de modelos 3D con IA

Responde una pregunta antes de construir nada: **¿un modelo 3D generado por IA a partir de una sola foto
se ve lo bastante bien, a escala real y en la mesa, como para vender Platter con eso?**

El script toma fotos reales de platos y hace lo siguiente con cada una:

1. Le pide un modelo 3D a **Tripo** y a **Meshy**.
2. Lo normaliza igual que la biblioteca de Platter: el diámetro real del plato, centrado y apoyado en la mesa.
3. Lo aligera para datos móviles: hasta 20 000 triángulos, texturas de 1024 px y compresión Draco.
4. Arma una página que lo compara con el modelo actual de la biblioteca, con botón de Realidad Aumentada
   y una ficha para que el equipo califique.

## 1. Tomar las fotos (lo más importante)

Unas **10 fotos de platos reales**, idealmente de un restaurante piloto, que cubran casos distintos:
algo plano (cebiche, causa), algo con volumen (hamburguesa, lomo saltado), un postre y una bebida.

- El plato **completo** en la foto, sin cortar bordes.
- Ángulo de unos **45°**, como lo ve un comensal sentado. Ni cenital ni de costado.
- Buena luz, sin flash, sin sombras duras. Fondo liso si se puede.
- Formato JPG o PNG. En iPhone, usa "Más compatible" en Ajustes → Cámara → Formatos, o expórtalas a JPG.

Guárdalas en `photos/` con este nombre: **`<plato>@<diámetro en cm>.jpg`**.

```
photos/
  lomo-saltado@28.jpg
  cebiche-clasico@24.jpg
  causa-limena@20.jpg
  suspiro@12.jpg        ← mide el plato o vaso real; sin "@" se asume 27 cm
```

El diámetro importa porque la IA no sabe el tamaño real: el script escala el modelo a esa medida.

## 2. Claves de API

Crea una cuenta en cada servicio (ambos dan créditos de prueba) y copia la clave:

```bash
cp .env.example .env    # y pega TRIPO_API_KEY y/o MESHY_API_KEY
```

Costo aproximado: unos 20–30 créditos por modelo en cada servicio. 10 fotos × 2 proveedores ≈ 20 tareas,
del orden de **US$ 4–12** en total. Revisa los precios vigentes en sus páginas antes de comprar créditos.

## 3. Correr

```bash
npm install
npm run generate                          # todas las fotos, ambos proveedores
npm run generate -- --limit=2             # empieza con 2 fotos para validar
npm run generate -- --providers=tripo     # solo un proveedor
npm run mock                              # todo el flujo sin red ni créditos (para probar el script)
```

Cada generación tarda entre 30 segundos y unos minutos. El progreso se guarda en `out/results.json`:
**volver a ejecutar no repite ni vuelve a cobrar** lo que ya terminó. Si se corta a la mitad, retoma las
tareas pendientes. Opciones:

- `--force` vuelve a generar todo (y se paga de nuevo).
- `--retry-failed` reintenta las tareas que el proveedor marcó como fallidas.
- `npm run report` solo regenera la página.

## 4. Revisar en el celular

```bash
npm run serve           # http://localhost:5180
```

El visor 3D funciona en cualquier navegador, pero **la Realidad Aumentada necesita HTTPS**. Para probarla
en el celular, abre un túnel y entra a la URL `https://…trycloudflare.com` que te muestre:

```bash
cloudflared tunnel --url http://localhost:5180
```

Pon el celular frente a una mesa real y toca **Ver en mi mesa** en cada modelo. Califica de 1 a 5:
si se parece al plato, si se ve apetitoso y si se ve bien en la mesa. Al final toca **Exportar
calificaciones (CSV)**. Cada integrante califica en su celular y luego se juntan los CSV.

## Opción gratuita: fotogrametría con Apple Object Capture

Si tienes una Mac con Apple Silicon (M1 o posterior), macOS arma el modelo **gratis y en tu equipo**,
a partir de muchas fotos alrededor del plato. No inventa nada, así que es lo más fiel al plato real.
Con fotos de iPhone, además, la orientación sale correcta. Requiere Xcode o sus Command Line Tools,
porque la herramienta se compila sola la primera vez.

### Cómo tomar las fotos (40–80 por plato)

1. Pon el plato sobre una superficie **lisa y opaca** que contraste con él, por ejemplo un mantel de un solo color. Evita vidrio y metal brillante.
2. Usa luz **pareja y suave**: cerca de una ventana o bajo luz difusa, sin flash y sin sombras duras.
3. Camina alrededor del plato tomando una foto cada 10–15° (unas 25–30 por vuelta) y da **tres vueltas**:
   - una baja, casi a la altura de la mesa;
   - una a unos 45°;
   - una alta, casi desde arriba.
4. Cada foto debe compartir **al menos el 70 %** con la anterior y el plato debe ocupar buena parte del encuadre. No muevas el plato.
5. Pasa las fotos a la Mac (AirDrop sirve) **en una carpeta por plato**. Pueden ir en HEIC o JPG.

La comida se enfría y se seca: ten las fotos listas en 2 o 3 minutos.

### Correr

```bash
npm run apple -- ~/Desktop/fotos-lomo lomo-saltado@28
npm run generate        # escala, aligera y agrega el modelo a la página (sin API keys no gasta nada)
npm run serve
```

Con 40–60 fotos tarda de 1 a 5 minutos en una Mac M-series. Si salen avisos de fotos descartadas o
de "no se pudieron unir todas las fotos", toma más fotos con más superposición. Opciones de detalle:
`preview`, `reduced` (por defecto, pensado para AR y web), `medium` y `full`.

## Otras fuentes gratuitas: importar modelos

Cualquier GLB descargado, por ejemplo de la demo de **TRELLIS.2** en Hugging Face
(huggingface.co/spaces/microsoft/TRELLIS.2), se puede comparar. Guárdalo en `imports/` con este nombre:

```
imports/lomo-saltado@28--trellis.glb      ← <plato>@<diámetro>--<fuente>.glb
```

Luego `npm run generate`: se escala al diámetro, se aligera y aparece en la página junto a los demás.
Si en `photos/` hay una foto con el mismo nombre de plato, se muestra al lado.

## 5. Cómo decidir

| Resultado | Decisión sugerida |
|---|---|
| Algún proveedor saca 4+ en "se parece" y "en la mesa" en la mayoría de platos | Integrarlo al flujo de la app: foto → modelo → aprobación del dueño |
| Va bien en platos planos y mal en platos con volumen | IA como base y biblioteca o servicio premium para los difíciles |
| Ninguno pasa de 3 | No vender "tu plato en 3D" todavía: biblioteca ampliada y fotogrametría como servicio |

Fíjate también en las advertencias de cada tarjeta. "Puede venir girado" indica un modelo que no queda
plano sobre la mesa. "Pesa más de 5 MB" significa que cargará lento con datos móviles.

## Notas

- Las fotos se reducen a 2048 px y se les quitan los metadatos (incluida la ubicación GPS) antes de enviarlas.
- Se envían a servidores de Tripo y Meshy: usa fotos que el restaurante haya autorizado.
- `out/` y `photos/` no se suben al repositorio.
