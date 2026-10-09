package pe.platter.analysis.infrastructure;

import java.net.http.HttpClient;
import java.time.Duration;
import java.util.Base64;
import java.util.List;
import java.util.Map;

import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import pe.platter.analysis.domain.GastronomicInference;
import pe.platter.analysis.domain.InferenceUnavailableException;
import pe.platter.shared.config.PlatterProperties;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * Anti-Corruption Layer hacia Google Gemini: traduce {@code Content/Part/Candidate} al modelo
 * {@link GastronomicInference}. Nada fuera de esta clase conoce el contrato de Google.
 */
@Component
class GeminiApiClientAdapter {

    static final List<String> CATEGORIES = List.of("Entradas", "Ceviches", "Fondos", "Criollos", "Sánguches",
            "Hamburguesas", "Pizzas", "Ensaladas", "Postres", "Bebidas");
    static final List<String> ALLERGENS = List.of("GLUTEN", "CRUSTACEANS", "MOLLUSCS", "FISH", "EGGS", "MILK",
            "PEANUTS", "TREE_NUTS", "SOY", "SESAME", "CELERY", "MUSTARD", "SULPHITES", "LUPIN");

    private static final String PROMPT = """
            Eres un experto en gastronomía peruana que ayuda a restaurantes MYPE a digitalizar su carta.
            Analiza la fotografía y responde SOLO con el JSON del esquema:
            - food: true si la imagen muestra claramente un plato o bebida; false en otro caso.
            - confidence: de 0 a 1, qué tan seguro estás de la identificación (baja si la foto es oscura o borrosa).
            - suggestedName: nombre comercial en español (ej. "Lomo saltado", "Cebiche clásico").
            - description: descripción sensorial apetitosa de 40 a 70 palabras, tono formal y léxico peruano.
            - category: una de las categorías permitidas.
            - ingredients: 3 a 10 ingredientes principales visibles o típicos de la receta, en español.
            - allergens: códigos de alérgenos probables según los ingredientes (vacío si no hay).
            - caloriesMin y caloriesMax: rango calórico estimado de la porción mostrada en kcal.
            """;

    private final RestClient http;
    private final ObjectMapper json;
    private final PlatterProperties.Ai config;

    GeminiApiClientAdapter(RestClient.Builder builder, ObjectMapper json, PlatterProperties properties) {
        this.config = properties.ai();
        this.json = json;
        HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(client);
        factory.setReadTimeout(config.timeout());
        this.http = builder.baseUrl(config.endpoint()).requestFactory(factory).build();
    }

    boolean configured() {
        return config.configured();
    }

    GastronomicInference generate(byte[] image, String mimeType) {
        Map<String, Object> body = Map.of(
                "contents", List.of(Map.of("parts", List.of(
                        Map.of("text", PROMPT),
                        Map.of("inlineData", Map.of("mimeType", mimeType,
                                "data", Base64.getEncoder().encodeToString(image)))))),
                "generationConfig", Map.of(
                        "temperature", 0.4,
                        "responseMimeType", "application/json",
                        "responseSchema", responseSchema()));

        JsonNode response = http.post()
                .uri("/models/{model}:generateContent", config.model())
                .header("x-goog-api-key", config.apiKey())
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(JsonNode.class);
        return translate(response);
    }

    GastronomicInference translate(JsonNode response) {
        JsonNode text = response == null ? null
                : response.path("candidates").path(0).path("content").path("parts").path(0).path("text");
        if (text == null || !text.isString()) {
            throw new InferenceUnavailableException("Respuesta de Gemini sin contenido");
        }
        JsonNode r = json.readTree(text.asString());
        return new GastronomicInference(
                r.path("food").asBoolean(false),
                clamp(r.path("confidence").asDouble(0)),
                r.path("suggestedName").asString(""),
                r.path("description").asString(""),
                CATEGORIES.contains(r.path("category").asString("")) ? r.path("category").asString() : null,
                strings(r.path("ingredients")),
                strings(r.path("allergens")).stream().filter(ALLERGENS::contains).toList(),
                r.path("caloriesMin").isNumber() ? r.path("caloriesMin").asInt() : null,
                r.path("caloriesMax").isNumber() ? r.path("caloriesMax").asInt() : null);
    }

    private static List<String> strings(JsonNode array) {
        if (!array.isArray()) {
            return List.of();
        }
        return array.valueStream().map(n -> n.asString("").trim()).filter(s -> !s.isEmpty()).toList();
    }

    private static double clamp(double value) {
        return Math.max(0, Math.min(1, value));
    }

    private static Map<String, Object> responseSchema() {
        return Map.of(
                "type", "OBJECT",
                "properties", Map.of(
                        "food", Map.of("type", "BOOLEAN"),
                        "confidence", Map.of("type", "NUMBER"),
                        "suggestedName", Map.of("type", "STRING"),
                        "description", Map.of("type", "STRING"),
                        "category", Map.of("type", "STRING", "enum", CATEGORIES),
                        "ingredients", Map.of("type", "ARRAY", "items", Map.of("type", "STRING")),
                        "allergens", Map.of("type", "ARRAY", "items", Map.of("type", "STRING", "enum", ALLERGENS)),
                        "caloriesMin", Map.of("type", "INTEGER"),
                        "caloriesMax", Map.of("type", "INTEGER")),
                "required", List.of("food", "confidence", "suggestedName", "description", "category",
                        "ingredients", "allergens", "caloriesMin", "caloriesMax"));
    }
}
