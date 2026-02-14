import { auth, db } from './firebase-config.js';
import { onAuthStateChanged, signOut } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { doc, getDoc } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";

let currentUser = null;

// Verificar autenticación
onAuthStateChanged(auth, async (user) => {
    if (user) {
        currentUser = user;
        await cargarDatosUsuario();
    } else {
        // Redirigir a login de la plataforma principal
        window.location.href = 'login.html';
    }
});

// Cargar datos del usuario
async function cargarDatosUsuario() {
    try {
        const userDoc = await getDoc(doc(db, "usuarios", currentUser.uid));
        if (userDoc.exists()) {
            document.getElementById('userName').textContent = userDoc.data().nombre;
        } else {
            document.getElementById('userName').textContent = currentUser.email;
        }
    } catch (error) {
        console.error('Error cargando usuario:', error);
        document.getElementById('userName').textContent = currentUser.email;
    }
}

// Logout
document.getElementById('logoutBtn').addEventListener('click', async () => {
    try {
        await signOut(auth);
        window.location.href = 'login.html';
    } catch (error) {
        console.error('Error cerrando sesión:', error);
        alert('Error al cerrar sesión');
    }
});
