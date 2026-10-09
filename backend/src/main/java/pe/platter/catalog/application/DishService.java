package pe.platter.catalog.application;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.cache.annotation.CacheEvict;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import pe.platter.assets.application.ModelLibrary;
import pe.platter.billing.application.PlanPolicy;
import pe.platter.catalog.domain.Dish;
import pe.platter.catalog.domain.DishDetails;
import pe.platter.catalog.domain.DishStatus;
import pe.platter.catalog.infrastructure.DishRepository;
import pe.platter.restaurants.application.RestaurantService;
import pe.platter.shared.api.PlatterException;

@Service
public class DishService {

    private final DishRepository dishes;
    private final PhotoService photos;
    private final ModelLibrary models;
    private final RestaurantService restaurants;
    private final PlanPolicy planPolicy;

    DishService(DishRepository dishes, PhotoService photos, ModelLibrary models, RestaurantService restaurants,
            PlanPolicy planPolicy) {
        this.dishes = dishes;
        this.photos = photos;
        this.models = models;
        this.restaurants = restaurants;
        this.planPolicy = planPolicy;
    }

    @Transactional(readOnly = true)
    public List<Dish> list(UUID restaurantId) {
        return dishes.findByRestaurantIdOrderByCategoryAscNameAsc(restaurantId);
    }

    @Transactional(readOnly = true)
    public Dish get(UUID restaurantId, UUID dishId) {
        return dishes.findByIdAndRestaurantId(dishId, restaurantId).orElseThrow(() -> PlatterException.notFound("Plato"));
    }

    @Transactional
    @CacheEvict(cacheNames = MenuCatalogQuery.CACHE, key = "#restaurantId")
    public Dish create(UUID restaurantId, DishDetails details) {
        planPolicy.ensureDishesAllowed(restaurants.get(restaurantId).getPlan(),
                dishes.countByRestaurantId(restaurantId) + 1);
        return dishes.save(new Dish(restaurantId, validated(restaurantId, details)));
    }

    @Transactional
    @CacheEvict(cacheNames = MenuCatalogQuery.CACHE, key = "#restaurantId")
    public Dish update(UUID restaurantId, UUID dishId, DishDetails details) {
        Dish dish = get(restaurantId, dishId);
        if (details.photoId() == null) {
            // Omitir photoId conserva la foto actual.
            details = details.withPhotoId(dish.getPhotoId());
        }
        dish.apply(validated(restaurantId, details));
        Map<String, String> issues = dish.publicationIssues();
        if (dish.getStatus() == DishStatus.PUBLISHED && !issues.isEmpty()) {
            throw new PlatterException(HttpStatus.UNPROCESSABLE_CONTENT, "DISH_NOT_PUBLISHABLE",
                    "Un plato publicado debe mantener su ficha completa", issues);
        }
        return dish;
    }

    /** US09: el plato solo es visible en la carta tras la validación y confirmación del dueño. */
    @Transactional
    @CacheEvict(cacheNames = MenuCatalogQuery.CACHE, key = "#restaurantId")
    public Dish publish(UUID restaurantId, UUID dishId) {
        Dish dish = get(restaurantId, dishId);
        Map<String, String> issues = dish.publicationIssues();
        if (!issues.isEmpty()) {
            throw new PlatterException(HttpStatus.UNPROCESSABLE_CONTENT, "DISH_NOT_PUBLISHABLE",
                    "Completa la ficha antes de publicar", issues);
        }
        dish.publish();
        return dish;
    }

    /** US18: "Agotado por hoy" con un toque; la carta pública se invalida de inmediato. */
    @Transactional
    @CacheEvict(cacheNames = MenuCatalogQuery.CACHE, key = "#restaurantId")
    public Dish changeAvailability(UUID restaurantId, UUID dishId, boolean available) {
        Dish dish = get(restaurantId, dishId);
        dish.changeAvailability(available);
        return dish;
    }

    @Transactional
    @CacheEvict(cacheNames = MenuCatalogQuery.CACHE, key = "#restaurantId")
    public void delete(UUID restaurantId, UUID dishId) {
        dishes.delete(get(restaurantId, dishId));
    }

    private DishDetails validated(UUID restaurantId, DishDetails details) {
        if (details.photoId() != null) {
            photos.get(restaurantId, details.photoId());
        }
        if (details.caloriesMin() != null && details.caloriesMax() != null
                && details.caloriesMin() > details.caloriesMax()) {
            throw new PlatterException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Revisa los campos marcados",
                    Map.of("caloriesMax", "Debe ser mayor o igual al mínimo"));
        }
        if (details.modelId() == null) {
            // US10 Scenario 1: asociación automática por categoría.
            return details.withModelId(models.suggest(details.name(), details.category()).orElse(null));
        }
        if (!models.exists(details.modelId())) {
            throw new PlatterException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Revisa los campos marcados",
                    Map.of("modelId", "El modelo 3D no existe en la biblioteca"));
        }
        return details;
    }
}
