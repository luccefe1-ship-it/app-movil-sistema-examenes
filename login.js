import { auth } from './firebase-config.js';
import { signInWithEmailAndPassword, onAuthStateChanged } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";

// Si ya está logueado, redirigir
onAuthStateChanged(auth, (user) => {
    if (user) {
        window.location.href = 'index.html';
    }
});

document.getElementById('btnLogin').addEventListener('click', async () => {
    const email = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value;
    const errorDiv = document.getElementById('error');

    if (!email || !password) {
        errorDiv.textContent = 'Por favor completa todos los campos';
        errorDiv.style.display = 'block';
        return;
    }

    try {
        await signInWithEmailAndPassword(auth, email, password);
        window.location.href = 'index.html';
    } catch (error) {
        console.error('Error login:', error);
        errorDiv.textContent = 'Email o contraseña incorrectos';
        errorDiv.style.display = 'block';
    }
});
