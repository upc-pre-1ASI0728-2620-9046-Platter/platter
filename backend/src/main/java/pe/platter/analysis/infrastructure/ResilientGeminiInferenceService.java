package pe.platter.analysis.infrastructure;

import java.time.Duration;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerConfig;

import pe.platter.analysis.domain.GastronomicInference;
import pe.platter.analysis.domain.GastronomicInferenceService;
import pe.platter.analysis.domain.InferenceUnavailableException;

/**
 * QA-03: llamada síncrona protegida por Circuit Breaker (ventana de 10 llamadas, apertura al 50 % de fallos,
 * 30 s en estado Open) y timeout de lectura de 5000 ms en el cliente HTTP. Con el circuito abierto se responde
 * de inmediato, sin bloquear hilos, para que el dueño continúe con la carga manual.
 */
@Service
class ResilientGeminiInferenceService implements GastronomicInferenceService {

    private static final Logger log = LoggerFactory.getLogger(ResilientGeminiInferenceService.class);

    private final GeminiApiClientAdapter gemini;
    private final CircuitBreaker circuitBreaker;

    ResilientGeminiInferenceService(GeminiApiClientAdapter gemini) {
        this.gemini = gemini;
        this.circuitBreaker = CircuitBreaker.of("gemini", CircuitBreakerConfig.custom()
                .slidingWindowType(CircuitBreakerConfig.SlidingWindowType.COUNT_BASED)
                .slidingWindowSize(10)
                .minimumNumberOfCalls(5)
                .failureRateThreshold(50)
                .waitDurationInOpenState(Duration.ofSeconds(30))
                .permittedNumberOfCallsInHalfOpenState(2)
                .build());
    }

    @Override
    public GastronomicInference analyze(byte[] image, String mimeType) {
        if (!gemini.configured()) {
            throw new InferenceUnavailableException("No hay API key de Gemini configurada");
        }
        try {
            return circuitBreaker.executeSupplier(() -> gemini.generate(image, mimeType));
        } catch (CallNotPermittedException e) {
            throw new InferenceUnavailableException("Circuito abierto: análisis IA temporalmente deshabilitado", e);
        } catch (InferenceUnavailableException e) {
            throw e;
        } catch (RuntimeException e) {
            log.warn("Fallo en la inferencia con Gemini: {}", e.getMessage());
            throw new InferenceUnavailableException("Fallo del proveedor de IA", e);
        }
    }

    CircuitBreaker.State state() {
        return circuitBreaker.getState();
    }
}
