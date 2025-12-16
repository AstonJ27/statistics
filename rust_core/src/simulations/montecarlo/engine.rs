use rand::prelude::*;
use rand_distr::{Exp, Normal, Uniform, Distribution};
use crate::errors::Error;
use super::models::*;

enum FastDist {
    Norm(Normal<f64>, f64), 
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

    // 1. Preparación
    let mut distributions = Vec::with_capacity(config.variables.len());
    
    for v in &config.variables {
        let dist = match v.distribution {
            DistType::Normal { mean, variance } => {
                if variance < 0.0 { return Err(Error::Other(format!("Varianza negativa en {}", v.name))); }
                let std = variance.sqrt(); // Calculamos std desde varianza
                FastDist::Norm(Normal::new(mean, std).unwrap(), v.multiplier)
            },
            DistType::Exponential { beta } => {
                if beta <= 0.0 { return Err(Error::Other(format!("Beta <= 0 en {}", v.name))); }
                FastDist::Expon(Exp::new(1.0 / beta).unwrap(), v.multiplier)
            },
            DistType::Uniform { min, max } => {
                if min >= max { return Err(Error::Other(format!("Min >= Max en {}", v.name))); }
                FastDist::Unif(Uniform::new_inclusive(min, max), v.multiplier)
            }
        };
        distributions.push(dist);
    }

    // 2. Ejecución
    let mut rng = thread_rng();
    let mut sum_x = 0.0;
    let mut sum_x2 = 0.0;
    let mut min_val = f64::MAX;
    let mut max_val = f64::MIN;
    let mut success_counter = 0;
    
    let preview_size = 50.min(config.n_simulations);
    // Corrección: Vector de objetos IterationDetail
    let mut preview: Vec<IterationDetail> = Vec::with_capacity(preview_size);

    for i in 0..config.n_simulations {
        let mut total_val = 0.0;
        // Guardamos los valores individuales de esta iteración
        let mut current_vars = Vec::with_capacity(distributions.len());

        for d in &distributions {
            let val = d.sample(&mut rng);
            current_vars.push(val); 
            total_val += val;
        }

        sum_x += total_val;
        sum_x2 += total_val * total_val;
        if total_val < min_val { min_val = total_val; }
        if total_val > max_val { max_val = total_val; }

        // Guardamos el objeto completo si es parte del preview
        if i < preview_size { 
            preview.push(IterationDetail {
                variables: current_vars,
                total: total_val
            }); 
        }

        // Lógica de Probabilidad
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

    // 3. Resultados
    let n = config.n_simulations as f64;
    let mean = sum_x / n;
    let variance_res = (sum_x2 / n) - (mean * mean);
    let std_dev = variance_res.max(0.0).sqrt();

    let mut prob_res = None;
    let mut cost_res = None;
    let mut count_res = None;

    if let AnalysisMode::Probability { cost_per_event, population_size, .. } = config.analysis {
        let p = success_counter as f64 / n;
        prob_res = Some(p);
        count_res = Some(success_counter);
        cost_res = Some(p * cost_per_event * population_size);
    }

    Ok(MonteCarloResponse {
        iterations: config.n_simulations,
        mean,
        std_dev,
        min: min_val,
        max: max_val,
        samples_preview: preview, // Ahora enviamos la estructura correcta
        success_count: count_res,
        probability: prob_res,
        expected_cost: cost_res,
    })
}