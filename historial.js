import { auth } from './js/firebase-config.js';
import { onAuthStateChanged } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";

let currentUser = null;

// Verificar autenticación
onAuthStateChanged(auth, async (user) => {
    if (user) {
        currentUser = user;
        cargarHistorial();
    } else {
        window.location.href = 'https://plataforma-examenes-f2df9.web.app/index.html';
    }
});

// Cargar historial de tests
function cargarHistorial() {
    const historial = JSON.parse(localStorage.getItem('historialTests') || '[]');
    const listaDiv = document.getElementById('listaHistorial');
    
    if (historial.length === 0) {
        listaDiv.innerHTML = '<p class="loading">No hay tests realizados aún</p>';
        return;
    }
    
    listaDiv.innerHTML = '';
    
    historial.forEach(test => {
        const item = crearItemHistorial(test);
        listaDiv.appendChild(item);
    });
}

// Crear elemento de historial
function crearItemHistorial(test) {
    const div = document.createElement('div');
    div.className = 'historial-item';
    
    const fecha = new Date(test.fecha);
    const fechaFormateada = fecha.toLocaleDateString('es-ES', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
    
    // Color de la nota
    let colorNota = '#667eea';
    if (test.nota >= 45) colorNota = '#10b981';
    else if (test.nota >= 30) colorNota = '#f59e0b';
    else colorNota = '#ef4444';
    
    div.innerHTML = `
        <h3>${test.nombre}</h3>
        <p>${fechaFormateada}</p>
        <p style="font-size: 14px; color: #666;">
            ✅ ${test.aciertos} | ❌ ${test.fallos} | ⚪ ${test.blanco}
        </p>
        <div class="historial-nota" style="color: ${colorNota};">
            ${test.nota.toFixed(2)}
        </div>
    `;
    
    div.addEventListener('click', () => {
        window.location.href = `detalle-test.html?id=${test.id}`;
    });
    
    return div;
}
