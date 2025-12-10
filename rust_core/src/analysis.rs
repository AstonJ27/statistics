// src/analysis.rs
use serde_json::json;
use crate::json_helpers::to_cstring;
use crate::errors::Error;
use std::slice;
use std::f64::consts::PI;

// Imports de módulos refactorizados
use crate::stats::summary;
use crate::aggregation::{histogram, boxplot, stem_leaf};
// Para freq_table seguiremos usando lógica inline o llamarías a su fn si la refactorizas

pub fn analyze_distribution_json(ptr: *const f64, len: usize, h_round: bool) -> Result<*mut libc::c_char, Error> {
    if !crate::ffi::check_ptr_len(ptr, len) { return Err(Error::NullOrEmptyInput); }
    
    unsafe {
        // 1. Preparar datos (ORDENAR UNA SOLA VEZ)
        let mut data = slice::from_raw_parts(ptr, len).to_vec();
        data.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        
        let n = data.len();
        if n == 0 { return Err(Error::NullOrEmptyInput); }
        let n_f64 = n as f64;

        // 2. Calcular K (Sturges)
        let mut k = crate::utils::sturges_bins(n);
        if h_round && k % 2 == 0 { k += 1; }

        // 3. Obtener Summary Stats (Usando módulo optimizado)
        let summary_stats = summary::calculate_summary_sorted(&data, k);
        let minv = summary_stats.min;
        let maxv = summary_stats.max;
        let w = summary_stats.amplitude;

        // 4. Boxplot (Usando módulo optimizado)
        let box_stats = boxplot::calculate_boxplot_sorted(&data);

        // 5. Histograma (Usando módulo optimizado)
        let hist_data = histogram::calculate_histogram_logic(&data, k, minv, maxv);

        // 6. Stem & Leaf (Usando wrapper existente, asumiendo scale fijo o dinámico)
        // Nota: stem_leaf_json original toma puntero, aquí usamos lógica interna si existiera,
        // si no, replicamos la lógica brevemente para no crear punteros internos.
        let stem_data = {
            // Replicación breve de lógica para evitar FFI overhead interno
            use std::collections::BTreeMap;
            let scale = 100.0;
            let mut map: BTreeMap<i64, Vec<i64>> = BTreeMap::new();
            for &x in &data {
                let scaled = (x * scale).round() as i64;
                let stem = scaled / (scale as i64);
                let leaf = (scaled % (scale as i64)).abs();
                map.entry(stem).or_default().push(leaf);
            }
            let mut out = Vec::new();
            for (stem, mut leaves) in map {
                leaves.sort_unstable();
                out.push(json!({"stem": stem, "leaves": leaves}));
            }
            out
        };

        // 7. Freq Table (Construimos basándonos en el histograma ya calculado)
        // Esto evita recalcular bins. Reutilizamos `hist_data`.
        let mut classes = Vec::with_capacity(k);
        let mut cum_abs = 0u32;
        let mut cum_rel = 0.0f64;
        
        for i in 0..k {
            let abs_f = hist_data.counts[i];
            cum_abs += abs_f;
            let rel = (abs_f as f64) / n_f64;
            cum_rel += rel;
            
            // Usamos edges del histograma para consistencia perfecta
            classes.push(json!({
                "lower": hist_data.edges[i],
                "upper": hist_data.edges[i+1],
                "midpoint": hist_data.centers[i],
                "abs_freq": abs_f,
                "rel_freq": rel,
                "cum_abs": cum_abs,
                "cum_rel": cum_rel
            }));
        }
        let freq_table_json = json!({ "classes": classes, "amplitude": w });


        // 8. BEST FIT (Optimizado y Corregido)
        let mean = summary_stats.mean;
        let std = summary_stats.std_pop; // MLE usa población

        // LL Normal
        let ll_norm = ll_normal(&data, mean, std);
        let aic_norm = 4.0 - 2.0 * ll_norm;

        // LL Uniform
        let ll_unif = ll_uniform(&data, minv, maxv);
        let aic_unif = 4.0 - 2.0 * ll_unif;

        // FIX: Validar negativos para Exp y LogNormal
        let has_negatives = minv < 0.0;
        
        // Exponential
        let (aic_exp, ll_exp, exp_params) = if has_negatives || mean <= 0.0 {
            (f64::INFINITY, f64::NEG_INFINITY, vec![])
        } else {
            let beta = mean;
            let ll = ll_exponential(&data, beta);
            (2.0 - 2.0 * ll, ll, vec![beta])
        };

        // LogNormal
        let (aic_logn, ll_logn, logn_params) = if has_negatives || minv <= 0.0 {
             (f64::INFINITY, f64::NEG_INFINITY, vec![])
        } else {
             let ln_data: Vec<f64> = data.iter().map(|x| x.ln()).collect();
             let ln_mean: f64 = ln_data.iter().sum::<f64>() / n_f64;
             let ln_var: f64 = ln_data.iter().map(|x| (x - ln_mean).powi(2)).sum::<f64>() / n_f64;
             let ln_sigma = ln_var.sqrt();
             let ll = ll_lognormal(&data, ln_mean, ln_sigma);
             (4.0 - 2.0 * ll, ll, vec![ln_mean, ln_sigma])
        };

        // Selección del mejor
        let mut fits = vec![
            ("normal", aic_norm, ll_norm, json!({"params":[mean, std]})),
            ("exponential", aic_exp, ll_exp, json!({"params": exp_params})),
            ("lognormal", aic_logn, ll_logn, json!({"params": logn_params})),
            ("uniform", aic_unif, ll_unif, json!({"params":[minv, maxv]})),
        ];
        // Ordenar por AIC menor
        fits.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap_or(std::cmp::Ordering::Equal));
        
        let best = &fits[0];
        let best_name = best.0;
        let best_aic = best.1;
        let best_ll = best.2;
        let best_params = best.3.clone();

        // 9. Generar Curvas (Expected Counts y Plot)
        // ... (Lógica de curvas simplificada usando helpers abajo) ...
        // Calculamos expected counts usando CDFs en los bordes del histograma
        let mut expected_counts = vec![0.0; k];
        let mut cdf_vals = Vec::with_capacity(k+1);
        
        // Helper closures para CDF dinámico
        let cdf_func = |x: f64| -> f64 {
            match best_name {
                "normal" => normal_cdf(x, mean, std),
                "exponential" => if !exp_params.is_empty() { exponential_cdf(x, exp_params[0]) } else { 0.0 },
                "lognormal" => if !logn_params.is_empty() { lognormal_cdf(x, logn_params[0], logn_params[1]) } else { 0.0 },
                "uniform" => uniform_cdf(x, minv, maxv),
                _ => 0.0,
            }
        };
        
        // PDF function para plotting
        let pdf_func = |x: f64| -> f64 {
            match best_name {
                "normal" => normal_pdf(x, mean, std),
                "exponential" => if !exp_params.is_empty() { exponential_pdf(x, exp_params[0]) } else { 0.0 },
                "lognormal" => if !logn_params.is_empty() { lognormal_pdf(x, logn_params[0], logn_params[1]) } else { 0.0 },
                "uniform" => uniform_pdf(x, minv, maxv),
                _ => 0.0,
            }
        };

        for &edge in &hist_data.edges {
            cdf_vals.push(cdf_func(edge));
        }
        for i in 0..k {
            let p = (cdf_vals[i+1] - cdf_vals[i]).max(0.0);
            expected_counts[i] = p * n_f64;
        }

        // Puntos para gráfica (Curva suave)
        let mpoints = 100usize;
        let mut x_plot = Vec::with_capacity(mpoints);
        let mut best_freq = Vec::with_capacity(mpoints);
        for i in 0..mpoints {
            let t = (i as f64) / ((mpoints - 1) as f64);
            let x = minv + t * (maxv - minv);
            x_plot.push(x);
            let pdf = pdf_func(x);
            best_freq.push(pdf * n_f64 * w);
        }

        // 10. Salida Final
        let out = json!({
            "summary": summary_stats,
            "histogram": hist_data,
            "freq_table": freq_table_json,
            "boxplot": box_stats,
            "stem_leaf": stem_data,
            "best_fit": {
                "name": best_name,
                "aic": best_aic,
                "ll": best_ll,
                "params": best_params,
                "expected_counts": expected_counts
            },
            "curves": {
                "x": x_plot,
                "best_freq": best_freq
            }
        });

        Ok(to_cstring(&out))
    }
}

// --- HELPERS MATEMÁTICOS (Privados) ---
fn ll_normal(data: &[f64], mu: f64, sigma: f64) -> f64 {
    if sigma <= 0.0 { return f64::NEG_INFINITY; }
    let n = data.len() as f64;
    let term1 = -0.5 * n * (2.0 * PI).ln();
    let term2 = -n * sigma.ln();
    let sum_sq: f64 = data.iter().map(|x| (x - mu).powi(2)).sum();
    term1 + term2 - sum_sq / (2.0 * sigma * sigma)
}
fn ll_exponential(data: &[f64], beta: f64) -> f64 {
    if beta <= 0.0 { return f64::NEG_INFINITY; }
    let n = data.len() as f64;
    let sum: f64 = data.iter().sum();
    -n * beta.ln() - sum / beta
}
fn ll_lognormal(data: &[f64], mu: f64, sigma: f64) -> f64 {
    if sigma <= 0.0 { return f64::NEG_INFINITY; }
    let n = data.len() as f64;
    let term1 = -0.5 * n * (2.0 * PI).ln();
    let term2 = -n * sigma.ln();
    let mut sum_log_x = 0.0;
    let mut sum_sq = 0.0;
    for &x in data {
        if x <= 0.0 { return f64::NEG_INFINITY; }
        let lx = x.ln();
        sum_log_x += lx;
        sum_sq += (lx - mu).powi(2);
    }
    term1 + term2 - sum_log_x - sum_sq / (2.0 * sigma * sigma)
}
fn ll_uniform(data: &[f64], a: f64, b: f64) -> f64 {
    if a >= b { return f64::NEG_INFINITY; }
    let n = data.len() as f64;
    for &x in data { if x < a || x > b { return f64::NEG_INFINITY; } }
    -n * (b - a).ln()
}

// PDF Implementations
fn normal_pdf(x: f64, mu: f64, sigma: f64) -> f64 {
    if sigma <= 0.0 { return 0.0; }
    let z = (x - mu) / sigma;
    (1.0 / (sigma * (2.0 * PI).sqrt())) * (-0.5 * z * z).exp()
}
fn exponential_pdf(x: f64, beta: f64) -> f64 {
    if x < 0.0 || beta <= 0.0 { 0.0 } else { (1.0 / beta) * (-x / beta).exp() }
}
fn lognormal_pdf(x: f64, mu: f64, sigma: f64) -> f64 {
    if x <= 0.0 || sigma <= 0.0 { 0.0 } else {
        (1.0 / (x * sigma * (2.0 * PI).sqrt())) * (-0.5 * ((x.ln() - mu) / sigma).powi(2)).exp()
    }
}
fn uniform_pdf(x: f64, a: f64, b: f64) -> f64 {
    if x >= a && x <= b && b > a { 1.0 / (b - a) } else { 0.0 }
}

// CDF Implementations (Approx)
fn normal_cdf(x: f64, mu: f64, sigma: f64) -> f64 {
    if sigma <= 0.0 { return if x >= mu { 1.0 } else { 0.0 }; }
    let z = (x - mu) / (sigma * 2.0_f64.sqrt());
    0.5 * (1.0 + erf_approx(z))
}
fn erf_approx(x: f64) -> f64 {
    let a1 =  0.254829592;
    let a2 = -0.284496736;
    let a3 =  1.421413741;
    let a4 = -1.453152027;
    let a5 =  1.061405429;
    let p  =  0.3275911;
    let sign = if x < 0.0 { -1.0 } else { 1.0 };
    let x_abs = x.abs();
    let t = 1.0 / (1.0 + p * x_abs);
    let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * (-x_abs * x_abs).exp();
    sign * y
}
fn exponential_cdf(x: f64, beta: f64) -> f64 {
    if x < 0.0 { 0.0 } else { 1.0 - (-x / beta).exp() }
}
fn lognormal_cdf(x: f64, mu: f64, sigma: f64) -> f64 {
    if x <= 0.0 { 0.0 } else { normal_cdf(x.ln(), mu, sigma) }
}
fn uniform_cdf(x: f64, a: f64, b: f64) -> f64 {
    if x < a { 0.0 } else if x >= b { 1.0 } else { (x - a) / (b - a) }
}