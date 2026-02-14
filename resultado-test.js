import { auth } from './firebase-config.js';
import { onAuthStateChanged } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";

let currentUser = null;
let resultado = null;

// Verificar autenticación
onAuthStateChanged(auth, async (user) => {
    if (user) {
        currentUser = user;
        cargarResultado();
    } else {
        window.location.href = 'https://plataforma-examenes-f2df9.web.app/index.html';
    }
});

// Cargar resultado del test
function cargarResultado() {
    const resultadoGuardado = sessionStorage.getItem('resultadoTest');
    
    if (!resultadoGuardado) {
        alert('No hay resultado disponible');
        window.location.href = 'index.html';
        return;
    }
    
    resultado = JSON.parse(resultadoGuardado);
    mostrarResultado();
    configurarEventos();
}

// Mostrar resultado
function mostrarResultado() {
    // Mostrar nota
    document.getElementById('notaFinal').textContent = resultado.nota.toFixed(2);
    
    // Colorear nota según valor
    const notaElemento = document.getElementById('notaFinal');
    if (resultado.nota >= 45) {
        notaElemento.style.color = '#10b981'; // Verde
    } else if (resultado.nota >= 30) {
        notaElemento.style.color = '#f59e0b'; // Amarillo/Naranja
    } else {
        notaElemento.style.color = '#ef4444'; // Rojo
    }
    
    // Mostrar estadísticas
    document.getElementById('aciertos').textContent = resultado.aciertos;
    document.getElementById('fallos').textContent = resultado.fallos;
    document.getElementById('blanco').textContent = resultado.blanco;
    
    // Mostrar cálculo de la nota
    const calculoDiv = document.getElementById('calculoNota');
    calculoDiv.innerHTML = `
        <strong>Cálculo:</strong><br>
        Aciertos: ${resultado.aciertos}<br>
        Fallos: ${resultado.fallos} (penalización: -${(resultado.fallos / 3).toFixed(2)})<br>
        En blanco: ${resultado.blanco} (sin penalización)<br>
        <br>
        <strong>Puntos brutos:</strong> ${resultado.puntosBrutos.toFixed(2)}<br>
        <strong>Nota sobre 60:</strong> ${resultado.nota.toFixed(2)}
    `;
}

// Configurar eventos
function configurarEventos() {
    document.getElementById('btnVerDetalle').addEventListener('click', () => {
        window.location.href = `detalle-test.html?id=${resultado.id}`;
    });
}
