// src/probabilities/cdf_pdf.rs
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct InverseCdfRequest {
    pub dist_type: String, // "normal", "exponential", "uniform"
    pub probability: f64,  // Valor entre 0 y 1 (U)
    pub param1: f64,       // Mean, Beta, Min
    pub param2: f64,       // Variance, -, Max
}

#[derive(Serialize)]
pub struct InverseCdfResponse {
    pub value: f64,        // El valor simulado final (X)
    pub z_score: Option<f64>, // Solo para normal
}

pub fn calculate_inverse(req: InverseCdfRequest) -> Result<InverseCdfResponse, String> {
    if req.probability <= 0.0 || req.probability >= 1.0 {
        return Err("La probabilidad debe estar estrictamente entre 0 y 1".to_string());
    }

    match req.dist_type.as_str() {
        "normal" => {
            // Param1 = Media, Param2 = Varianza (Ojo: Varianza, no Std)
            if req.param2 < 0.0 { return Err("Varianza negativa".to_string()); }
            let std_dev = req.param2.sqrt();
            
            // 1. Calcular Z (Probit)
            let z = inverse_normal_cdf_approx(req.probability);
            
            // 2. Des-estandarizar: X = mu + Z * sigma
            let x = req.param1 + (z * std_dev);
            
            Ok(InverseCdfResponse { value: x, z_score: Some(z) })
        },
        "exponential" => {
            // Param1 = Beta (Media). 
            if req.param1 <= 0.0 { return Err("Beta debe ser > 0".to_string()); }
            // F(x) = 1 - e^(-x/beta)  =>  x = -beta * ln(1 - p)
            let x = -req.param1 * (1.0 - req.probability).ln();
            Ok(InverseCdfResponse { value: x, z_score: None })
        },
        "uniform" => {
            // Param1 = Min, Param2 = Max
            if req.param1 >= req.param2 { return Err("Min >= Max".to_string()); }
            let x = req.param1 + (req.param2 - req.param1) * req.probability;
            Ok(InverseCdfResponse { value: x, z_score: None })
        },
        _ => Err(format!("Distribución '{}' no soportada", req.dist_type))
    }
}

/// Aproximación de Acklam para la inversa de la normal estándar.
fn inverse_normal_cdf_approx(p: f64) -> f64 {
    const A: [f64; 6] = [
        -3.969683028665376e1,  2.209460984245205e2,
        -2.759285104469687e2,  1.383577518672690e2,
        -3.066479806614716e1,  2.506628277459239e0
    ];
    const B: [f64; 5] = [
        -5.447609879822406e1,  1.615858368580409e2,
        -1.556989798598866e2,  6.680131188771972e1,
        -1.328068155288572e1
    ];
    const C: [f64; 9] = [
        -7.784894002430293e-3, -3.223964580411365e-1,
        -2.400758277161838e0,  -2.549732539343734e0,
        4.374664141464968e0,   2.938163982698783e0,
        7.784695709041462e-3,  3.224671290700398e-1,
        2.445134137142996e0
    ];
    const D: [f64; 8] = [
        7.784695709041462e-3,  3.224671290700398e-1,
        2.445134137142996e0,   3.754408661907416e0,
        -2.400758277161838e0,  -2.549732539343734e0,
        4.374664141464968e0,   2.938163982698783e0
    ];

    let low = 0.02425;
    let high = 1.0 - low;

    if p < low {
        let q = (-2.0 * p.ln()).sqrt();
        ((((((((C[0]*q + C[1])*q + C[2])*q + C[3])*q + C[4])*q + C[5])*q + C[6])*q + C[7])*q + C[8]) /
        (((((((D[0]*q + D[1])*q + D[2])*q + D[3])*q + D[4])*q + D[5])*q + D[6])*q + D[7])
    } else if p > high {
        let q = (-2.0 * (1.0 - p).ln()).sqrt();
        -((((((((C[0]*q + C[1])*q + C[2])*q + C[3])*q + C[4])*q + C[5])*q + C[6])*q + C[7])*q + C[8]) /
        (((((((D[0]*q + D[1])*q + D[2])*q + D[3])*q + D[4])*q + D[5])*q + D[6])*q + D[7])
    } else {
        let q = p - 0.5;
        let r = q * q;
        (((((A[0]*r + A[1])*r + A[2])*r + A[3])*r + A[4])*r + A[5])*q /
        (((((B[0]*r + B[1])*r + B[2])*r + B[3])*r + B[4])*r + 1.0)
    }
}