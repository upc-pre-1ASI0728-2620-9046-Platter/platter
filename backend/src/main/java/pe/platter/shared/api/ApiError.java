package pe.platter.shared.api;

import java.util.Map;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_EMPTY)
public record ApiError(String code, String message, Map<String, ?> details) {

    public ApiError(String code, String message) {
        this(code, message, Map.of());
    }
}
