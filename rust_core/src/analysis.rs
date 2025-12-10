// rust_core/src/analysis.rs
use serde_json::json;
use crate::json_helpers::to_cstring;
use crate::errors::Error;
use std::slice;
use std::f64::consts::PI;

// Imports de módulos
use crate::stats::summary::{self, SummaryStats};
use crate::aggregation::{histogram, boxplot, stem_leaf};

// Estructuras auxiliares para organizar el código interno
struct FitResult {
    name: &'static str,
    aic: f64,
    ll: f64,
    params: Vec<f64>,
}

struct CurvesResult {
    x_plot: Vec<f64>,
    best_freq: Vec<f64>,
    expected_counts: Vec<f64>,
}

// --- FUNCIÓN PRINCIPAL (ORQUESTADOR) ---
pub fn analyze_distribution_json(
    ptr: *const f64, 
    len: usize, 
    h_round: bool, 
    forced_k: usize, 
    forced_min: f64, 
    forced_max: f64
) -> Result<*mut libc::c_char, Error> {
    
    unsafe {
        // 1. Obtener y ordenar datos (Función extraída)
        let data = get_sorted_data(ptr, len)?;
        let n = data.len();
        let n_f64 = n as f64;

        // 2. Determinar K
        let k = if forced_k > 0 {
            forced_k
        } else {
            let s_k = crate::utils::sturges_bins(n);
            if h_round && s_k % 2 == 0 { s_k + 1 } else { s_k }
        };

        // 3. Estadísticas Descriptivas
        let mut summary_stats = summary::calculate_summary_sorted(&data, k);
        
        // Aplicar límites manuales si existen (para corregir tablas manuales)
        if !forced_min.is_nan() { summary_stats.min = forced_min; }
        if !forced_max.is_nan() { summary_stats.max = forced_max; }
        
        // Recalcular rango y amplitud con los límites definitivos
        summary_stats.range = summary_stats.max - summary_stats.min;
        if k > 0 { summary_stats.amplitude = summary_stats.range / (k as f64); }
        summary_stats.k = k;

        // Variables limpias para uso posterior
        let minv = summary_stats.min;
        let maxv = summary_stats.max;
        let w = summary_stats.amplitude;

        // 4. Módulos de Agregación (Boxplot, Hist, Stem)
        let box_stats = boxplot::calculate_boxplot_sorted(&data);
        let hist_data = histogram::calculate_histogram_logic(&data, k, minv, maxv);
        let stem_data = stem_leaf::calculate_stem_leaf_logic(&data, 100.0);

        // 5. Tabla de Frecuencias (Construida desde el Histograma para consistencia)
        let mut classes = Vec::with_capacity(k);
        let mut cum_abs = 0u32;
        let mut cum_rel = 0.0f64;
        
        for i in 0..k {
            let abs_f = if i < hist_data.counts.len() { hist_data.counts[i] } else { 0 };
            cum_abs += abs_f;
            let rel = (abs_f as f64) / n_f64;
            cum_rel += rel;
            
            // Usamos lógica de intervalos consistente con minv/maxv
            let lower = minv + (i as f64) * w;
            let upper = lower + w;
            let midpoint = lower + (w / 2.0);

            classes.push(json!({
                "lower": lower, "upper": upper, "midpoint": midpoint,
                "abs_freq": abs_f, "rel_freq": rel,
                "cum_abs": cum_abs, "cum_rel": cum_rel
            }));
        }
        let freq_table_json = json!({ "classes": classes, "amplitude": w });

        // 6. Best Fit (Función extraída)
        let fit = calculate_best_fit(&data, &summary_stats);

        // 7. Curvas y Esperados (Función extraída)
        // Nota: Pasamos los bordes calculados o generamos unos ideales basados en minv/maxv
        let edges = if !hist_data.edges.is_empty() { hist_data.edges.clone() } else { 
            (0..=k).map(|i| minv + i as f64 * w).collect() 
        };
        let curves = calculate_curves(&fit, &edges, minv, maxv, n_f64, w);

        // 8. Construir JSON Final
        let out = json!({
            "summary": summary_stats,
            "histogram": hist_data,
            "freq_table": freq_table_json,
            "boxplot": box_stats,
            "stem_leaf": stem_data,
            "best_fit": {
                "name": fit.name,
                "aic": fit.aic,
                "ll": fit.ll,
                "params": fit.params,
                "expected_counts": curves.expected_counts
            },
            "curves": {
                "x": curves.x_plot,
                "best_freq": curves.best_freq
            }
        });

        Ok(to_cstring(&out))
    }
}

// --- FUNCIONES DE SOPORTE (EXTRAÍDAS) ---

unsafe fn get_sorted_data(ptr: *const f64, len: usize) -> Result<Vec<f64>, Error> {
    if !crate::ffi::check_ptr_len(ptr, len) { return Err(Error::NullOrEmptyInput); }
    let mut data = slice::from_raw_parts(ptr, len).to_vec();
    data.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    Ok(data)
}

fn calculate_best_fit(data: &[f64], stats: &SummaryStats) -> FitResult {
    let mean = stats.mean;
    let std = stats.std_pop;
    let minv = stats.min;
    let maxv = stats.max;
    let n_f64 = data.len() as f64;

    // 1. Normal
    let ll_norm = ll_normal(data, mean, std);
    let aic_norm = 4.0 - 2.0 * ll_norm;

    // 2. Uniforme
    let ll_unif = ll_uniform(data, minv, maxv);
    let aic_unif = 4.0 - 2.0 * ll_unif;

    // Validar negativos para Exp y LogNormal
    let has_negatives = minv < 0.0;

    // 3. Exponencial
    let (aic_exp, ll_exp, exp_params) = if has_negatives || mean <= 0.0 {
        (f64::INFINITY, f64::NEG_INFINITY, vec![])
    } else {
        let beta = mean;
        let ll = ll_exponential(data, beta);
        (2.0 - 2.0 * ll, ll, vec![beta])
    };

    // 4. LogNormal
    let (aic_logn, ll_logn, logn_params) = if has_negatives || minv <= 0.0 {
         (f64::INFINITY, f64::NEG_INFINITY, vec![])
    } else {
         let ln_data: Vec<f64> = data.iter().map(|x| x.ln()).collect();
         let ln_mean: f64 = ln_data.iter().sum::<f64>() / n_f64;
         let ln_var: f64 = ln_data.iter().map(|x| (x - ln_mean).powi(2)).sum::<f64>() / n_f64;
         let ln_sigma = ln_var.sqrt();
         let ll = ll_lognormal(data, ln_mean, ln_sigma);
         (4.0 - 2.0 * ll, ll, vec![ln_mean, ln_sigma])
    };

    // Selección
    let mut fits = vec![
        FitResult { name: "normal", aic: aic_norm, ll: ll_norm, params: vec![mean, std] },
        FitResult { name: "exponential", aic: aic_exp, ll: ll_exp, params: exp_params },
        FitResult { name: "lognormal", aic: aic_logn, ll: ll_logn, params: logn_params },
        FitResult { name: "uniform", aic: aic_unif, ll: ll_unif, params: vec![minv, maxv] },
    ];

    fits.sort_by(|a, b| a.aic.partial_cmp(&b.aic).unwrap_or(std::cmp::Ordering::Equal));
    
    // Retornar el mejor (remove(0) saca el primero)
    fits.remove(0)
}

fn calculate_curves(fit: &FitResult, edges: &[f64], minv: f64, maxv: f64, n_f64: f64, w: f64) -> CurvesResult {
    let params = &fit.params;
    let name = fit.name;

    // Helper closures
    let cdf = |x: f64| -> f64 {
        match name {
            "normal" => normal_cdf(x, params[0], params[1]),
            "exponential" => if !params.is_empty() { exponential_cdf(x, params[0]) } else { 0.0 },
            "lognormal" => if !params.is_empty() { lognormal_cdf(x, params[0], params[1]) } else { 0.0 },
            "uniform" => uniform_cdf(x, params[0], params[1]),
            _ => 0.0,
        }
    };
    
    let pdf = |x: f64| -> f64 {
        match name {
            "normal" => normal_pdf(x, params[0], params[1]),
            "exponential" => if !params.is_empty() { exponential_pdf(x, params[0]) } else { 0.0 },
            "lognormal" => if !params.is_empty() { lognormal_pdf(x, params[0], params[1]) } else { 0.0 },
            "uniform" => uniform_pdf(x, params[0], params[1]),
            _ => 0.0,
        }
    };

    // 1. Expected Counts (usando CDF en los bordes)
    let mut expected_counts = Vec::with_capacity(edges.len().saturating_sub(1));
    let mut cdf_vals = Vec::with_capacity(edges.len());
    
    for &edge in edges {
        cdf_vals.push(cdf(edge));
    }
    
    for i in 0..edges.len().saturating_sub(1) {
        let p = (cdf_vals[i+1] - cdf_vals[i]).max(0.0);
        expected_counts.push(p * n_f64);
    }

    // 2. Plotting Points (usando PDF)
    let mpoints = 100usize;
    let mut x_plot = Vec::with_capacity(mpoints);
    let mut best_freq = Vec::with_capacity(mpoints);
    
    for i in 0..mpoints {
        let t = (i as f64) / ((mpoints - 1) as f64);
        let x = minv + t * (maxv - minv);
        x_plot.push(x);
        let y = pdf(x) * n_f64 * w;
        best_freq.push(y);
    }

    CurvesResult { x_plot, best_freq, expected_counts }
}

// --- MATH HELPERS (Sin cambios, mantener igual) ---
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

// PDF Functions
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

// CDF Functions
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