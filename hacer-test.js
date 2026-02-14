import { auth } from './firebase-config.js';
import { onAuthStateChanged } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";

let currentUser = null;
let testActual = null;
let preguntaActualIndex = 0;
let respuestasUsuario = []; // Array de respuestas: { preguntaIndex, respuestaSeleccionada (0-3 o null) }

// Verificar autenticación
onAuthStateChanged(auth, async (user) => {
    if (user) {
        currentUser = user;
        cargarTest();
    } else {
        window.location.href = 'https://plataforma-examenes-f2df9.web.app/index.html';
    }
});

// Cargar test desde sessionStorage
function cargarTest() {
    const testGuardado = sessionStorage.getItem('testActual');
    
    if (!testGuardado) {
        alert('No hay test configurado');
        window.location.href = 'configurar-test.html';
        return;
    }

    testActual = JSON.parse(testGuardado);
    
    // Inicializar respuestas vacías
    respuestasUsuario = testActual.preguntas.map(() => null);
    
    // Mostrar información del test
    document.getElementById('nombreTestActual').textContent = testActual.nombre;
    document.getElementById('totalPreguntas').textContent = testActual.preguntas.length;
    
    // Configurar eventos
    configurarEventos();
    
    // Mostrar primera pregunta
    mostrarPregunta(0);
}

// Configurar eventos
function configurarEventos() {
    document.getElementById('btnAnterior').addEventListener('click', () => {
        if (preguntaActualIndex > 0) {
            mostrarPregunta(preguntaActualIndex - 1);
        }
    });

    document.getElementById('btnSiguiente').addEventListener('click', () => {
        if (preguntaActualIndex < testActual.preguntas.length - 1) {
            mostrarPregunta(preguntaActualIndex + 1);
        }
    });

    document.getElementById('btnFinalizarTest').addEventListener('click', finalizarTest);
}

// Mostrar pregunta
function mostrarPregunta(index) {
    preguntaActualIndex = index;
    const pregunta = testActual.preguntas[index];
    
    // Actualizar contador
    document.getElementById('numeroPregunta').textContent = index + 1;
    
    // Mostrar texto de la pregunta
    document.getElementById('textoPregunta').textContent = pregunta.texto;
    
    // Renderizar opciones
    const opcionesDiv = document.getElementById('opcionesRespuesta');
    opcionesDiv.innerHTML = '';
    
    pregunta.opciones.forEach((opcion, i) => {
        const boton = document.createElement('button');
        boton.className = 'opcion-btn';
        boton.textContent = `${String.fromCharCode(65 + i)}) ${opcion}`;
        
        // Marcar si ya fue seleccionada
        if (respuestasUsuario[index] === i) {
            boton.classList.add('selected');
        }
        
        boton.addEventListener('click', () => {
            // Desmarcar todas
            opcionesDiv.querySelectorAll('.opcion-btn').forEach(b => b.classList.remove('selected'));
            // Marcar la seleccionada
            boton.classList.add('selected');
            // Guardar respuesta
            respuestasUsuario[index] = i;
        });
        
        opcionesDiv.appendChild(boton);
    });
    
    // Actualizar estado de botones de navegación
    actualizarBotonesNavegacion();
}

// Actualizar botones de navegación
function actualizarBotonesNavegacion() {
    const btnAnterior = document.getElementById('btnAnterior');
    const btnSiguiente = document.getElementById('btnSiguiente');
    
    // Desactivar "Anterior" si estamos en la primera pregunta
    if (preguntaActualIndex === 0) {
        btnAnterior.style.opacity = '0.5';
        btnAnterior.style.cursor = 'not-allowed';
    } else {
        btnAnterior.style.opacity = '1';
        btnAnterior.style.cursor = 'pointer';
    }
    
    // Desactivar "Siguiente" si estamos en la última pregunta
    if (preguntaActualIndex === testActual.preguntas.length - 1) {
        btnSiguiente.style.opacity = '0.5';
        btnSiguiente.style.cursor = 'not-allowed';
    } else {
        btnSiguiente.style.opacity = '1';
        btnSiguiente.style.cursor = 'pointer';
    }
}

// Finalizar test
function finalizarTest() {
    // Confirmar si hay preguntas sin responder
    const sinResponder = respuestasUsuario.filter(r => r === null).length;
    
    if (sinResponder > 0) {
        const confirmar = confirm(`Tienes ${sinResponder} pregunta(s) sin responder. ¿Deseas finalizar el test?`);
        if (!confirmar) return;
    }
    
    // Calcular resultados
    const resultado = calcularResultado();
    
    // Guardar resultado completo en sessionStorage
    sessionStorage.setItem('resultadoTest', JSON.stringify(resultado));
    
    // Guardar en historial (localStorage)
    guardarEnHistorial(resultado);
    
    // Actualizar preguntas falladas
    actualizarPreguntasFalladas(resultado);
    
    // Redirigir a pantalla de resultado
    window.location.href = 'resultado-test.html';
}

// Calcular resultado del test
function calcularResultado() {
    let aciertos = 0;
    let fallos = 0;
    let blanco = 0;
    
    const detallePreguntas = testActual.preguntas.map((pregunta, index) => {
        const respuestaUsuario = respuestasUsuario[index];
        const esCorrecta = respuestaUsuario === pregunta.respuestaCorrecta;
        const esBlanco = respuestaUsuario === null;
        
        if (esBlanco) {
            blanco++;
        } else if (esCorrecta) {
            aciertos++;
        } else {
            fallos++;
        }
        
        return {
            pregunta: pregunta.texto,
            opciones: pregunta.opciones,
            respuestaCorrecta: pregunta.respuestaCorrecta,
            respuestaUsuario: respuestaUsuario,
            esCorrecta: esCorrecta,
            esBlanco: esBlanco,
            explicacion: pregunta.explicacion || null,
explicacionGemini: pregunta.explicacionGemini || null,
explicacionPDF: pregunta.explicacionPDF || null,
subtema: pregunta.subtemaNombre || 'Sin subtema'
        };
    });
    
    // Calcular nota según imagen (aciertos - (fallos / 3))
    // Si el examen tiene 100 preguntas, la nota sobre 60 sería:
    // nota = (aciertos - fallos/3) * 60 / totalPreguntas
    const totalPreguntas = testActual.preguntas.length;
    const puntosBrutos = aciertos - (fallos / 3);
    const nota = Math.max(0, (puntosBrutos * 60) / totalPreguntas);
    
    return {
        id: Date.now(), // ID único basado en timestamp
        nombre: testActual.nombre,
        fecha: new Date().toISOString(),
        totalPreguntas: totalPreguntas,
        aciertos: aciertos,
        fallos: fallos,
        blanco: blanco,
        nota: Math.round(nota * 100) / 100, // Redondear a 2 decimales
        puntosBrutos: Math.round(puntosBrutos * 100) / 100,
        detallePreguntas: detallePreguntas,
        subtemas: testActual.subtemas || []
    };
}

// Guardar en historial
function guardarEnHistorial(resultado) {
    const historial = JSON.parse(localStorage.getItem('historialTests') || '[]');
    
    // Agregar al inicio (más reciente primero)
    historial.unshift({
        id: resultado.id,
        nombre: resultado.nombre,
        fecha: resultado.fecha,
        nota: resultado.nota,
        aciertos: resultado.aciertos,
        fallos: resultado.fallos,
        blanco: resultado.blanco,
        totalPreguntas: resultado.totalPreguntas,
        subtemas: resultado.subtemas
    });
    
    // Guardar detalle completo por separado
    localStorage.setItem(`test_${resultado.id}`, JSON.stringify(resultado));
    
    // Actualizar historial
    localStorage.setItem('historialTests', JSON.stringify(historial));
}

// Actualizar preguntas falladas para repaso
function actualizarPreguntasFalladas(resultado) {
    // Si el test era de "solo falladas", limpiar las que se acertaron
    if (testActual.soloFalladas) {
        const falladas = JSON.parse(localStorage.getItem('preguntasFalladas') || '[]');
        const preguntasCorrectas = resultado.detallePreguntas
            .filter(d => d.esCorrecta)
            .map(d => d.pregunta);
        
        const nuevasFalladas = falladas.filter(p => !preguntasCorrectas.includes(p.texto));
        localStorage.setItem('preguntasFalladas', JSON.stringify(nuevasFalladas));
    } else {
        // Agregar nuevas preguntas falladas
        const falladas = JSON.parse(localStorage.getItem('preguntasFalladas') || '[]');
        
        resultado.detallePreguntas.forEach((detalle, index) => {
            if (!detalle.esCorrecta && !detalle.esBlanco) {
                const preguntaOriginal = testActual.preguntas[index];
                
                // Verificar si ya está en falladas
                const yaExiste = falladas.some(p => p.texto === preguntaOriginal.texto);
                
                if (!yaExiste) {
                    falladas.push({
                        texto: preguntaOriginal.texto,
                        opciones: preguntaOriginal.opciones,
                        respuestaCorrecta: preguntaOriginal.respuestaCorrecta,
                        verificada: true,
                        subtemaId: preguntaOriginal.subtemaId,
                        subtemaNombre: preguntaOriginal.subtemaNombre
                    });
                }
            }
        });
        
        localStorage.setItem('preguntasFalladas', JSON.stringify(falladas));
    }
}
