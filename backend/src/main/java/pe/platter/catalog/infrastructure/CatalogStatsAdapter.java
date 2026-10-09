package pe.platter.catalog.infrastructure;

import java.util.UUID;

import org.springframework.stereotype.Component;

import pe.platter.restaurants.application.CatalogStats;

@Component
class CatalogStatsAdapter implements CatalogStats {

    private final DishRepository dishes;

    CatalogStatsAdapter(DishRepository dishes) {
        this.dishes = dishes;
    }

    @Override
    public long countDishes(UUID restaurantId) {
        return dishes.countByRestaurantId(restaurantId);
    }
}
