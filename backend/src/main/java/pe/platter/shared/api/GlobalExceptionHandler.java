package pe.platter.shared.api;

import java.util.LinkedHashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(PlatterException.class)
    ResponseEntity<ApiError> platter(PlatterException ex) {
        return ResponseEntity.status(ex.status()).body(new ApiError(ex.code(), ex.getMessage(), ex.details()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiError> invalid(MethodArgumentNotValidException ex) {
        Map<String, String> details = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors()
                .forEach(e -> details.putIfAbsent(e.getField(), e.getDefaultMessage()));
        return validation("Revisa los campos marcados", details);
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class,
            MissingServletRequestParameterException.class, MissingServletRequestPartException.class})
    ResponseEntity<ApiError> unreadable(Exception ex) {
        return validation("Solicitud inválida", Map.of());
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    ResponseEntity<ApiError> tooLarge() {
        return ResponseEntity.status(HttpStatus.CONTENT_TOO_LARGE)
                .body(new ApiError("IMAGE_TOO_LARGE", "La imagen supera el máximo de 10 MB"));
    }

    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    ResponseEntity<ApiError> mediaType() {
        return ResponseEntity.status(HttpStatus.UNSUPPORTED_MEDIA_TYPE)
                .body(new ApiError("UNSUPPORTED_MEDIA_TYPE", "Tipo de contenido no soportado"));
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    ResponseEntity<ApiError> method() {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED)
                .body(new ApiError("METHOD_NOT_ALLOWED", "Método no permitido"));
    }

    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<ApiError> noResource() {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ApiError("NOT_FOUND", "Recurso no encontrado"));
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiError> unexpected(Exception ex) {
        log.error("Error no controlado", ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ApiError("INTERNAL_ERROR", "Ocurrió un error inesperado"));
    }

    private static ResponseEntity<ApiError> validation(String message, Map<String, String> details) {
        return ResponseEntity.badRequest().body(new ApiError("VALIDATION_ERROR", message, details));
    }
}
