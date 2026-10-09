package pe.platter.analysis.infrastructure;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.concurrent.atomic.AtomicInteger;

import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.context.properties.source.MapConfigurationPropertySource;
import org.springframework.web.client.RestClient;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;

import java.util.Map;

import pe.platter.analysis.domain.GastronomicInference;
import pe.platter.analysis.domain.InferenceUnavailableException;
import pe.platter.shared.config.PlatterProperties;
import tools.jackson.databind.json.JsonMapper;

class GeminiResilienceTest {

    private final JsonMapper json = JsonMapper.builder().build();

    private PlatterProperties properties(String apiKey) {
        return new Binder(new MapConfigurationPropertySource(Map.of("platter.ai.api-key", apiKey)))
                .bindOrCreate("platter", PlatterProperties.class);
    }

    @Test
    void translatesGeminiContractIntoDomainLanguage() {
        GeminiApiClientAdapter adapter = new GeminiApiClientAdapter(RestClient.builder(), json, properties("k"));
        String inner = """
                {"food":true,"confidence":0.92,"suggestedName":"Lomo saltado","description":"Jugoso...",
                 "category":"Fondos","ingredients":["Lomo"," Cebolla ",""],"allergens":["SOY","PLUTONIO"],
                 "caloriesMin":700,"caloriesMax":850}""";
        var response = json.createObjectNode();
        response.putArray("candidates").addObject().putObject("content").putArray("parts").addObject()
                .put("text", inner);

        GastronomicInference result = adapter.translate(response);

        assertThat(result.suggestedName()).isEqualTo("Lomo saltado");
        assertThat(result.category()).isEqualTo("Fondos");
        assertThat(result.ingredients()).containsExactly("Lomo", "Cebolla");
        assertThat(result.allergenCodes()).containsExactly("SOY");
        assertThat(result.caloriesMin()).isEqualTo(700);
        assertThat(result.confidence()).isEqualTo(0.92);
    }

    @Test
    void opensCircuitAfterRepeatedFailuresAndFailsFast() {
        AtomicInteger calls = new AtomicInteger();
        GeminiApiClientAdapter failing = new GeminiApiClientAdapter(RestClient.builder(), json, properties("k")) {
            @Override
            GastronomicInference generate(byte[] image, String mimeType) {
                calls.incrementAndGet();
                throw new IllegalStateException("timeout simulado");
            }
        };
        ResilientGeminiInferenceService service = new ResilientGeminiInferenceService(failing);

        for (int i = 0; i < 5; i++) {
            assertThatThrownBy(() -> service.analyze(new byte[] {1}, "image/jpeg"))
                    .isInstanceOf(InferenceUnavailableException.class);
        }
        assertThat(service.state()).isEqualTo(CircuitBreaker.State.OPEN);

        long start = System.nanoTime();
        assertThatThrownBy(() -> service.analyze(new byte[] {1}, "image/jpeg"))
                .isInstanceOf(InferenceUnavailableException.class)
                .hasMessageContaining("Circuito abierto");
        assertThat((System.nanoTime() - start) / 1_000_000).isLessThan(100);
        assertThat(calls).hasValue(5);
    }

    @Test
    void withoutApiKeyTheProviderIsUnavailable() {
        ResilientGeminiInferenceService service = new ResilientGeminiInferenceService(
                new GeminiApiClientAdapter(RestClient.builder(), json, properties("")));
        assertThatThrownBy(() -> service.analyze(new byte[] {1}, "image/png"))
                .isInstanceOf(InferenceUnavailableException.class);
    }
}
