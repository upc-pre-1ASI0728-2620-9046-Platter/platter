package pe.platter.analysis.domain;

/** Puerto de inferencia multimodal. Lanza {@link InferenceUnavailableException} si el proveedor no responde. */
public interface GastronomicInferenceService {

    GastronomicInference analyze(byte[] image, String mimeType);
}
