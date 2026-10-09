package pe.platter.catalog.application;

import java.util.Map;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import pe.platter.analysis.domain.GastronomicInference;
import pe.platter.analysis.domain.GastronomicInferenceService;
import pe.platter.analysis.domain.InferenceUnavailableException;
import pe.platter.assets.application.ModelLibrary;
import pe.platter.catalog.domain.Photo;
import pe.platter.restaurants.application.RestaurantService;
import pe.platter.shared.api.PlatterException;
import pe.platter.shared.config.PlatterProperties;
import pe.platter.shared.storage.ObjectStorage;

/** Historia 1 del Domain Storytelling: el Catálogo solicita el análisis multimodal y sugiere el modelo 3D. */
@Service
public class DishAnalysisService {

    private final PhotoService photos;
    private final ObjectStorage storage;
    private final GastronomicInferenceService inference;
    private final ModelLibrary models;
    private final RestaurantService restaurants;
    private final double lowConfidenceThreshold;

    DishAnalysisService(PhotoService photos, ObjectStorage storage, GastronomicInferenceService inference,
            ModelLibrary models, RestaurantService restaurants, PlatterProperties properties) {
        this.photos = photos;
        this.storage = storage;
        this.inference = inference;
        this.models = models;
        this.restaurants = restaurants;
        this.lowConfidenceThreshold = properties.ai().lowConfidenceThreshold();
    }

    public Result analyze(UUID restaurantId, UUID photoId) {
        if (!restaurants.get(restaurantId).getPlan().aiAnalysis()) {
            throw new PlatterException(HttpStatus.FORBIDDEN, "PLAN_LIMIT_REACHED",
                    "Tu plan no incluye el análisis con IA");
        }
        Photo photo = photos.get(restaurantId, photoId);
        byte[] bytes = storage.get(photo.getStorageKey()).orElseThrow(() -> PlatterException.notFound("Fotografía"));
        GastronomicInference result;
        try {
            result = inference.analyze(bytes, photo.getContentType());
        } catch (InferenceUnavailableException e) {
            throw new PlatterException(HttpStatus.SERVICE_UNAVAILABLE, "AI_UNAVAILABLE",
                    "El análisis con IA no está disponible en este momento. Puedes completar la ficha manualmente.",
                    Map.of("retryable", true, "manualEntryAllowed", true));
        }
        boolean lowConfidence = !result.food() || result.confidence() < lowConfidenceThreshold;
        String modelId = models.suggest(result.suggestedName(), result.category()).orElse(null);
        return new Result(photo, result, lowConfidence, modelId);
    }

    public record Result(Photo photo, GastronomicInference inference, boolean lowConfidence,
            String suggestedModelId) {
    }
}
