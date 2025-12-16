use serde::{Deserialize, Serialize};

#[derive(Deserialize, Clone)]
pub enum DistType {
    Normal { mean: f64, variance: f64 }, // Confirmando el uso de 'variance'
    Exponential { beta: f64 }, 
    Uniform { min: f64, max: f64 },
}

#[derive(Deserialize, Clone)]
pub struct VariableConfig {
    pub name: String,
    pub distribution: DistType,
    pub multiplier: f64, 
}

#[derive(Deserialize)]
#[serde(tag = "mode_type", content = "params")]
pub enum AnalysisMode {
    Aggregation, 
    Probability { 
        threshold: f64,
        operator: String, 
        cost_per_event: f64,
        population_size: f64,
    }
}

#[derive(Deserialize)]
pub struct MonteCarloConfig {
    pub n_simulations: usize,
    pub variables: Vec<VariableConfig>,
    pub analysis: AnalysisMode,
}

// --- NUEVA ESTRUCTURA PARA EL DETALLE (Corrección del error) ---
#[derive(Serialize, Clone)]
pub struct IterationDetail {
    pub variables: Vec<f64>, // Lista de valores [x1, x2, x3]
    pub total: f64,          // Suma total
}

#[derive(Serialize)]
pub struct MonteCarloResponse {
    pub iterations: usize,
    pub mean: f64,
    pub std_dev: f64,
    pub min: f64,
    pub max: f64,
    // CAMBIO AQUÍ: Vector de IterationDetail en lugar de f64
    pub samples_preview: Vec<IterationDetail>, 
    pub success_count: Option<usize>,
    pub probability: Option<f64>,
    pub expected_cost: Option<f64>,
}