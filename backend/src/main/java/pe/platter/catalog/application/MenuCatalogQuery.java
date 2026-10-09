package pe.platter.catalog.application;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import pe.platter.assets.application.ModelLibrary;
import pe.platter.assets.domain.DishModel;
import pe.platter.catalog.domain.Allergen;
import pe.platter.catalog.domain.Dish;
import pe.platter.catalog.domain.DishStatus;
import pe.platter.catalog.infrastructure.DishRepository;

/**
 * Outbound capability {@code GetActiveMenuCatalog(restaurantId)} (Open Host Service hacia la experiencia WebAR).
 * El resultado se cachea por restaurante (QA-06) y se invalida al modificar cualquier plato.
 */
@Service
public class MenuCatalogQuery {

    public static final String CACHE = "activeMenu";

    private final DishRepository dishes;
    private final ModelLibrary models;

    MenuCatalogQuery(DishRepository dishes, ModelLibrary models) {
        this.dishes = dishes;
        this.models = models;
    }

    @Cacheable(cacheNames = CACHE, key = "#restaurantId")
    @Transactional(readOnly = true)
    public MenuCatalogView activeMenu(UUID restaurantId) {
        Map<String, List<DishView>> byCategory = new LinkedHashMap<>();
        for (Dish dish : dishes.findByRestaurantIdAndStatusOrderByCategoryAscNameAsc(restaurantId,
                DishStatus.PUBLISHED)) {
            byCategory.computeIfAbsent(dish.getCategory(), c -> new ArrayList<>()).add(toView(dish));
        }
        List<CategoryView> categories = byCategory.entrySet().stream()
                .map(e -> new CategoryView(e.getKey(), List.copyOf(e.getValue()))).toList();
        return new MenuCatalogView(restaurantId, categories);
    }

    @Transactional(readOnly = true)
    public Optional<UUID> restaurantOfPublishedDish(UUID dishId) {
        return dishes.findById(dishId).filter(d -> d.getStatus() == DishStatus.PUBLISHED).map(Dish::getRestaurantId);
    }

    private DishView toView(Dish dish) {
        DishModel model = models.find(dish.getModelId()).orElse(null);
        return new DishView(dish.getId(), dish.getName(), dish.getDescription(), dish.getCategory(), dish.getPrice(),
                dish.getIngredients(), dish.getAllergens().stream().map(Allergen::name).sorted().toList(),
                dish.isAllergenFree(), dish.getKitchenNotes(), dish.getCaloriesMin(), dish.getCaloriesMax(),
                dish.isVegetarian(), dish.isVegan(), dish.getPhotoId(), model == null ? null : model.id(),
                dish.isAvailable());
    }

    public record MenuCatalogView(UUID restaurantId, List<CategoryView> categories) implements Serializable {
    }

    public record CategoryView(String name, List<DishView> dishes) implements Serializable {
    }

    public record DishView(UUID id, String name, String description, String category, BigDecimal price,
            List<String> ingredients, List<String> allergens, boolean allergenFree, String kitchenNotes,
            Integer caloriesMin, Integer caloriesMax, boolean vegetarian, boolean vegan, UUID photoId,
            String modelId, boolean available) implements Serializable {
    }
}
