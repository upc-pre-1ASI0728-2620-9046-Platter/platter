package pe.platter.catalog.interfaces;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Component;

import pe.platter.assets.application.ModelLibrary;
import pe.platter.assets.interfaces.ModelResource;
import pe.platter.catalog.domain.Allergen;
import pe.platter.catalog.domain.Dish;
import pe.platter.shared.web.ApiUrls;

@Component
public class DishResources {

    private final ModelLibrary models;

    DishResources(ModelLibrary models) {
        this.models = models;
    }

    public static String photoUrl(UUID photoId) {
        return photoId == null ? null : ApiUrls.of("/api/v1/media/photos/" + photoId);
    }

    public static Calories calories(Integer min, Integer max) {
        return min == null && max == null ? null : new Calories(min, max);
    }

    public ModelResource model(String modelId) {
        return models.find(modelId).map(ModelResource::from).orElse(null);
    }

    DishResource toResource(Dish d) {
        return new DishResource(d.getId(), d.getName(), d.getDescription(), d.getCategory(), d.getPrice(),
                d.getIngredients(), d.getAllergens().stream().map(Allergen::name).sorted().toList(),
                d.isAllergenFree(), d.getKitchenNotes(), calories(d.getCaloriesMin(), d.getCaloriesMax()),
                d.isVegetarian(), d.isVegan(), photoUrl(d.getPhotoId()), d.getPhotoId(), model(d.getModelId()),
                d.getStatus().name(), d.isAvailable(), d.getUpdatedAt());
    }

    public record Calories(Integer min, Integer max) {
    }

    record DishResource(UUID id, String name, String description, String category, BigDecimal priceSoles,
            List<String> ingredients, List<String> allergens, boolean allergenFree, String kitchenNotes,
            Calories calories, boolean vegetarian, boolean vegan, String photoUrl, UUID photoId,
            ModelResource model, String status, boolean available, Instant updatedAt) {
    }
}
