<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Configurar Test</title>
    <link rel="stylesheet" href="style.css">
    <link rel="manifest" href="manifest.json">
<link rel="icon" href="icon-192.png">
<meta name="theme-color" content="#667eea">
</head>
<body>
    <div class="container">
        <header>
            <button class="btn-back" onclick="window.location.href='index.html'">← Volver</button>
            <h1>⚙️ Configurar Test</h1>
        </header>

        <main>
            <div id="opcionesRapidas" style="display: none; margin-bottom: 20px;">
                <button class="btn-repetir" id="btnRepetirParametros">
                    🔄 Repetir últimos parámetros
                </button>
                <button class="btn-falladas" id="btnSoloFalladas">
                    ❌ Solo preguntas falladas
                </button>
            </div>

            <div class="form-group">
                <label>Nombre del test</label>
                <input type="text" id="nombreTest" placeholder="Ej: Test Tema 1">
            </div>

            <div class="form-group">
                <label>Seleccionar temas y subtemas</label>
                <div id="listaTemas">Cargando temas...</div>
            </div>

            <div class="form-group">
                <label>Número de preguntas</label>
                <div class="cantidad-btns">
                    <button class="btn-cantidad" data-cantidad="10">10</button>
                    <button class="btn-cantidad" data-cantidad="20">20</button>
                    <button class="btn-cantidad" data-cantidad="50">50</button>
                    <button class="btn-cantidad" data-cantidad="100">100</button>
                </div>
                <input type="number" id="cantidadPersonalizada" placeholder="Otra cantidad" min="1">
            </div>

            <button class="btn-primary" id="btnIniciarTest">
                🚀 Iniciar Test
            </button>
        </main>
    </div>

    <script type="module" src="configurar-test.js?v=2"></script>
</body>
</html>
