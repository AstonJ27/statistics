# 📘 Plan Maestro: Simulador de Colas Multietapa (Autolavado)

## 1\. Concepto del Sistema

Vamos a modelar un sistema de colas en serie (Pipeline). Imagina una línea de montaje donde un vehículo debe pasar secuencialmente por varias estaciones (Nodos).

  * **El Cliente (Carro):** Es una entidad que fluye a través del sistema.
  * **Las Estaciones (Stages):** Son los recursos limitados (ej. Limpieza, Lavado, Secado).
  * **El Conflicto:** Los carros llegan más rápido de lo que las estaciones pueden procesar, generando colas o abandonos.

### Las 3 Reglas de Negocio Clave (Tus requerimientos)

1.  **Aleatoriedad Pura (Sin Semillas):**

      * *Antes:* Usábamos una semilla fija para poder repetir el experimento exactamente igual.
      * *Ahora:* Usaremos la entropía del sistema operativo (reloj interno, ruido térmico del CPU) para generar los números. Cada vez que le des a "Simular", el resultado será distinto, reflejando la imprevisibilidad de la vida real.

2.  **Capacidad por Nodo (Concurrencia):**

      * *Antes:* Cada etapa atendía 1 carro a la vez.
      * *Ahora:* Cada etapa tiene $N$ servidores (empleados/máquinas).
          * Ejemplo: "Limpieza Preliminar" tiene capacidad 2. Significa que puede haber 2 carros siendo limpiados *simultáneamente*. El 3er carro tendrá que esperar o irse.

3.  **Comportamiento del Cliente (El Booleano `stay_until_finish`):**

      * Este flag define la **paciencia** del cliente una vez que ya inició el proceso.
      * **Escenario A (Cliente Impaciente / `false`):** Antes de entrar a *cualquier* etapa, el cliente mira si hay servidores libres. Si la etapa está llena (Capacidad al máximo), se va inmediatamente (Abandono/Reneging).
      * **Escenario B (Cliente Cautivo / `true`):** El cliente solo evalúa la *primera* etapa. Si logra entrar al sistema, se queda "atrapado" y esperará en cola lo que sea necesario en las siguientes etapas hasta terminar todo el circuito.

-----

## 2\. Arquitectura Técnica (Backend - Rust)

Rust será el motor de cálculo. Para lograr la máxima eficiencia ($O(N \log K)$), no simularemos segundo a segundo (Time-Slicing), sino que usaremos una **lógica de disponibilidad de recursos**.

### Estructuras de Datos (Structs)

Modificaremos `SimConfig` y `StageConfig` en `rust_core` para aceptar los nuevos parámetros.

```rust
struct StageConfig {
    name: String,
    dist_type: String, // Normal, Exponencial, Uniforme
    params: (f64, f64),
    capacity: usize,   // <--- NUEVO: Cuántos carros atiende a la vez
}

struct SimulationConfig {
    hours: u32,
    lambda_arrival: f64,     // Tasa de llegada (Poisson)
    stay_until_finish: bool, // <--- NUEVO: Regla de comportamiento
    stages: Vec<StageConfig>
}
```

### El Algoritmo de Simulación (El corazón del cambio)

Aquí es donde aplicamos las mejores prácticas de rendimiento. En lugar de hilos pesados, usaremos un **Heap de Tiempos Libres**.

Para cada etapa, en lugar de guardar un solo `free_time` (cuándo se libera la etapa), guardaremos una lista de tiempos de finalización de tamaño igual a la capacidad.

**Flujo paso a paso para un Carro:**

1.  **Llegada ($T_{llegada}$):** Calculamos cuándo llega el carro basado en una distribución Poisson desde el carro anterior.
2.  **Iteración por Etapas:** El carro intenta pasar por la Etapa 1, luego la 2, etc.
3.  **Evaluación de Capacidad (Min-Heap):**
      * Supongamos que la Etapa tiene capacidad 2. Tenemos dos "carriles".
      * Carril A se libera al minuto 10.
      * Carril B se libera al minuto 15.
      * *Lógica:* El carro siempre elegirá el carril que se libere *antes* (minuto 10).
4.  **Toma de Decisión (El Booleano):**
      * Comparamos $T_{llegada}$ vs $T_{libre\_carril}$.
      * Si $T_{llegada} < T_{libre\_carril}$ significa que **hay cola** (el carro llegó antes de que el servidor se desocupe).
      * **Si `stay_until_finish == false` Y hay cola:** El carro se marca como `Left` (Insatisfecho) y termina su simulación ahí.
      * **Si `stay_until_finish == true` O no hay cola:** El carro espera.
          * Nuevo $T_{inicio} = \max(T_{llegada}, T_{libre\_carril})$.
          * Calculamos duración del servicio (ej. 5 min).
          * $T_{fin} = T_{inicio} + 5$.
          * Actualizamos el tiempo libre de ese carril a $T_{fin}$.
5.  **Siguiente Etapa:** El $T_{llegada}$ a la siguiente etapa es el $T_{fin}$ de la actual.

-----

## 3\. Interfaz de Usuario (Frontend - Flutter)

Dart será responsable de recoger la configuración y pintar los resultados de forma atractiva.

### Cambios en Pantalla de Configuración (`simulation_page.dart`)

1.  **Toggle Global:** Un Switch o Checkbox para `stay_until_finish`.
      * *Label:* "Modo Estricto (Esperar hasta terminar)" o "Permitir abandono entre etapas".
2.  **Input por Etapa:** En el widget `StageInputList`, agregaremos un campo numérico "Capacidad" (Capacity) al lado de los parámetros de distribución.
      * *Default:* 1.

### Cambios en Visualización (`simulation_results.dart`)

1.  **Gráfica de Dona (Donut Chart):**
      * **Verde:** Clientes Satisfechos (Pasaron todas las etapas).
      * **Rojo:** Clientes Insatisfechos (Abandonaron).
          * Podemos subdividir el rojo en el futuro: "Abandonó al inicio" vs "Abandonó a la mitad", pero por ahora un solo rojo es suficiente.
      * **Gris/Naranja:** En proceso (Se acabó el tiempo de simulación y seguían dentro).

-----

## 4\. Comunicación de Datos (JSON Contract)

Este será el formato exacto del JSON que Flutter enviará a Rust. Definir esto es clave para que ambos "hablen el mismo idioma".

```json
{
  "hours": 8,
  "lambda_arrival": 3.5,
  "stay_until_finish": false,
  "stages": [
    {
      "name": "Limpieza Preliminar",
      "dist_type": "normal",
      "p1": 10.0, 
      "p2": 2.0,
      "capacity": 2  // <-- Nuevo
    },
    {
      "name": "Túnel de Lavado",
      "dist_type": "exponential",
      "p1": 5.0,
      "p2": 0.0,
      "capacity": 1  // <-- Cuello de botella clásico
    }
  ]
}
```

-----

## 5\. Resumen de Eficiencia y Mejores Prácticas

¿Por qué hacerlo así?

1.  **Rust Ownership:** Al manejar los vectores de tiempos dentro de Rust, evitamos la recolección de basura (GC) de Dart durante los millones de cálculos matemáticos.
2.  **Sin Hilos del OS:** Usar un enfoque matemático secuencial (iterando eventos) es infinitamente más rápido que crear un "Thread" por cada carro, consumiendo menos RAM.
3.  **Pre-cálculo de Distribuciones:** Como viste en el código anterior, instanciamos las distribuciones (`Normal::new`) *antes* del bucle. Esto ahorra ciclos de CPU valiosos dentro de la simulación.
4.  **Min-Heap para Capacidad:** Al buscar el servidor libre, usar una estructura ordenada nos da complejidad logarítmica, ideal si el usuario decide poner una etapa con capacidad de 100 servidores.

-----

### ¿Cuál es el siguiente paso?

Procederé a modificar **primero el lado de Rust (`rust_core`)**.

1.  Actualizaré las estructuras `struct` para incluir `capacity` y el flag booleano.
2.  Reescribiré la lógica del bucle `for hour in hours` para manejar múltiples servidores por etapa usando vectores de estado.
3.  Eliminaré cualquier rastro de semillas fijas (`seed`) y usaré `thread_rng()` para aleatoriedad real.

¿Te parece correcto este enfoque detallado? Si das luz verde, comienzo con la implementación del Backend en Rust.