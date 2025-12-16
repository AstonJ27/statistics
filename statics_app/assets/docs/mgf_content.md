# Funciones Generadoras de Momentos (FGM)

La **FGM** $M_X(t)$ se define como el valor esperado de $e^{tX}$:

$$
M(t) = E[e^{tX}]
$$

---

## 1. Distribución Binomial
**Caso:** Discreta ($n$ ensayos, prob $p$).
$$P(X=x) = \binom{n}{x} p^x q^{n-x}$$

### Paso a paso:
1. Definición de la esperanza:
$$M(t) = \sum_{x=0}^{n} e^{tx} \binom{n}{x} p^x q^{n-x}$$

2. Agrupamos los términos con exponente $x$:
$$M(t) = \sum_{x=0}^{n} \binom{n}{x} (pe^t)^x q^{n-x}$$

3. Aplicamos el **Teorema del Binomio** $(a+b)^n$:
   Aquí $a = pe^t$ y $b = q$.

### Resultado:
$$M(t) = (q + pe^t)^n$$

---

## 2. Distribución de Poisson
**Caso:** Discreta (parámetro $\lambda$).
$$P(X=x) = \frac{e^{-\lambda} \lambda^x}{x!}$$

### Paso a paso:
1. Definición:
$$M(t) = \sum_{x=0}^{\infty} e^{tx} \frac{e^{-\lambda} \lambda^x}{x!}$$

2. Sacamos la constante $e^{-\lambda}$ y unimos potencias:
$$M(t) = e^{-\lambda} \sum_{x=0}^{\infty} \frac{(\lambda e^t)^x}{x!}$$

3. Usamos la serie de Taylor de la exponencial ($$e^{u} = \sum \frac{u^x}{x!}$$):
   Donde $u = \lambda e^t$.

4. Sustituimos:
$$M(t) = e^{-\lambda} \cdot e^{\lambda e^t}$$

### Resultado:
$$M(t) = e^{\lambda(e^t - 1)}$$

---

## 3. Distribución Exponencial
**Caso:** Continua (parámetro $$ \lambda $$).
$$f(x) = \lambda e^{-\lambda x}, \quad x > 0$$

### Paso a paso:
1. Definición (Integral):
$$M(t) = \int_{0}^{\infty} e^{tx} \lambda e^{-\lambda x} dx$$

2. Agrupamos exponentes:
$$M(t) = \lambda \int_{0}^{\infty} e^{-(\lambda - t)x} dx$$

3. Resolvemos la integral (para $t < \lambda$):
$$M(t) = \lambda \left[ \frac{e^{-(\lambda - t)x}}{-(\lambda - t)} \right]_{0}^{\infty}$$

4. Evaluando límites (en $\infty$ es 0, en $0$ es 1):
$$M(t) = \lambda \left( 0 - \frac{1}{-(\lambda - t)} \right)$$

### Resultado:
$$M(t) = \frac{\lambda}{\lambda - t}$$

---

## 4. Distribución Uniforme
**Caso:** Continua en $[a, b]$.
$$f(x) = \frac{1}{b-a}$$

### Paso a paso:
1. Definición:
$$M(t) = \int_{a}^{b} e^{tx} \frac{1}{b-a} dx$$

2. Sacamos la constante:
$$M(t) = \frac{1}{b-a} \int_{a}^{b} e^{tx} dx$$

3. Integramos:
$$M(t) = \frac{1}{b-a} \left[ \frac{e^{tx}}{t} \right]_{a}^{b}$$

### Resultado:
$$M(t) = \frac{e^{tb} - e^{ta}}{t(b-a)}$$

---

## 5. Distribución Normal
**Caso:** Continua ($$ \mu, \sigma^2 $$).

### Paso a paso simplificado:
1. Definición:
$$M(t) = \int_{-\infty}^{\infty} e^{tx} \frac{1}{\sqrt{2\pi}\sigma} e^{-\frac{(x-\mu)^2}{2\sigma^2}} dx$$

2. Completando cuadrados en el exponente:
   El término $tx$ se fusiona con el exponente cuadrático.
   
   $$\text{Exp} = tx - \frac{(x-\mu)^2}{2\sigma^2}$$

3. Tras reordenar algebraicamente, sale el factor constante:
   $$e^{\mu t + \frac{1}{2}\sigma^2 t^2}$$

### Resultado:
$$M(t) = e^{\mu t + \frac{1}{2}\sigma^2 t^2}$$
.
.
.
.
.
.