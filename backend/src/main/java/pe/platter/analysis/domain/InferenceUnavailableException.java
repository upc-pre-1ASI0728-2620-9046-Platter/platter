package pe.platter.analysis.domain;

public class InferenceUnavailableException extends RuntimeException {

    public InferenceUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }

    public InferenceUnavailableException(String message) {
        super(message);
    }
}
