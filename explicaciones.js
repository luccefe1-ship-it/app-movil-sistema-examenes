import { auth, db, storage } from './js/firebase-config.js';
import { onAuthStateChanged } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { collection, query, where, getDocs } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";
import { ref, getDownloadURL } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-storage.js";

let currentUser = null;
let explicaciones = [];
let explicacionesFiltradas = [];

// Verificar autenticación
onAuthStateChanged(auth, async (user) => {
    if (user) {
        currentUser = user;
        await cargarExplicaciones();
        configurarBusqueda();
    } else {
        window.location.href = 'https://plataforma-examenes-f2df9.web.app/index.html';
    }
});

// Cargar explicaciones del usuario
async function cargarExplicaciones() {
    try {
        const listaDiv = document.getElementById('listaExplicaciones');
        listaDiv.innerHTML = '<p class="loading">Cargando explicaciones...</p>';
        
        // Cargar temas del usuario
        const q = query(collection(db, "temas"), where("usuarioId", "==", currentUser.uid));
        const snapshot = await getDocs(q);
        
        explicaciones = [];
        
        // Recorrer temas y subtemas buscando preguntas con explicación
        snapshot.forEach((doc) => {
            const tema = doc.data();
            const temaId = doc.id;
            
            if (tema.preguntas && Array.isArray(tema.preguntas)) {
                tema.preguntas.forEach((pregunta, index) => {
                    if (pregunta.explicacion || pregunta.explicacionGemini || pregunta.explicacionPDF) {
                        explicaciones.push({
                            temaId: temaId,
                            temaNombre: tema.nombre,
                            preguntaIndex: index,
                            preguntaTexto: pregunta.texto,
                            explicacion: pregunta.explicacion || null,
                            explicacionGemini: pregunta.explicacionGemini || null,
                            explicacionPDF: pregunta.explicacionPDF || null,
                            pdfPath: pregunta.pdfPath || null,
                            pdfPage: pregunta.pdfPage || null
                        });
                    }
                });
            }
        });
        
        if (explicaciones.length === 0) {
            listaDiv.innerHTML = '<p class="loading">No tienes explicaciones guardadas</p>';
            return;
        }
        
        explicacionesFiltradas = [...explicaciones];
        mostrarExplicaciones();
        
    } catch (error) {
        console.error('Error cargando explicaciones:', error);
        document.getElementById('listaExplicaciones').innerHTML = '<p style="color: red; text-align: center;">Error cargando explicaciones</p>';
    }
}

// Mostrar explicaciones
function mostrarExplicaciones() {
    const listaDiv = document.getElementById('listaExplicaciones');
    
    if (explicacionesFiltradas.length === 0) {
        listaDiv.innerHTML = '<p class="loading">No se encontraron explicaciones</p>';
        return;
    }
    
    listaDiv.innerHTML = '';
    
    explicacionesFiltradas.forEach(exp => {
        const item = crearItemExplicacion(exp);
        listaDiv.appendChild(item);
    });
}

// Crear elemento de explicación
function crearItemExplicacion(exp) {
    const div = document.createElement('div');
    div.className = 'explicacion-item';
    
    let html = `
        <div style="margin-bottom: 10px;">
            <strong style="color: #667eea; font-size: 14px;">${exp.temaNombre}</strong>
        </div>
        <p style="margin-bottom: 12px; color: #333; font-size: 15px;">${exp.preguntaTexto}</p>
    `;
    
    // Mostrar explicación manual si existe
    if (exp.explicacion) {
        html += `
            <div style="padding: 10px; background: #f0f4ff; border-radius: 6px; margin-bottom: 8px;">
                <strong style="color: #667eea;">📝 Explicación manual:</strong>
                <p style="margin-top: 6px; font-size: 14px; color: #333;">${exp.explicacion}</p>
            </div>
        `;
    }
    
    // Mostrar explicación Gemini si existe
    if (exp.explicacionGemini) {
        html += `
            <div style="padding: 10px; background: #fef3c7; border-radius: 6px; margin-bottom: 8px;">
                <strong style="color: #f59e0b;">🤖 Explicación Gemini:</strong>
                <p style="margin-top: 6px; font-size: 14px; color: #333;">${exp.explicacionGemini}</p>
            </div>
        `;
    }
    
    // Mostrar explicación PDF si existe
    if (exp.explicacionPDF) {
        html += `
            <div style="padding: 10px; background: #fee2e2; border-radius: 6px; margin-bottom: 8px;">
                <strong style="color: #ef4444;">📄 Explicación PDF:</strong>
                <p style="margin-top: 6px; font-size: 14px; color: #333;">${exp.explicacionPDF}</p>
                ${exp.pdfPath ? `<p style="margin-top: 4px; font-size: 12px; color: #666;">Fuente: ${exp.pdfPath} - Página ${exp.pdfPage || '?'}</p>` : ''}
            </div>
        `;
    }
    
    div.innerHTML = html;
    return div;
}

// Configurar búsqueda
function configurarBusqueda() {
    const inputBuscar = document.getElementById('buscarExplicacion');
    
    inputBuscar.addEventListener('input', (e) => {
        const termino = e.target.value.toLowerCase().trim();
        
        if (!termino) {
            explicacionesFiltradas = [...explicaciones];
        } else {
            explicacionesFiltradas = explicaciones.filter(exp => {
                return exp.preguntaTexto.toLowerCase().includes(termino) ||
                       exp.temaNombre.toLowerCase().includes(termino) ||
                       (exp.explicacion && exp.explicacion.toLowerCase().includes(termino)) ||
                       (exp.explicacionGemini && exp.explicacionGemini.toLowerCase().includes(termino)) ||
                       (exp.explicacionPDF && exp.explicacionPDF.toLowerCase().includes(termino));
            });
        }
        
        mostrarExplicaciones();
    });
}
