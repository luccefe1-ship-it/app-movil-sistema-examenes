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

        const temasPrincipales = [];
        const subtemasMap = new Map();

        snapshot.forEach((doc) => {
            const tema = { id: doc.id, ...doc.data() };
            
            if (tema.temaPadreId) {
                if (!subtemasMap.has(tema.temaPadreId)) {
                    subtemasMap.set(tema.temaPadreId, []);
                }
                subtemasMap.get(tema.temaPadreId).push(tema);
            } else {
                temasPrincipales.push(tema);
            }
        });

        temasPrincipales.sort((a, b) => a.nombre.localeCompare(b.nombre, undefined, { numeric: true, sensitivity: 'base' }));
        
        subtemasMap.forEach((subtemas) => {
            subtemas.sort((a, b) => a.nombre.localeCompare(b.nombre, undefined, { numeric: true, sensitivity: 'base' }));
        });

        if (temasPrincipales.length === 0) {
            listaTemas.innerHTML = '<p style="color: white; text-align: center; padding: 20px;">No tienes temas creados en la plataforma de escritorio.<br><br>Crea temas y preguntas en:<br><a href="https://plataforma-examenes-f2df9.web.app" style="color: white; text-decoration: underline;">plataforma-examenes-f2df9.web.app</a></p>';
            return;
        }

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

function crearElementoTema(tema, subtemas) {
    const temaDiv = document.createElement('div');
    temaDiv.className = 'tema-item';

    const cantidadPreguntasTema = tema.preguntas?.filter(p => p.verificada)?.length || 0;
    
    let infoExtra = '';
    if (subtemas.length > 0) {
        infoExtra = `${subtemas.length} subtemas <span class="toggle-icon">▶</span>`;
    } else if (cantidadPreguntasTema > 0) {
        infoExtra = `${cantidadPreguntasTema}`;
    }

    const temaHeader = document.createElement('div');
    temaHeader.className = 'tema-header';
    
    temaHeader.innerHTML = `
        <input type="checkbox" id="tema-${tema.id}" data-tema-id="${tema.id}">
        <label for="tema-${tema.id}" style="flex: 1; cursor: pointer; font-weight: 600;">
            ${tema.nombre}
        </label>
        <span style="color: #999; font-size: 14px;">${infoExtra}</span>
    `;
    
    const checkboxTema = temaHeader.querySelector('input');
    checkboxTema.addEventListener('change', (e) => {
        if (e.target.checked) {
            if (subtemas.length > 0) {
                subtemas.forEach(subtema => {
                    const checkboxSubtema = document.querySelector(`#subtema-${CSS.escape(subtema.id)}`);
                    if (checkboxSubtema && !checkboxSubtema.checked) {
                        checkboxSubtema.checked = true;
                        checkboxSubtema.dispatchEvent(new Event('change'));
                    }
                });
            } else if (cantidadPreguntasTema > 0) {
                subtemasSeleccionados.push({
                    id: tema.id,
                    nombre: tema.nombre,
                    preguntas: tema.preguntas || []
                });
            }
        } else {
            if (subtemas.length > 0) {
                subtemas.forEach(subtema => {
                    const checkboxSubtema = document.querySelector(`#subtema-${CSS.escape(subtema.id)}`);
                    if (checkboxSubtema && checkboxSubtema.checked) {
                        checkboxSubtema.checked = false;
                        checkboxSubtema.dispatchEvent(new Event('change'));
                    }
                });
            } else {
                subtemasSeleccionados = subtemasSeleccionados.filter(s => s.id !== tema.id);
            }
        }
    });
    
    temaDiv.appendChild(temaHeader);

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
                    const checkboxTema = temaDiv.querySelector('input[data-tema-id]');
                    if (checkboxTema) {
                        checkboxTema.checked = false;
                    }
                }
            });

            subtemasDiv.appendChild(subtemaDiv);
        });

        subtemasDiv.style.display = 'none';
        temaDiv.appendChild(subtemasDiv);
        
        const toggleIcon = temaHeader.querySelector('.toggle-icon');
        if (toggleIcon) {
            toggleIcon.parentElement.style.cursor = 'pointer';
            toggleIcon.parentElement.addEventListener('click', (e) => {
                if (e.target.tagName !== 'INPUT' && e.target.tagName !== 'LABEL') {
                    const isVisible = subtemasDiv.style.display !== 'none';
                    subtemasDiv.style.display = isVisible ? 'none' : 'block';
                    toggleIcon.textContent = isVisible ? '▶' : '▼';
                }
            });
        }
    }

    return temaDiv;
}

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

function configurarEventos() {
    document.querySelectorAll('.btn-cantidad').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.btn-cantidad').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            cantidadSeleccionada = parseInt(btn.dataset.cantidad);
            document.getElementById('cantidadPersonalizada').value = '';
        });
    });

    document.getElementById('cantidadPersonalizada').addEventListener('input', (e) => {
        if (e.target.value) {
            document.querySelectorAll('.btn-cantidad').forEach(b => b.classList.remove('active'));
            cantidadSeleccionada = parseInt(e.target.value) || 10;
        }
    });

    document.querySelector('.btn-cantidad').classList.add('active');

    document.getElementById('btnRepetirParametros')?.addEventListener('click', repetirUltimosParametros);
    document.getElementById('btnSoloFalladas')?.addEventListener('click', cargarSoloFalladas);
    document.getElementById('btnIniciarTest').addEventListener('click', iniciarTest);
}

// Repetir últimos parámetros
function repetirUltimosParametros() {
    const parametros = JSON.parse(localStorage.getItem('ultimosParametros'));
    if (!parametros) return;

    // ===== DEBUG LOGS =====
    console.log('%c=== DEBUG REPETIR PARÁMETROS ===', 'color: red; font-size: 16px;');
    console.log('Parámetros completos:', JSON.stringify(parametros, null, 2));
    console.log('IDs de subtemas guardados:', parametros.subtemas);
    console.log('Tipo de cada ID:', parametros.subtemas.map(s => `${s} (${typeof s})`));

    // FIX nombre: limpiar todo y añadir un solo "(repetido)"
    let nombreBase = parametros.nombre;
    nombreBase = nombreBase.replace(/\s*\(repetido\)/g, '');
    nombreBase = nombreBase.replace(/\s*repetidox\d+/g, '');
    nombreBase = nombreBase.trim();
    document.getElementById('nombreTest').value = nombreBase + ' (repetido)';
    
    cantidadSeleccionada = parametros.cantidad;

    // Expandir todos los temas
    document.querySelectorAll('.subtemas-list').forEach(list => {
        list.style.display = 'block';
    });
    document.querySelectorAll('.toggle-icon').forEach(icon => {
        icon.textContent = '▼';
    });

    // Limpiar selección previa
    subtemasSeleccionados = [];

    // DEBUG: Listar TODOS los checkboxes del DOM
    const todosSubtemas = document.querySelectorAll('input[data-subtema-id]');
    const todosTemas = document.querySelectorAll('input[data-tema-id]');
    console.log(`Checkboxes en DOM: ${todosTemas.length} temas, ${todosSubtemas.length} subtemas`);
    console.log('IDs subtemas en DOM:', Array.from(todosSubtemas).map(cb => `"${cb.dataset.subtemaId}" (${typeof cb.dataset.subtemaId})`));
    console.log('IDs temas en DOM:', Array.from(todosTemas).map(cb => `"${cb.dataset.temaId}" (${typeof cb.dataset.temaId})`));

    // Esperar a que el DOM se actualice
    setTimeout(() => {
        let encontrados = 0;
        let noEncontrados = 0;

        parametros.subtemas.forEach(subtemaId => {
            const idStr = String(subtemaId);
            
            // Buscar como subtema
            const checkboxSubtema = document.querySelector(`input[data-subtema-id="${idStr}"]`);
            // Buscar como tema (tema sin hijos)
            const checkboxTema = document.querySelector(`input[data-tema-id="${idStr}"]`);
            
            console.log(`Buscando ID "${idStr}": subtema=${!!checkboxSubtema}, tema=${!!checkboxTema}`);
            
            if (checkboxSubtema && !checkboxSubtema.checked) {
                checkboxSubtema.checked = true;
                checkboxSubtema.dispatchEvent(new Event('change'));
                encontrados++;
            } else if (checkboxTema && !checkboxTema.checked) {
                checkboxTema.checked = true;
                checkboxTema.dispatchEvent(new Event('change'));
                encontrados++;
            } else if (!checkboxSubtema && !checkboxTema) {
                noEncontrados++;
                console.warn(`ID "${idStr}" NO ENCONTRADO en ningún checkbox del DOM`);
            }
        });
        
        console.log(`Resultado: ${encontrados} encontrados, ${noEncontrados} NO encontrados`);
        
        // Marcar temas padre si TODOS sus subtemas están marcados
        setTimeout(() => {
            document.querySelectorAll('.tema-item').forEach(temaItem => {
                const checkboxTema = temaItem.querySelector(':scope > .tema-header input[data-tema-id]');
                if (!checkboxTema || checkboxTema.checked) return;
                
                const subtemasListDiv = temaItem.querySelector(':scope > .subtemas-list');
                if (!subtemasListDiv) return;
                
                const checkboxesHijos = subtemasListDiv.querySelectorAll('input[data-subtema-id]');
                if (checkboxesHijos.length === 0) return;
                
                const todosChecked = Array.from(checkboxesHijos).every(cb => cb.checked);
                
                if (todosChecked) {
                    checkboxTema.checked = true;
                    console.log(`Tema padre "${checkboxTema.dataset.temaId}" marcado (todos ${checkboxesHijos.length} subtemas OK)`);
                }
            });
            
            console.log('%c=== FIN DEBUG ===', 'color: red; font-size: 16px;');
            console.log('subtemasSeleccionados:', subtemasSeleccionados.length, subtemasSeleccionados.map(s => s.id));
        }, 200);
    }, 300);

    // Marcar cantidad
    const btnCantidad = document.querySelector(`[data-cantidad="${parametros.cantidad}"]`);
    if (btnCantidad) {
        document.querySelectorAll('.btn-cantidad').forEach(b => b.classList.remove('active'));
        btnCantidad.classList.add('active');
    } else {
        document.getElementById('cantidadPersonalizada').value = parametros.cantidad;
    }
}

function cargarSoloFalladas() {
    const falladas = JSON.parse(localStorage.getItem('preguntasFalladas') || '[]');
    
    if (falladas.length === 0) {
        alert('No hay preguntas falladas guardadas');
        return;
    }

    const configTest = {
        nombre: 'Repaso Preguntas Falladas',
        soloFalladas: true,
        preguntas: falladas,
        fecha: new Date().toISOString()
    };

    sessionStorage.setItem('testActual', JSON.stringify(configTest));
    window.location.href = 'hacer-test.html';
}

async function iniciarTest() {
    const nombre = document.getElementById('nombreTest').value.trim() || 'Test sin nombre';

    if (subtemasSeleccionados.length === 0) {
        alert('Debes seleccionar al menos un subtema');
        return;
    }

    let preguntasDisponibles = [];
    subtemasSeleccionados.forEach(subtema => {
        const preguntasVerificadas = (subtema.preguntas || []).filter(p => p.verificada);
        preguntasDisponibles.push(...preguntasVerificadas.map(p => {
            const opcionesTexto = (p.opciones || []).map(op => op.texto || op);
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

    const preguntasTest = mezclarArray(preguntasDisponibles).slice(0, cantidadSeleccionada);

    // FIX: Guardar nombre LIMPIO sin sufijos de repetición
    let nombreLimpio = nombre;
    nombreLimpio = nombreLimpio.replace(/\s*\(repetido\)/g, '');
    nombreLimpio = nombreLimpio.replace(/\s*repetidox\d+/g, '');
    nombreLimpio = nombreLimpio.trim();

    localStorage.setItem('ultimosParametros', JSON.stringify({
        nombre: nombreLimpio,
        subtemas: subtemasSeleccionados.map(s => s.id),
        cantidad: cantidadSeleccionada
    }));

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

function mezclarArray(array) {
    const resultado = [...array];
    for (let i = resultado.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [resultado[i], resultado[j]] = [resultado[j], resultado[i]];
    }
    return resultado;
}
