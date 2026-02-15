\# App Móvil Sistema de Exámenes



Aplicación móvil Flutter para realizar tests de preparación de exámenes de justicia.



\## 📱 Estado del Proyecto



\*\*Versión:\*\* 1.0.0 (En desarrollo)  

\*\*Última actualización:\*\* 15 de febrero de 2026



\### ✅ Completado (Fase 1 y 2)



\#### Setup Inicial

\- \[x] Flutter SDK instalado y configurado

\- \[x] Proyecto Flutter creado

\- \[x] Firebase configurado (proyecto: plataforma-examenes-f2df9)

\- \[x] Dependencias instaladas (Firebase, Provider, Google Fonts)

\- \[x] Estructura de carpetas completa



\#### Modelos de Datos

\- \[x] Tema

\- \[x] Subtema

\- \[x] Pregunta (con campo explicación)

\- \[x] TestConfig

\- \[x] RespuestaUsuario

\- \[x] ResultadoTest (con sistema de puntuación completo)



\#### Servicios

\- \[x] AuthService (login, registro, logout)

\- \[x] TemasService (obtener temas y subtemas)

\- \[x] PreguntasService (obtener preguntas por subtemas)

\- \[x] TestService (calculadora de puntuación, guardar resultados)



\#### Pantallas

\- \[x] LoginScreen (funcional)

\- \[x] HomeScreen (funcional)



\#### Configuración

\- \[x] AppColors con paleta profesional

\- \[x] Firebase Options generado

\- \[x] MultiProvider configurado en main.dart



\### 🚧 Pendiente (Fase 3)



\#### Pantallas por Implementar

\- \[ ] ConfigurarTestScreen - Configuración de tests

\- \[ ] RealizarTestScreen - Realizar test con explicaciones inline

\- \[ ] ResultadosScreen - Mostrar resultados con puntuación

\- \[ ] DetalleTestScreen - Ver detalle completo del test

\- \[ ] HistorialScreen - Lista de tests realizados



\#### Servicios Adicionales

\- \[ ] Integrar todos los servicios con Provider



\## 🔥 Firebase



\*\*Proyecto:\*\* plataforma-examenes-f2df9  

\*\*Plataformas configuradas:\*\* Android, iOS, Web



\### Colecciones (Solo Lectura)

\- `usuarios`

\- `temas`

\- `subtemas`

\- `preguntas`



\### Colecciones (Escritura)

\- `resultados\_tests` (nueva, solo para app móvil)



\## 🎨 Diseño



\*\*Paleta de Colores:\*\*

\- Primary: `#1E40AF` (Azul oscuro)

\- Secondary: `#0EA5E9` (Azul cielo)

\- Success: `#10B981` (Verde)

\- Error: `#EF4444` (Rojo)



\## 🧮 Sistema de Puntuación



La app implementa el sistema oficial de puntuación con penalización:

```dart

penalizacion = incorrectas / (numOpciones - 1)

aciertosNetos = correctas - penalizacion

puntuacion = (aciertosNetos / totalPreguntas) \* 100

notaExamen = (aciertosNetos / totalPreguntas) \* 60

```



\## 🚀 Cómo Ejecutar

```bash

\# Instalar dependencias

flutter pub get



\# Ejecutar en Chrome

flutter run -d chrome



\# Ejecutar en Android

flutter run -d android



\# Ejecutar en iOS

flutter run -d ios

```



\## 📦 Dependencias Principales



\- `firebase\_core: ^3.3.0`

\- `firebase\_auth: ^5.1.4`

\- `cloud\_firestore: ^5.2.1`

\- `provider: ^6.1.1`

\- `google\_fonts: ^6.1.0`

\- `shared\_preferences: ^2.2.2`



\## 📝 Próximos Pasos



1\. Implementar ConfigurarTestScreen

2\. Implementar RealizarTestScreen con explicaciones inline

3\. Implementar ResultadosScreen con cálculos de puntuación

4\. Implementar HistorialScreen

5\. Testing completo en diferentes dispositivos

6\. Optimizaciones de rendimiento



\## 👨‍💻 Desarrollo



\*\*Entorno:\*\* Windows 10  

\*\*Flutter:\*\* 3.24.5  

\*\*Dart:\*\* 3.5.4

