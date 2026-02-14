import { auth, db } from './firebase-config.js';
import { onAuthStateChanged } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { collection, query, where, getDocs } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";

let currentUser = null;
let temasDisponibles = [];
let subtemasSeleccionados = [];
let cantidadSeleccionada = 10;

// Verificar autenticación
onAuthStateChanged(auth, async (user) => {
    if (user) {
        currentUser = user;
        await cargarTemas();
        verificarOpcionesRapidas();
        configurarEventos();
    } else {
        window.location.href = 'login.html';
    }
});

async function cargarTemas() {
    try {
        const listaTemas = document.getElementById('listaTemas');
        listaTemas.innerHTML = '<p class="loading">Cargando temas...</p>';

        console.log('Cargando temas para usuario:', currentUser.uid);

        const temasRef = collection(db, "temas");
        const q = query(temasRef, where("usuarioId", "==", currentUser.uid));
        const snapshot = await getDocs(q);

        console.log('Temas encontrados:', snapshot.size);

        // Separar temas principales y subtemas
        const temasPrincipales = [];
        const subtemasMap = new Map();

        snapshot.forEach((doc) => {
            const tema = { id: doc.id, ...doc.data() };
            console.log('Tema cargado:', tema.nombre, '- Es subtema:', !!tema.temaPadreId);
            
            if (tema.temaPadreId) {
                // Es un subtema
                if (!subtemasMap.has(tema.temaPadreId)) {
                    subtemasMap.set(tema.temaPadreId, []);
                }
                subtemasMap.get(tema.temaPadreId).push(tema);
            } else {
                // Es tema principal
                temasPrincipales.push(tema);
            }
        });

        console.log('Temas principales:', temasPrincipales.length);
        console.log('Subtemas totales:', Array.from(subtemasMap.values()).flat().length);

        // Ordenar temas alfabéticamente con orden natural (números)
        temasPrincipales.sort((a, b) => a.nombre.localeCompare(b.nombre, undefined, { numeric: true, sensitivity: 'base' }));
        
        // Ordenar subtemas dentro de cada tema
        subtemasMap.forEach((subtemas) => {
            subtemas.sort((a, b) => a.nombre.localeCompare(b.nombre, undefined, { numeric: true, sensitivity: 'base' }));
        });

        if (temasPrincipales.length === 0) {
            listaTemas.innerHTML = '<p style="color: white; text-align: center; padding: 20px;">No tienes temas creados en la plataforma de escritorio.<br><br>Crea temas y preguntas en:<br><a href="https://plataforma-examenes-f2df9.web.app" style="color: white; text-decoration: underline;">plataforma-examenes-f2df9.web.app</a></p>';
            return;
        }

        // Renderizar temas y subtemas
        listaTemas.innerHTML = '';
        temasPrincipales.forEach(tema => {
            const temaDiv = crearElementoTema(tema, subtemasMap.get(tema.id) || []);
            listaTemas.appendChild(temaDiv);
        });

        temasDisponibles = temasPrincipales;

    } catch (error) {
        console.error('Error cargando temas:', error);
        document.getElementById('listaTemas').innerHTML = `<p style="color: white; text-align: center; padding: 20px;">Error cargando temas: ${error.message}</p>`;
    }
}

// Crear elemento visual de tema con sus subtemas
function crearElementoTema(tema, subtemas) {
    const temaDiv = document.createElement('div');
    temaDiv.className = 'tema-item';

    const cantidadPreguntasTema = tema.preguntas?.filter(p => p.verificada)?.length || 0;
    
    // Si tiene subtemas, mostrar número de subtemas
    // Si NO tiene subtemas pero SÍ preguntas, mostrar número de preguntas
    let infoExtra = '';
    if (subtemas.length > 0) {
        infoExtra = `${subtemas.length} subtemas <span class="toggle-icon">▶</span>`;
    } else if (cantidadPreguntasTema > 0) {
        infoExtra = `${cantidadPreguntasTema}`;
    }

    // Header del tema
    const temaHeader = document.createElement('div');
    temaHeader.className = 'tema-header';
    
    // Si NO tiene subtemas pero SÍ preguntas, hacerlo seleccionable
    if (subtemas.length === 0 && cantidadPreguntasTema > 0) {
        temaHeader.innerHTML = `
            <input type="checkbox" id="tema-${tema.id}" data-tema-id="${tema.id}">
            <label for="tema-${tema.id}" style="flex: 1; cursor: pointer; font-weight: 600;">
                ${tema.nombre}
            </label>
            <span style="color: #999; font-size: 14px;">${infoExtra}</span>
        `;
        
        temaHeader.querySelector('input').addEventListener('change', (e) => {
            if (e.target.checked) {
                subtemasSeleccionados.push({
                    id: tema.id,
                    nombre: tema.nombre,
                    preguntas: tema.preguntas || []
                });
            } else {
                subtemasSeleccionados = subtemasSeleccionados.filter(s => s.id !== tema.id);
            }
        });
    } else {
        temaHeader.innerHTML = `
            <span style="font-weight: 600; flex: 1;">${tema.nombre}</span>
            <span style="color: #999; font-size: 14px;">${infoExtra}</span>
        `;
    }
    
    temaDiv.appendChild(temaHeader);

    // Lista de subtemas (seleccionables)
    if (subtemas.length > 0) {
        const subtemasDiv = document.createElement('div');
        subtemasDiv.className = 'subtemas-list';

        subtemas.forEach(subtema => {
            const cantidadPreguntas = subtema.preguntas?.filter(p => p.verificada)?.length || 0;
            
            const subtemaDiv = document.createElement('div');
            subtemaDiv.className = 'subtema-item';
            subtemaDiv.innerHTML = `
                <input type="checkbox" id="subtema-${subtema.id}" data-subtema-id="${subtema.id}">
                <label for="subtema-${subtema.id}" style="flex: 1; cursor: pointer;">
                    ${subtema.nombre} <span style="color: #999;">(${cantidadPreguntas})</span>
                </label>
            `;

            subtemaDiv.querySelector('input').addEventListener('change', (e) => {
                if (e.target.checked) {
                    subtemasSeleccionados.push({
                        id: subtema.id,
                        nombre: subtema.nombre,
                        preguntas: subtema.preguntas || []
                    });
                } else {
                    subtemasSeleccionados = subtemasSeleccionados.filter(s => s.id !== subtema.id);
                }
            });

            subtemasDiv.appendChild(subtemaDiv);
        });

        // Inicialmente contraído
        subtemasDiv.style.display = 'none';
        temaDiv.appendChild(subtemasDiv);
        
        // Click en tema header para expandir/contraer
        temaHeader.style.cursor = 'pointer';
        temaHeader.addEventListener('click', () => {
            const isVisible = subtemasDiv.style.display !== 'none';
            subtemasDiv.style.display = isVisible ? 'none' : 'block';
            const icon = temaHeader.querySelector('.toggle-icon');
            icon.textContent = isVisible ? '▶' : '▼';
        });
    }

    return temaDiv;
}

// Verificar si hay opciones rápidas disponibles
function verificarOpcionesRapidas() {
    const ultimosParametros = localStorage.getItem('ultimosParametros');
    const preguntasFalladas = localStorage.getItem('preguntasFalladas');

    if (ultimosParametros || preguntasFalladas) {
        document.getElementById('opcionesRapidas').style.display = 'block';
    }

    if (!ultimosParametros) {
        document.getElementById('btnRepetirParametros').style.display = 'none';
    }

    if (!preguntasFalladas || JSON.parse(preguntasFalladas).length === 0) {
        document.getElementById('btnSoloFalladas').style.display = 'none';
    }
}

// Configurar eventos
function configurarEventos() {
    // Botones de cantidad
    document.querySelectorAll('.btn-cantidad').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.btn-cantidad').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            cantidadSeleccionada = parseInt(btn.dataset.cantidad);
            document.getElementById('cantidadPersonalizada').value = '';
        });
    });

    // Cantidad personalizada
    document.getElementById('cantidadPersonalizada').addEventListener('input', (e) => {
        if (e.target.value) {
            document.querySelectorAll('.btn-cantidad').forEach(b => b.classList.remove('active'));
            cantidadSeleccionada = parseInt(e.target.value) || 10;
        }
    });

    // Seleccionar primera opción por defecto
    document.querySelector('.btn-cantidad').classList.add('active');

    // Botón repetir parámetros
    document.getElementById('btnRepetirParametros')?.addEventListener('click', repetirUltimosParametros);

    // Botón solo falladas
    document.getElementById('btnSoloFalladas')?.addEventListener('click', cargarSoloFalladas);

    // Botón iniciar test
    document.getElementById('btnIniciarTest').addEventListener('click', iniciarTest);
}

// Repetir últimos parámetros
function repetirUltimosParametros() {
    const parametros = JSON.parse(localStorage.getItem('ultimosParametros'));
    if (!parametros) return;

    document.getElementById('nombreTest').value = parametros.nombre + ' (repetido)';
    cantidadSeleccionada = parametros.cantidad;

    // Marcar los subtemas
    parametros.subtemas.forEach(subtemaId => {
        const checkbox = document.querySelector(`input[data-subtema-id="${subtemaId}"]`);
        if (checkbox) {
            checkbox.checked = true;
            checkbox.dispatchEvent(new Event('change'));
        }
    });

    // Marcar cantidad
    const btnCantidad = document.querySelector(`[data-cantidad="${parametros.cantidad}"]`);
    if (btnCantidad) {
        document.querySelectorAll('.btn-cantidad').forEach(b => b.classList.remove('active'));
        btnCantidad.classList.add('active');
    } else {
        document.getElementById('cantidadPersonalizada').value = parametros.cantidad;
    }
}

// Cargar solo preguntas falladas
function cargarSoloFalladas() {
    const falladas = JSON.parse(localStorage.getItem('preguntasFalladas') || '[]');
    
    if (falladas.length === 0) {
        alert('No hay preguntas falladas guardadas');
        return;
    }

    // Guardar configuración de test solo con falladas
    const configTest = {
        nombre: 'Repaso Preguntas Falladas',
        soloFalladas: true,
        preguntas: falladas,
        fecha: new Date().toISOString()
    };

    sessionStorage.setItem('testActual', JSON.stringify(configTest));
    window.location.href = 'hacer-test.html';
}

// Iniciar test
async function iniciarTest() {
    const nombre = document.getElementById('nombreTest').value.trim() || 'Test sin nombre';

    if (subtemasSeleccionados.length === 0) {
        alert('Debes seleccionar al menos un subtema');
        return;
    }

    // Recopilar todas las preguntas verificadas de los subtemas seleccionados
    let preguntasDisponibles = [];
    subtemasSeleccionados.forEach(subtema => {
        const preguntasVerificadas = (subtema.preguntas || []).filter(p => p.verificada);
        preguntasDisponibles.push(...preguntasVerificadas.map(p => {
            // Extraer textos de opciones (vienen como array de objetos {texto, esCorrecta})
            const opcionesTexto = (p.opciones || []).map(op => op.texto || op);
            // Encontrar índice de respuesta correcta
            const respuestaCorrectaIndex = (p.opciones || []).findIndex(op => op.esCorrecta === true);
            
            return {
                texto: p.texto || '',
                opciones: opcionesTexto,
                respuestaCorrecta: respuestaCorrectaIndex >= 0 ? respuestaCorrectaIndex : 0,
                explicacion: p.explicacion || '',
                explicacionGemini: p.explicacionGemini || '',
                explicacionPDF: p.explicacionPDF || '',
                verificada: true,
                subtemaId: subtema.id,
                subtemaNombre: subtema.nombre
            };
        }));
    });

    if (preguntasDisponibles.length === 0) {
        alert('No hay preguntas verificadas en los subtemas seleccionados');
        return;
    }

    if (cantidadSeleccionada > preguntasDisponibles.length) {
        alert(`Solo hay ${preguntasDisponibles.length} preguntas disponibles. Se usarán todas.`);
        cantidadSeleccionada = preguntasDisponibles.length;
    }

    // Mezclar y seleccionar preguntas
    const preguntasTest = mezclarArray(preguntasDisponibles).slice(0, cantidadSeleccionada);

    // Guardar parámetros para repetir
    localStorage.setItem('ultimosParametros', JSON.stringify({
        nombre: nombre,
        subtemas: subtemasSeleccionados.map(s => s.id),
        cantidad: cantidadSeleccionada
    }));

    // Guardar configuración del test
    const configTest = {
        nombre: nombre,
        cantidad: cantidadSeleccionada,
        subtemas: subtemasSeleccionados.map(s => ({ id: s.id, nombre: s.nombre })),
        preguntas: preguntasTest,
        fecha: new Date().toISOString()
    };

    sessionStorage.setItem('testActual', JSON.stringify(configTest));
    window.location.href = 'hacer-test.html';
}

// Mezclar array
function mezclarArray(array) {
    const resultado = [...array];
    for (let i = resultado.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [resultado[i], resultado[j]] = [resultado[j], resultado[i]];
    }
    return resultado;
}
