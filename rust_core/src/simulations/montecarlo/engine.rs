use rand::prelude::*;
use rand_distr::{Exp, Normal, Uniform, Distribution};
use crate::errors::Error;
use super::models::*;

// Enum optimizado para evitar 'match' de strings dentro del bucle
enum FastDist {
    Norm(Normal<f64>, f64), // Dist, Multiplier
    Expon(Exp<f64>, f64),
    Unif(Uniform<f64>, f64),
}

impl FastDist {
    #[inline(always)]
    fn sample<R: Rng + ?Sized>(&self, rng: &mut R) -> f64 {
        match self {
            FastDist::Norm(d, m) => d.sample(rng) * m,
            FastDist::Expon(d, m) => d.sample(rng) * m,
            FastDist::Unif(d, m) => d.sample(rng) * m,
        }
    }
}

pub fn execute(config: MonteCarloConfig) -> Result<MonteCarloResponse, Error> {
    if config.n_simulations == 0 { return Err(Error::NullOrEmptyInput); }

    // 1. Preparación (Pre-flight)
    let mut distributions = Vec::with_capacity(config.variables.len());
    
    for v in &config.variables {
        let dist = match v.distribution {
            DistType::Normal { mean, variance } => {
                if variance < 0.0 { return Err(Error::Other(format!("Std Dev negativa en {}", v.name))); }
                let std = variance.sqrt();
                FastDist::Norm(Normal::new(mean, std).unwrap(), v.multiplier)
            },
            DistType::Exponential { beta } => {
                if beta <= 0.0 { return Err(Error::Other(format!("Beta <= 0 en {}", v.name))); }
                // Rust usa lambda, el usuario da Beta. Lambda = 1/Beta
                FastDist::Expon(Exp::new(1.0 / beta).unwrap(), v.multiplier)
            },
            DistType::Uniform { min, max } => {
                if min >= max { return Err(Error::Other(format!("Min >= Max en {}", v.name))); }
                FastDist::Unif(Uniform::new_inclusive(min, max), v.multiplier)
            }
        };
        distributions.push(dist);
    }

    // 2. Ejecución (Hot Loop)
    let mut rng = thread_rng();
    let mut sum_x = 0.0;
    let mut sum_x2 = 0.0;
    let mut min_val = f64::MAX;
    let mut max_val = f64::MIN;
    let mut success_counter = 0;
    
    // Solo guardamos una muestra pequeña para previsualizar (evita alloc masivo)
    let preview_size = 50.min(config.n_simulations);
    let mut preview = Vec::with_capacity(preview_size);

    for i in 0..config.n_simulations {
        // Sumamos las variables aleatorias de esta iteración
        let mut total_val = 0.0;
        for d in &distributions {
            total_val += d.sample(&mut rng);
        }

        // Estadísticas acumulativas
        sum_x += total_val;
        sum_x2 += total_val * total_val;
        if total_val < min_val { min_val = total_val; }
        if total_val > max_val { max_val = total_val; }

        if i < preview_size { preview.push(total_val); }

        // Lógica condicional (si aplica)
        if let AnalysisMode::Probability { threshold, ref operator, .. } = config.analysis {
            let passed = match operator.as_str() {
                "<" => total_val < threshold,
                "<=" => total_val <= threshold,
                ">" => total_val > threshold,
                ">=" => total_val >= threshold,
                _ => false, 
            };
            if passed { success_counter += 1; }
        }
    }

    // 3. Post-procesamiento
    let n = config.n_simulations as f64;
    let mean = sum_x / n;
    let variance = (sum_x2 / n) - (mean * mean); // E[X^2] - (E[X])^2
    let std_dev = variance.max(0.0).sqrt(); // max(0) por si error flotante da -0.000...

    let mut prob_res = None;
    let mut cost_res = None;
    let mut count_res = None;

    if let AnalysisMode::Probability { cost_per_event, population_size, .. } = config.analysis {
        let p = success_counter as f64 / n;
        prob_res = Some(p);
        count_res = Some(success_counter);
        // Costo esperado TOTAL = Probabilidad * CostoUnitario * Poblacion
        cost_res = Some(p * cost_per_event * population_size);
    }

    Ok(MonteCarloResponse {
        iterations: config.n_simulations,
        mean,
        std_dev,
        min: min_val,
        max: max_val,
        samples_preview: preview,
        success_count: count_res,
        probability: prob_res,
        expected_cost: cost_res,
    })
}