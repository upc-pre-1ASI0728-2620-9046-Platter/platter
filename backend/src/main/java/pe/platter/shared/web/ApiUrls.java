package pe.platter.shared.web;

import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/**
 * Construye URLs absolutas a partir de la petición en curso (respetando X-Forwarded-* detrás del gateway),
 * de modo que la app móvil y el cliente WebAR reciban enlaces utilizables directamente.
 */
public final class ApiUrls {

    private ApiUrls() {
    }

    public static String of(String path) {
        return ServletUriComponentsBuilder.fromCurrentContextPath().path(path).toUriString();
    }
}
