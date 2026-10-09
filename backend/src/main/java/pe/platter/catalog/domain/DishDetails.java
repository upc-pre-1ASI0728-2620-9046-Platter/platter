package pe.platter.catalog.domain;

import java.math.BigDecimal;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/** Datos editables de la ficha técnica de un plato. */
public record DishDetails(
        String name,
        String description,
        String category,
        BigDecimal price,
        List<String> ingredients,
        Set<Allergen> allergens,
        boolean allergenFree,
        String kitchenNotes,
        Integer caloriesMin,
        Integer caloriesMax,
        boolean vegetarian,
        boolean vegan,
        UUID photoId,
        String modelId) {

    public DishDetails withPhotoId(UUID photoId) {
        return new DishDetails(name, description, category, price, ingredients, allergens, allergenFree, kitchenNotes,
                caloriesMin, caloriesMax, vegetarian, vegan, photoId, modelId);
    }

    public DishDetails withModelId(String modelId) {
        return new DishDetails(name, description, category, price, ingredients, allergens, allergenFree, kitchenNotes,
                caloriesMin, caloriesMax, vegetarian, vegan, photoId, modelId);
    }
}
