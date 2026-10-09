package pe.platter.assets.application;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.text.Normalizer;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import pe.platter.assets.domain.DishModel;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

/**
 * Biblioteca gastronómica 3D precargada (DRV-06). Los GLB son pequeños e inmutables: se mantienen en memoria con
 * su ETag precalculado para despacharlos con caché agresiva (DRV-01).
 */
@Service
public class ModelLibrary {

    public static final String GENERIC_MODEL_ID = "generico";
    private static final Logger log = LoggerFactory.getLogger(ModelLibrary.class);

    /** Palabras clave del nombre/categoría del plato → modelo estándar de la biblioteca (US10 Scenario 1). */
    private static final Map<String, String> KEYWORDS = new LinkedHashMap<>();

    static {
        KEYWORDS.put("cebiche", "ceviche");
        KEYWORDS.put("ceviche", "ceviche");
        KEYWORDS.put("tiradito", "ceviche");
        KEYWORDS.put("lomo", "lomo-saltado");
        KEYWORDS.put("saltado", "lomo-saltado");
        KEYWORDS.put("aji de gallina", "aji-de-gallina");
        KEYWORDS.put("causa", "causa");
        KEYWORDS.put("hamburguesa", "hamburguesa");
        KEYWORDS.put("burger", "hamburguesa");
        KEYWORDS.put("sanguch", "hamburguesa");
        KEYWORDS.put("sandwich", "hamburguesa");
        KEYWORDS.put("pizza", "pizza");
        KEYWORDS.put("ensalada", "ensalada");
        KEYWORDS.put("postre", "postre");
        KEYWORDS.put("suspiro", "postre");
        KEYWORDS.put("torta", "postre");
        KEYWORDS.put("chicha", "bebida");
        KEYWORDS.put("bebida", "bebida");
        KEYWORDS.put("jugo", "bebida");
        KEYWORDS.put("limonada", "bebida");
    }

    private final Map<String, DishModel> models = new LinkedHashMap<>();
    private final Map<String, Asset> assets = new LinkedHashMap<>();

    public ModelLibrary(ObjectMapper json) {
        ClassPathResource index = new ClassPathResource("library/models.json");
        if (!index.exists()) {
            log.warn("No se encontró library/models.json: la biblioteca 3D está vacía");
            return;
        }
        try (InputStream in = index.getInputStream()) {
            List<DishModel> entries = json.readValue(in, new TypeReference<List<DishModel>>() {
            });
            for (DishModel model : entries) {
                ClassPathResource glb = new ClassPathResource("library/models/" + model.id() + ".glb");
                if (!glb.exists()) {
                    log.warn("Modelo {} sin archivo GLB, se omite", model.id());
                    continue;
                }
                byte[] bytes = glb.getContentAsByteArray();
                models.put(model.id(), model);
                assets.put(model.id(), new Asset(bytes, etag(bytes)));
            }
            log.info("Biblioteca 3D cargada con {} modelos", models.size());
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    public List<DishModel> all() {
        return List.copyOf(models.values());
    }

    public Optional<DishModel> find(String id) {
        return Optional.ofNullable(id).map(models::get);
    }

    public Optional<Asset> asset(String id) {
        return Optional.ofNullable(assets.get(id));
    }

    public boolean exists(String id) {
        return id != null && models.containsKey(id);
    }

    /** Sugiere el modelo estándar según nombre y categoría del plato; si no hay coincidencia, el genérico. */
    public Optional<String> suggest(String dishName, String category) {
        String haystack = normalize((dishName == null ? "" : dishName) + " " + (category == null ? "" : category));
        for (Map.Entry<String, String> entry : KEYWORDS.entrySet()) {
            if (haystack.contains(entry.getKey()) && models.containsKey(entry.getValue())) {
                return Optional.of(entry.getValue());
            }
        }
        if (category != null) {
            for (DishModel model : models.values()) {
                if (model.category() != null && model.category().equalsIgnoreCase(category.trim())) {
                    return Optional.of(model.id());
                }
            }
        }
        return models.containsKey(GENERIC_MODEL_ID) ? Optional.of(GENERIC_MODEL_ID)
                : models.keySet().stream().findFirst();
    }

    private static String normalize(String text) {
        return Normalizer.normalize(text, Normalizer.Form.NFD).replaceAll("\\p{M}", "").toLowerCase(Locale.ROOT);
    }

    private static String etag(byte[] bytes) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes);
            return "\"" + HexFormat.of().formatHex(digest, 0, 16) + "\"";
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    public record Asset(byte[] bytes, String etag) {
    }
}
