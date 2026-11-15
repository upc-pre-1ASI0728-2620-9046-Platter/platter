package pe.platter.shared.config;

import org.springdoc.core.utils.SpringDocUtils;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.ExternalDocumentation;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityScheme;
import pe.platter.shared.security.CurrentOwner;

/**
 * Documentación OpenAPI 3 del contrato REST v1 (Published Language).
 * Swagger UI: {@code /swagger-ui/index.html} · JSON: {@code /v3/api-docs}.
 */
@Configuration
class OpenApiConfig {

    static {
        // El dueño se resuelve desde el JWT (CurrentOwnerArgumentResolver): no es un parámetro de la API.
        SpringDocUtils.getConfig().addRequestWrapperToIgnore(CurrentOwner.class);
    }

    @Bean
    OpenAPI platterOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("Platter API")
                        .version("v1")
                        .description("""
                                Web Services de Platter: carta gastronómica en Realidad Aumentada para restaurantes MYPE.
                                Las rutas del dueño requieren un JWT: obtenlo con `POST /api/v1/auth/login` \
                                (cuenta demo `demo@platter.pe` / `demo12345`) y pégalo en **Authorize**.
                                Los errores responden `{ code, message, details }`.""")
                        .license(new License().name("Uso académico — UPC 1ASI0728")))
                .externalDocs(new ExternalDocumentation()
                        .description("Contrato de la API (docs/api-contract.md)")
                        .url("https://github.com/upc-pre-1ASI0728-2620-9046-Platter/platter/blob/main/docs/api-contract.md"))
                .components(new Components().addSecuritySchemes("bearerAuth", new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")
                        .description("JWT HS256 emitido por /api/v1/auth/login (expira en 1 hora)")));
    }
}
