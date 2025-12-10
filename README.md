
# 📊 Statistics App (Flutter + Rust)

Una aplicación móvil de alto rendimiento para **Estadística Inferencial y Descriptiva**, construida con una arquitectura híbrida que combina la flexibilidad de **Flutter** para la interfaz de usuario con la potencia y seguridad de memoria de **Rust** para los cálculos numéricos intensivos.

## 🚀 Propósito del Proyecto

El objetivo principal es proveer una herramienta robusta y modular para el análisis estadístico y la simulación de procesos estocásticos. La aplicación resuelve dos problemas fundamentales:

1.  **Análisis Descriptivo Completo:** Procesamiento de datos crudos o agrupados para generar métricas precisas, gráficos y ajustes de distribución.
2.  **Simulación de Procesos (Colas/Pipelines):** Modelado de sistemas de eventos discretos (como un autolavado o línea de producción) con múltiples etapas y distribuciones probabilísticas dinámicas.

-----

## 🏗️ Arquitectura del Sistema

El proyecto sigue una arquitectura **Modular por Funcionalidad (Feature-first)** en el frontend y una arquitectura de **Núcleo de Cálculo (Compute Core)** en el backend.

### Stack Tecnológico

  * **Frontend:** Flutter (Dart).
  * **Backend / Core:** Rust.
  * **Comunicación:** FFI (Foreign Function Interface) vía `dart:ffi`.
  * **Formato de Intercambio:** Punteros directos a memoria (para arrays de datos) y Strings JSON (para resultados estructurados).

### Flujo de Datos General

1.  **Input (Flutter):** El usuario ingresa datos (CSV, Tabla Manual, Parámetros).
2.  **Bridge (NativeService):** Dart asigna memoria nativa, copia los datos y llama a la función externa de Rust.
3.  **Process (Rust Core):** Rust toma el puntero, reconstruye los datos, ejecuta algoritmos optimizados ($O(N)$ o $O(N \log N)$) y serializa el resultado a JSON.
4.  **Output (Flutter):** Dart recibe el JSON, lo deserializa en Modelos y renderiza los Widgets.

-----

## 📂 Estructura del Proyecto

### 1\. `rust_core/` (El Cerebro Matemático)

Contiene toda la lógica de negocio pesada. No tiene dependencias de UI.

| Archivo / Directorio | Responsabilidad Principal |
| :--- | :--- |
| **`lib.rs`** | **Fachada (Facade).** Exponer las funciones `extern "C"` que Dart puede llamar. Transforma punteros crudos en estructuras Rust seguras. |
| **`analysis.rs`** | **Orquestador.** Coordina el análisis descriptivo completo. Recibe datos, los ordena, llama a los módulos de agregación y ensambla el JSON final. |
| **`stats/summary.rs`** | Cálculo de estadísticos básicos: Media, Mediana, Moda (algoritmo lineal), Varianza, Desviación, Sesgo, Curtosis y CV. |
| **`aggregation/`** | Módulos para transformar datos en estructuras visuales: |
| ├── `histogram.rs` | Calcula bins, bordes y alturas usando la Regla de Sturges o clases forzadas. |
| ├── `boxplot.rs` | Calcula cuartiles, rango intercuartílico (IQR) y detecta outliers. |
| ├── `freq_table.rs` | Genera la tabla de frecuencias (Absoluta, Relativa, Acumulada). |
| └── `stem_leaf.rs` | Genera el diagrama de Tallo y Hoja. |
| **`simulations/carwash.rs`** | **Motor de Simulación.** Implementa la lógica de eventos discretos para sistemas de colas (ej. autolavado). Maneja entidades, tiempos de espera y estados. |
| **`sampling/generator.rs`** | Generación de números pseudoaleatorios (Normal, Uniforme, Exponencial) usando `rand_chacha` para alta velocidad. |
| **`probabilities/`** | Funciones de Densidad (PDF) y Acumuladas (CDF) para calcular el "Best Fit" y curvas de ajuste. |

### 2\. `statics_app/` (La Interfaz de Usuario)

Aplicación Flutter modularizada para mantenibilidad.

| Directorio | Contenido y Responsabilidad |
| :--- | :--- |
| **`lib/core/ffi/`** | **Puente Nativo.** |
| ├── `ffi_bindings.dart` | Definiciones de tipos C (`Int32`, `Double`, `Pointer`) y firmas de funciones. |
| └── `native_service.dart` | Clase estática que abstrae la complejidad de FFI. Maneja la asignación/liberación de memoria (`calloc`, `free`). |
| **`lib/modules/descriptive/`** | **Módulo 1: Estadística Descriptiva.** |
| ├── `screens/descriptive_page.dart` | Pantalla principal. Gestiona el estado de los inputs y muestra los resultados. |
| ├── `widgets/data_input_forms.dart` | **Lógica de Entrada.** Maneja formularios inteligentes para CSV, Tablas y Histogramas. Realiza la inferencia de límites y expansión de datos. |
| ├── `models/descriptive_models.dart` | Mapea el JSON de Rust a objetos Dart (`AnalyzeResult`, `HistogramData`). |
| └── `widgets/*` | Componentes visuales: `HistogramPainter` (Canvas), `BoxplotWidget`, `StemLeafWidget`. |
| **`lib/modules/simulation/`** | **Módulo 2: Simulación.** |
| ├── `screens/simulation_page.dart` | Pantalla de configuración de la simulación. |
| ├── `widgets/stage_input_list.dart` | Lista dinámica para agregar/quitar estaciones del sistema. |
| ├── `widgets/simulation_results.dart` | Visualización de métricas de simulación (Donuts, Listas de tiempos). |
| └── `models/simulation_models.dart` | Modelos para los resultados de la simulación (`SimResultV2`, `HourMetrics`). |

-----

## 🌟 Características Clave & Lógica de Negocio

### Módulo 1: Estadística Descriptiva

  * **Entrada de Datos Flexible:**
      * **Generador Aleatorio:** Crea muestras usando el motor de Rust.
      * **Manual (CSV):** Parsea texto libre.
      * **Tabla de Frecuencias / Histograma:** Implementa un algoritmo de **"Reconstrucción de Datos"**. Si el usuario ingresa datos agrupados, el sistema expande estos datos basándose en la frecuencia y la marca de clase para permitir que el motor de Rust (diseñado para datos crudos) procese todo sin cambios.
  * **Inferencia de Datos:** Si el usuario ingresa una tabla incompleta (ej. solo marcas sin límites), el sistema infiere los intervalos basándose en la amplitud detectada.
  * **Análisis "Best Fit":** Calcula automáticamente qué distribución (Normal, Exponencial, Uniforme, LogNormal) se ajusta mejor a los datos usando el criterio **AIC (Akaike Information Criterion)**.

### Módulo 2: Simulación de Procesos

  * **Pipeline Dinámico:** El usuario puede configurar $N$ etapas (ej. Lavado, Secado, Pulido).
  * **Distribuciones por Etapa:** Cada etapa puede tener su propio comportamiento probabilístico (Normal, Exponencial, Uniforme).
  * **Optimización:** El backend pre-calcula las distribuciones antes del bucle de simulación para evitar el overhead de instanciación en tiempo de ejecución (Montecarlo eficiente).

-----

## 🛠️ Guía de Compilación (Build)

Para ejecutar este proyecto, necesitas compilar la librería de Rust y enlazarla con Flutter.

### Prerrequisitos

1.  Flutter SDK instalado.
2.  Rust & Cargo instalados.
3.  NDK de Android (si compilas para Android).

### Pasos Generales

1.  **Compilar Rust:**
    Navega a `rust_core/` y compila la librería compartida (`.so` para Android, `.dll` para Windows, `.dylib` para macOS/iOS).

      * *Nota: El proyecto incluye scripts (ej. `build_apk.sh`) que automatizan la compilación cruzada para arquitecturas Android (`arm64-v8a`, `armeabi-v7a`, `x86_64`).*

2.  **Ubicación de Binarios:**
    Los archivos compilados (`libstat_core.so`) deben colocarse en la carpeta `android/app/src/main/jniLibs/<arch>/` de la app Flutter.

3.  **Ejecutar Flutter:**

    ```bash
    cd statics_app
    flutter pub get
    flutter run
    ```

-----

> **Nota para Desarrolladores:** Este proyecto hace un uso intensivo de `unsafe` en el lado de Rust para manejar punteros crudos. Cualquier cambio en las firmas de `extern "C"` en `lib.rs` debe reflejarse inmediatamente en `ffi_bindings.dart` para evitar errores de segmentación (Segfaults).
