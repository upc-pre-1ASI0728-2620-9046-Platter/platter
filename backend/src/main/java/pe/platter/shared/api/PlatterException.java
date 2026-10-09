package pe.platter.shared.api;

import java.util.Map;

import org.springframework.http.HttpStatus;

/** Error de negocio que se traduce 1:1 al formato {@link ApiError}. */
public class PlatterException extends RuntimeException {

    private final HttpStatus status;
    private final String code;
    private final Map<String, ?> details;

    public PlatterException(HttpStatus status, String code, String message, Map<String, ?> details) {
        super(message);
        this.status = status;
        this.code = code;
        this.details = details;
    }

    public PlatterException(HttpStatus status, String code, String message) {
        this(status, code, message, Map.of());
    }

    public static PlatterException notFound(String what) {
        return new PlatterException(HttpStatus.NOT_FOUND, "NOT_FOUND", what + " no encontrado");
    }

    public HttpStatus status() {
        return status;
    }

    public String code() {
        return code;
    }

    public Map<String, ?> details() {
        return details;
    }
}
