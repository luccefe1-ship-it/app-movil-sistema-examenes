import { auth } from './js/firebase-config.js';
import { onAuthStateChanged } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";

let currentUser = null;
let testDetalle = null;

// Verificar autenticación
onAuthStateChanged(auth, async (user) => {
    if (user) {
        currentUser = user;
        cargarDetalleTest();
    } else {
        window.location.href = 'https://plataforma-examenes-f2df9.web.app/index.html';
    }
});

// Cargar detalle del test
function cargarDetalleTest() {
    // Obtener ID del test desde URL
    const urlParams = new URLSearchParams(window.location.search);
    const testId = urlParams.get('id');
    
    if (!testId) {
        alert('Test no encontrado');
        window.location.href = 'historial.html';
        return;
    }
    
    // Cargar detalle desde localStorage
    const detalleGuardado = localStorage.getItem(`test_${testId}`);
    
    if (!detalleGuardado) {
        alert('No se encontraron los detalles del test');
        window.location.href = 'historial.html';
        return;
    }
    
    testDetalle = JSON.parse(detalleGuardado);
    mostrarDetalle();
}

// Mostrar detalle del test
function mostrarDetalle() {
    // Información general
    document.getElementById('nombreTest').textContent = testDetalle.nombre;
    
    const fecha = new Date(testDetalle.fecha);
    const fechaFormateada = fecha.toLocaleDateString('es-ES', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
    document.getElementById('fechaTest').textContent = fechaFormateada;
    
    // Nota con color
    const notaElemento = document.getElementById('notaDetalle');
    notaElemento.textContent = testDetalle.nota.toFixed(2);
    
    if (testDetalle.nota >= 45) {
        notaElemento.style.color = '#10b981';
    } else if (testDetalle.nota >= 30) {
        notaElemento.style.color = '#f59e0b';
    } else {
        notaElemento.style.color = '#ef4444';
    }
    
    // Mostrar preguntas con respuestas
    const preguntasDiv = document.getElementById('preguntasDetalle');
    preguntasDiv.innerHTML = '';
    
    testDetalle.detallePreguntas.forEach((detalle, index) => {
        const preguntaDiv = crearPreguntaDetalle(detalle, index);
        preguntasDiv.appendChild(preguntaDiv);
    });
}

// Crear elemento de pregunta con detalle
function crearPreguntaDetalle(detalle, index) {
    const div = document.createElement('div');
    
    // Clase según resultado
    let clase = 'pregunta-detalle';
    if (detalle.esBlanco) {
        clase += ' blanco';
    } else if (detalle.esCorrecta) {
        clase += ' correcta';
    } else {
        clase += ' incorrecta';
    }
    
    div.className = clase;
    
    // Icono según resultado
    let icono = '⚪';
    let textoEstado = 'En blanco';
    if (!detalle.esBlanco) {
        if (detalle.esCorrecta) {
            icono = '✅';
            textoEstado = 'Correcta';
        } else {
            icono = '❌';
            textoEstado = 'Incorrecta';
        }
    }
    
    // Construir HTML
    let html = `
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
            <strong>Pregunta ${index + 1}</strong>
            <span style="font-size: 20px;">${icono}</span>
        </div>
        <p style="margin-bottom: 12px; color: #333;">${detalle.pregunta}</p>
    `;
    
    // Mostrar opciones
    detalle.opciones.forEach((opcion, i) => {
        let estiloOpcion = 'padding: 8px 12px; margin: 4px 0; border-radius: 6px; font-size: 14px;';
        
        if (i === detalle.respuestaCorrecta) {
            // Respuesta correcta
            estiloOpcion += 'background: #d1fae5; border: 2px solid #10b981;';
        } else if (i === detalle.respuestaUsuario) {
            // Respuesta incorrecta del usuario
            estiloOpcion += 'background: #fee2e2; border: 2px solid #ef4444;';
        } else {
            estiloOpcion += 'background: #f5f5f5; border: 2px solid #e0e0e0;';
        }
        
        html += `<div style="${estiloOpcion}">${String.fromCharCode(65 + i)}) ${opcion}</div>`;
    });
    
    // Mostrar explicación si existe
    if (detalle.explicacion) {
        html += `
            <div style="margin-top: 12px; padding: 10px; background: #f0f4ff; border-radius: 6px; border-left: 3px solid #667eea;">
                <strong style="color: #667eea;">💡 Explicación:</strong>
                <p style="margin-top: 6px; font-size: 14px; color: #333;">${detalle.explicacion}</p>
            </div>
        `;
    }
    
    div.innerHTML = html;
    return div;
}
